#pragma once
#import <Foundation/Foundation.h>

// Copies and validates an extracted DDS pack before replacing the installed folder.
// Returns nil on success or a player-facing error; leaves the previous pack on validation failure.
NSString* COSImportTextureFolder(NSURL* source, NSURL* destination);
