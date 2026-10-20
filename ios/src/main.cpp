// SDL owns UIApplication startup. Its main callback runs on the main thread after
// UIKit is ready, so the importer and the game both keep Apple's thread requirements.
#include <SDL3/SDL_main.h>
#include <cstdio>

extern "C" int aurora_main(int argc, char** argv);
extern "C" bool cos_ios_prepare();

int main(int argc, char** argv) {
    fprintf(stderr, "[ios] SDL main entered; preparing importer\n");
    if (!cos_ios_prepare()) {
        return 1;
    }
    return aurora_main(argc, argv);
}
