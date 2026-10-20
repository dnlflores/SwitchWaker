// WGSL -> uam GLSL (shader_translate.h). The post-pass follows the pattern of SwitchWakerHD's
// runtime/src/gfx/deko/glsl_convert.cpp (MPL-2.0): fix the source line by line where uam's dialect
// differs, keep everything else byte for byte. No code of it is copied; the rules are this
// project's.
#include "shader_translate.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <cstdio>
#include <map>
#include <sstream>
#include <tuple>

#include "src/tint/api/tint.h"
#include "src/tint/lang/core/ir/module.h"
#include "src/tint/lang/glsl/writer/writer.h"
#include "src/tint/lang/wgsl/inspector/inspector.h"
#include "src/tint/lang/wgsl/reader/reader.h"
#include "src/tint/utils/text/styled_text.h"

namespace swdk {
namespace {

using tint::BindingPoint;
using RB = tint::inspector::ResourceBinding;

constexpr uint32_t kPlaceholderSamplerGroup = 1000;  // textureLoad without a sampler

std::string sampler_name(uint32_t slot) { return "cos_tex" + std::to_string(slot); }

bool is_uniform(RB::ResourceType t) { return t == RB::ResourceType::kUniformBuffer; }
bool is_storage(RB::ResourceType t) {
    return t == RB::ResourceType::kStorageBuffer || t == RB::ResourceType::kReadOnlyStorageBuffer;
}
bool is_texture(RB::ResourceType t) {
    return t == RB::ResourceType::kSampledTexture || t == RB::ResourceType::kDepthTexture ||
           t == RB::ResourceType::kMultisampledTexture || t == RB::ResourceType::kDepthMultisampledTexture;
}

// Tint's binding numbers for textures and samplers before the post-pass: group * 64 + binding, unique
// while every binding is below 64
constexpr uint32_t kBindingsPerGroup = 64;

// An opaque sampler type of GLSL: sampler2D, isampler2D, usampler2DArray, sampler2DShadow, samplerCube...
bool is_sampler_type(const std::string& t) {
    const size_t at = t[0] == 'i' || t[0] == 'u' ? 1 : 0;
    return t.compare(at, 7, "sampler") == 0;
}

// "uniform [precision] <sampler type> <name>;" -> true, *name. The words of the line, as Tint's GLSL
// writer emits a combined sampler at global scope (one space between words, no layout()).
bool sampler_declaration(const std::string& line, std::string* name) {
    if (line.rfind("uniform ", 0) != 0 || line.size() < 2 || line.back() != ';') return false;
    std::istringstream words(line.substr(0, line.size() - 1));
    std::vector<std::string> w;
    for (std::string word; words >> word;) w.push_back(word);
    const bool precision = w.size() == 4 && (w[1] == "highp" || w[1] == "mediump" || w[1] == "lowp");
    if (!(w.size() == 3 || precision)) return false;
    if (!is_sampler_type(w[precision ? 2 : 1])) return false;
    *name = w.back();
    return true;
}

// a line that declares a sampler uniform in another shape than sampler_declaration's
bool unhandled_sampler_uniform(const std::string& line) {
    if (line.find('{') != std::string::npos) return false;  // a uniform block
    std::istringstream words(line);
    bool uniform = false, sampler = false;
    for (std::string word; words >> word;) {
        uniform = uniform || word == "uniform";
        sampler = sampler || is_sampler_type(word);
    }
    return uniform && sampler;
}

}  // namespace

void translate_init() { tint::Initialize(); }

namespace {
// file: kept alive with the program (its diagnostics refer to it)
tint::Program parse_wgsl(const tint::Source::File& file) {
    tint::wgsl::reader::Options readerOptions;
    readerOptions.allowed_features = tint::wgsl::AllowedFeatures::Everything();
    return tint::wgsl::reader::Parse(&file, readerOptions);
}
}  // namespace

std::vector<EntryPoint> wgsl_entry_points(const std::string& wgsl, std::string* error) {
    std::vector<EntryPoint> out;
    tint::Source::File file("shader.wgsl", wgsl);
    tint::Program program = parse_wgsl(file);
    if (!program.IsValid()) {
        *error = "WGSL: " + program.Diagnostics().Str();
        return out;
    }
    tint::inspector::Inspector inspector(program);
    for (const auto& ep : inspector.GetEntryPoints()) {
        if (ep.stage == tint::inspector::PipelineStage::kVertex) out.push_back({ShaderStage::Vertex, ep.name});
        if (ep.stage == tint::inspector::PipelineStage::kFragment) out.push_back({ShaderStage::Fragment, ep.name});
    }
    return out;
}

TranslateResult wgsl_to_glsl(const std::string& wgsl, const std::string& entryPoint, ShaderStage stage,
                             BindingScheme scheme) {
    TranslateResult r;
    tint::Source::File file("shader.wgsl", wgsl);
    tint::Program program = parse_wgsl(file);
    if (!program.IsValid()) {
        r.error = "WGSL: " + program.Diagnostics().Str();
        return r;
    }

    tint::inspector::Inspector inspector(program);
    bool found = false;
    for (const auto& ep : inspector.GetEntryPoints()) {
        if (ep.name == entryPoint) {
            found = true;
            r.immediateSize = ep.immediate_data_size;
            const bool wantVertex = stage == ShaderStage::Vertex;
            if ((ep.stage == tint::inspector::PipelineStage::kVertex) != wantVertex) {
                r.error = "entry point " + entryPoint + " is not of the requested stage";
                return r;
            }
        }
    }
    if (!found) {
        r.error = "no entry point " + entryPoint;
        return r;
    }

    tint::glsl::writer::Options options;
    options.version = tint::glsl::writer::Version(tint::glsl::writer::Version::Standard::kDesktop, 4, 6);
    options.entry_point_name = entryPoint;
    options.disable_robustness = true;
    options.depth_zero_to_one = true;
    options.disable_position_y_negation = true;
    options.use_uniform_buffers = true;
    options.strip_all_names = false;
    options.disable_polyfill_integer_div_mod = false;
    options.placeholder_sampler_bind_point = {kPlaceholderSamplerGroup, 0};

    // Buffers: GX's fixed numbers, or (group, binding) order.
    std::vector<RB> resources = inspector.GetResourceBindings(entryPoint);
    std::sort(resources.begin(), resources.end(), [](const RB& a, const RB& b) {
        return std::tie(a.bind_group, a.binding) < std::tie(b.bind_group, b.binding);
    });
    uint32_t nextUbo = 0, nextSsbo = 0;
    for (const RB& res : resources) {
        const BindingPoint wgslBp{res.bind_group, res.binding};
        if (res.binding >= kBindingsPerGroup) {
            r.error = "binding " + std::to_string(res.binding) + " of " + res.variable_name + " is not below " +
                      std::to_string(kBindingsPerGroup);
            return r;
        }
        if (is_uniform(res.resource_type) || is_storage(res.resource_type)) {
            const bool ubo = is_uniform(res.resource_type);
            uint32_t slot;
            if (scheme == BindingScheme::GX) {
                slot = ubo ? (res.bind_group == 1 && res.binding == 0 ? 0u : 99u)
                           : (res.bind_group == 0 ? res.binding : 99u);
            } else {
                slot = ubo ? nextUbo++ : nextSsbo++;
            }
            if (slot >= kImmediatesUboSlot) {
                r.error = "no slot for buffer @group(" + std::to_string(res.bind_group) + ") @binding(" +
                          std::to_string(res.binding) + ")";
                return r;
            }
            (ubo ? options.bindings.uniform : options.bindings.storage).emplace(wgslBp, BindingPoint{0, slot});
            r.bindings.push_back({ubo ? SlotBinding::Kind::Uniform : SlotBinding::Kind::Storage, uint8_t(slot),
                                  res.bind_group, res.binding});
        } else if (is_texture(res.resource_type)) {
            // the post-remapping number only names the pair below; uam sees the post-pass binding
            options.bindings.texture.emplace(wgslBp, BindingPoint{0, res.bind_group * kBindingsPerGroup + res.binding});
        } else if (res.resource_type == RB::ResourceType::kSampler) {
            options.bindings.sampler.emplace(wgslBp, BindingPoint{0, res.bind_group * kBindingsPerGroup + res.binding});
        } else {
            r.error = "unsupported resource " + res.variable_name;
            return r;
        }
    }

    // Combined samplers: one slot per (texture, sampler) pair the entry point uses.
    auto pairs = inspector.GetSamplerAndNonSamplerTextureUses(
        entryPoint, BindingPoint{kPlaceholderSamplerGroup, 0});
    std::sort(pairs.begin(), pairs.end(), [](const auto& a, const auto& b) {
        return std::tie(a.texture_binding_point.group, a.texture_binding_point.binding,
                        a.sampler_binding_point.group, a.sampler_binding_point.binding) <
               std::tie(b.texture_binding_point.group, b.texture_binding_point.binding,
                        b.sampler_binding_point.group, b.sampler_binding_point.binding);
    });
    std::vector<SamplerSlot> samplerSlots;
    uint32_t nextSampler = 0;
    uint32_t usedSlots = 0;  // bit per combined sampler slot
    for (const auto& pair : pairs) {
        const BindingPoint tex = pair.texture_binding_point, smp = pair.sampler_binding_point;
        uint32_t slot;
        if (scheme == BindingScheme::GX) {
            slot = tex.group == 2 && tex.binding % 2 == 0 ? tex.binding / 2 : 99u;
        } else {
            slot = nextSampler++;
        }
        if (slot >= 32) {
            r.error = "no sampler slot for texture @group(" + std::to_string(tex.group) + ") @binding(" +
                      std::to_string(tex.binding) + ")";
            return r;
        }
        // GX: one slot per texture map. The same texture with two samplers (or sampled and also read with
        // textureLoad) would make two GLSL samplers on one slot, and the renderer binds one descriptor there.
        if (usedSlots & (1u << slot)) {
            r.error = "texture @group(" + std::to_string(tex.group) + ") @binding(" + std::to_string(tex.binding) +
                      ") is used with more than one sampler: one slot (" + std::to_string(slot) + ") for both";
            return r;
        }
        usedSlots |= 1u << slot;
        const BindingPoint texRemapped{0, tex.group * kBindingsPerGroup + tex.binding};
        const BindingPoint smpRemapped = smp.group == kPlaceholderSamplerGroup
                                             ? options.placeholder_sampler_bind_point
                                             : BindingPoint{0, smp.group * kBindingsPerGroup + smp.binding};
        const std::string name = sampler_name(slot);
        options.sampler_texture_to_name.emplace(
            tint::glsl::writer::CombinedTextureSamplerPair{texRemapped, smpRemapped, false}, name);
        samplerSlots.push_back({name, slot});
        r.bindings.push_back({SlotBinding::Kind::Sampler, uint8_t(slot), tex.group, tex.binding});
    }
    if (r.immediateSize) {
        r.bindings.push_back({SlotBinding::Kind::Immediates, uint8_t(kImmediatesUboSlot), 0, 0});
        // every stage declares the whole block: the same layout in both stages
        options.minimum_immediate_size = (r.immediateSize + 15u) & ~15u;
    }

    auto ir = tint::wgsl::reader::ProgramToLoweredIR(program);
    if (ir != tint::Success) {
        r.error = "IR: " + ir.Failure().reason;
        return r;
    }
    auto out = tint::glsl::writer::Generate(ir.Get(), options);
    if (out != tint::Success) {
        r.error = "GLSL writer: " + out.Failure().reason;
        return r;
    }
    r.glsl = std::move(out->glsl);
    if (!post_pass(&r.glsl, samplerSlots, &r.error)) {
        r.error = "post-pass: " + r.error;
        return r;
    }
    r.ok = true;
    return r;
}

bool post_pass(std::string* glsl, const std::vector<SamplerSlot>& samplerSlots, std::string* error) {
    std::map<std::string, uint32_t> slots;
    for (const auto& s : samplerSlots) slots[s.name] = s.slot;

    std::istringstream in(*glsl);
    std::string out, line;
    out.reserve(glsl->size() + 256);
    while (std::getline(in, line)) {
        // "uniform highp sampler2D cos_tex0;" (also isampler2D, usampler2D, sampler2DShadow, ...)
        std::string name;
        if (sampler_declaration(line, &name)) {
            auto it = slots.find(name);
            if (it == slots.end()) {
                *error = "no slot for sampler " + name;
                return false;
            }
            out += "layout(binding = " + std::to_string(it->second) + ") " + line + "\n";
            continue;
        }
        // Any other sampler uniform (indented, with a layout() of Tint's binding number group * 64 + binding,
        // ...) would reach uam without its slot, which then defaults to binding 0: refused, so that a later
        // Tint's output cannot slip through.
        if (unhandled_sampler_uniform(line)) {
            *error = "unexpected sampler declaration: " + line;
            return false;
        }
        // Dual-source blending: Tint asks for the ES extension even for desktop GLSL, where
        // layout(index = 1) is core (GL 3.3); uam refuses the extension name.
        if (line.rfind("#extension GL_EXT_blend_func_extended", 0) == 0) continue;
        // "layout(location = 0) uniform uint tint_immediates[16];": Tint's immediates are an array
        // of u32 in a default-block uniform. In a std140 block an array of uint has a 16-byte
        // stride, so the block holds uvec4s instead and every (constant) index is rewritten below.
        if (line.find(" tint_immediates[") != std::string::npos && line.find("uniform uint ") != std::string::npos) {
            const size_t open = line.find(" tint_immediates[") + 17;
            const uint32_t words = uint32_t(strtoul(line.c_str() + open, nullptr, 10));
            if (words == 0 || words > 64 || line.compare(line.size() - 2, 2, "];") != 0) {
                *error = "unexpected immediates declaration: " + line;
                return false;
            }
            out += "layout(binding = " + std::to_string(kImmediatesUboSlot) +
                   ", std140) uniform tint_immediates_ubo {\n  uvec4 tint_immediates_v[" +
                   std::to_string((words + 3) / 4) + "];\n};\n";
            continue;
        }
        if (line.find("tint_immediates") != std::string::npos) {
            // tint_immediates[5u] -> tint_immediates_v[1].y
            std::string fixed;
            size_t pos = 0, at;
            while ((at = line.find("tint_immediates", pos)) != std::string::npos) {
                fixed.append(line, pos, at - pos);
                size_t i = at + 15;
                if (i >= line.size() || line[i] != '[') {
                    *error = "unexpected use of the immediates: " + line;
                    return false;
                }
                size_t j = i + 1;
                while (j < line.size() && isdigit(uint8_t(line[j]))) j++;
                const bool constant = j > i + 1;
                if (j < line.size() && line[j] == 'u') j++;
                if (!constant || j >= line.size() || line[j] != ']') {
                    *error = "immediates indexed with a non-constant (uam reads .x for a dynamic component "
                             "index into a uniform vector): " + line;
                    return false;
                }
                const uint32_t index = uint32_t(strtoul(line.c_str() + i + 1, nullptr, 10));
                fixed += "tint_immediates_v[" + std::to_string(index / 4) + "]." + "xyzw"[index % 4];
                pos = j + 1;
            }
            fixed.append(line, pos, std::string::npos);
            line = std::move(fixed);
        }
        out += line;
        out += '\n';
    }
    *glsl = std::move(out);
    return true;
}

}  // namespace swdk
