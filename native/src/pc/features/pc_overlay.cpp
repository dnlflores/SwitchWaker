// COS_FPS_OVERLAY: a small frame-rate panel in the screen's top-left corner, drawn with Aurora's
// ImGui (which presents over the game picture; COS_SHOT images leave it out). Off by default on
// every host; the options menu (Rendimiento > "Contador de FPS") or COS_FPS_OVERLAY=1 turns it on.
//
// COS_FPS_OVERLAY_DETAIL=compact keeps only the frame rate and the game thread's time on one line.
//
// Every half second it shows the presents per second over that half second (one per game frame, two
// for the split frames of COS_FPS60_TEST), the game thread's busy time per frame (the frame
// minus the pace wait, without aurora_end_frame), and what Dawn's GL replay
// issued per presented frame: draws, pipeline changes and sampled-texture binds, and the time of the
// glDraw* calls (where Mesa validates state) and of setting the state before them; and the GPU time
// per frame of the frames read back in the half second (GL_TIME_ELAPSED_EXT, a few frames late).
#include "pc_internal.h"

#include <imgui.h>


namespace pc {

namespace {

constexpr uint64_t kWindowNs = 500ull * 1000000ull;

struct OverlayState {
    bool started = false;
    bool measured = false; // a half-second window closed (fps and game ms are valid)
    uint64_t windowStartNs = 0;
    unsigned int frames = 0;     // presents
    unsigned int gameFrames = 0; // game frames (fewer than presents with COS_FPS60_TEST)
    uint64_t busyNs = 0;
    double fps = 0;
    double gameMs = 0;
} sOverlay;

void overlayUpdate(uint64_t now) {
    OverlayState& s = sOverlay;
    const uint64_t elapsed = now - s.windowStartNs;
    s.fps = s.frames * 1e9 / (double)elapsed;
    s.gameMs = s.gameFrames != 0 ? s.busyNs / 1e6 / s.gameFrames : 0;
    s.windowStartNs = now;
    s.frames = 0;
    s.gameFrames = 0;
    s.busyNs = 0;
    s.measured = true;
}

} // namespace

void overlayFrame(uint64_t busyNs, bool gameFrame) {
    if (!gConfig.fpsOverlay || ImGui::GetCurrentContext() == nullptr) {
        return;
    }
    OverlayState& s = sOverlay;
    const uint64_t now = monotonicNs();
    if (!s.started) {
        s.started = true;
        s.windowStartNs = now;
    }
    s.frames++;
    if (gameFrame) {
        s.gameFrames++;
        s.busyNs += busyNs;
    }
    if (now - s.windowStartNs >= kWindowNs) {
        overlayUpdate(now);
    }

    ImGui::SetNextWindowPos(ImVec2(8.0f, 8.0f), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.55f);
    constexpr ImGuiWindowFlags kFlags = ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_AlwaysAutoResize |
                                        ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoFocusOnAppearing |
                                        ImGuiWindowFlags_NoNav | ImGuiWindowFlags_NoInputs;
    if (ImGui::Begin("##cos_fps_overlay", nullptr, kFlags)) {
        if (!s.measured) {
            // Turned on a moment ago (options menu): nothing measured yet.
            ImGui::TextUnformatted("-- fps");
            ImGui::End();
            return;
        }
        if (gConfig.fpsOverlayCompact) {
            // COS_FPS_OVERLAY_DETAIL=compact (options menu): one line.
            ImGui::Text("%.1f fps  %.1f ms", s.fps, s.gameMs);
            ImGui::End();
            return;
        }
        ImGui::Text("%.1f fps", s.fps);
        ImGui::Text("game %.1f ms", s.gameMs);
    }
    ImGui::End();
}

} // namespace pc
