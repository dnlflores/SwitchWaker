// Disc check of the run harness (docs/NATIVE_PORT_PHASE4_6.md, step 6.0, decision H9).
//
// COS_DISC must name a readable GameCube disc image (.iso) of the build's disc, revision 0 (GZLE01 for
// the USA build, GZLP01 for the European one: pc_game_id.h, docs/PAL_DISC_PLAN.md): the disc header
// (boot.bin) holds the game code and maker at 0x00, the version byte at 0x07 and the GameCube
// magic 0xC2339F3D at 0x1C, all big-endian. Anything else exits 14 before the SDK starts.
// Opening the disc for the game (aurora_dvd_open) is step 6.1; the SHA-1 check of the image on
// first use is done by native/tools/run.sh (main.dol SHA-1 against the supported revision).
#include "pc_internal.h"

#include "pc/pc_game_id.h"

#include <cerrno>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <string>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>


namespace pc {

namespace {
char sDiscError[512];
// For the player's message (exitDisc): COS_DISC does not exist; COS_DISC is the other region's disc
// (revision 0), so the player started the other build or misnamed the image.
bool sDiscMissing;
bool sOtherRegionDisc;

} // namespace

void discMessage(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(sDiscError, sizeof sDiscError, fmt, ap);
    va_end(ap);
    writef(STDERR_FILENO, "[cos] DISC: %s\n", sDiscError);
}

void exitDisc() {
    pc_exit(PC_EXIT_DISC);
    __builtin_unreachable();
}

int checkDisc() {
    const char* path = gConfig.disc;
    if (path == nullptr) {
        discMessage("COS_DISC is not set (path of the " COS_GAME_ID_STR " .iso)");
        return PC_EXIT_DISC;
    }
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        sDiscMissing = errno == ENOENT;
        discMessage("cannot open COS_DISC=%s: %s", path, strerror(errno));
        return PC_EXIT_DISC;
    }
    struct stat st;
    unsigned char header[0x20];
    ssize_t got = -1;
    if (fstat(fd, &st) == 0 && S_ISREG(st.st_mode)) {
        got = pread(fd, header, sizeof(header), 0);
    }
    close(fd);
    if (got != (ssize_t)sizeof(header)) {
        discMessage("%s is not a regular file with a disc header", path);
        return PC_EXIT_DISC;
    }
    if (memcmp(header, "CISO", 4) == 0) {
        discMessage("%s is a CISO image; convert it to a plain .iso (decision H9)", path);
        return PC_EXIT_DISC;
    }
    const uint32_t magic = ((uint32_t)header[0x1C] << 24) | ((uint32_t)header[0x1D] << 16) |
                           ((uint32_t)header[0x1E] << 8) | (uint32_t)header[0x1F];
    if (magic != 0xC2339F3Du) {
        discMessage("%s is not a GameCube disc image (magic 0x%08x at 0x1C; compressed?)", path, magic);
        return PC_EXIT_DISC;
    }
    char id[7];
    for (int i = 0; i < 6; i++) {
        id[i] = (header[i] >= 0x20 && header[i] < 0x7F) ? (char)header[i] : '?';
    }
    id[6] = '\0';
    const unsigned int version = header[7];
    if (strcmp(id, COS_GAME_ID_STR) != 0 || version != 0) {
        // the other region's disc: name the build that runs it
        const bool usa = strcmp(id, PC_GAME_ID_USA) == 0 && version == 0;
        const bool eur = strcmp(id, PC_GAME_ID_EUR) == 0 && version == 0;
        if (usa || eur) {
            sOtherRegionDisc = true;
            discMessage("%s is %s revision 0, the %s disc: it runs with the %s build (%s); this build is for %s",
                        path, id, usa ? "USA" : "European", usa ? "USA" : "European",
                        usa ? "COS_VERSION=2" : "COS_VERSION=3", COS_GAME_ID_STR);
        } else {
            discMessage("%s is %s revision %u; the supported disc is %s revision 0", path, id, version,
                        COS_GAME_ID_STR);
        }
        return PC_EXIT_DISC;
    }
    writef(STDERR_FILENO, "[cos] disc: %s %s revision 0, %lld bytes\n", path, COS_GAME_ID_STR,
           (long long)st.st_size);
    return 0;
}

} // namespace pc
