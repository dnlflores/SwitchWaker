/*
 * pc_game_id.h - the disc this build runs from (docs/PAL_DISC_PLAN.md).
 *
 * The game version is fixed at compile time (VERSION, native/cmake/GameConfig.cmake): the USA build
 * (COS_VERSION=2, the reference) runs only from GZLE01 revision 0, the European build
 * (COS_VERSION=3) only from GZLP01 revision 0. GameConfig.cmake defines COS_GAME_ID_STR for every
 * unit that links cos_game_headers (the iOS entry gets the same define, ios/CMakeLists.txt). Plain C.
 */
#ifndef PC_GAME_ID_H
#define PC_GAME_ID_H

#ifndef COS_GAME_ID_STR
#define COS_GAME_ID_STR "GZLE01"
#endif

/* The other supported disc, for the message that names the right build. */
#define PC_GAME_ID_USA "GZLE01"
#define PC_GAME_ID_EUR "GZLP01"

/* The disc's region as the messages name it, and the expected image's file name. */
#define PC_GAME_IS_EUR (COS_GAME_ID_STR[3] == 'P')
#define PC_GAME_REGION_EN (PC_GAME_IS_EUR ? "Europe" : "USA")
#define PC_GAME_REGION_ES (PC_GAME_IS_EUR ? "Europa" : "EE. UU.")
#define PC_GAME_ISO_NAME COS_GAME_ID_STR ".iso"

#endif /* PC_GAME_ID_H */
