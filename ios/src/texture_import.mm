#import "texture_import.h"

#include <cstdio>
#include <cstring>

NSString* COSImportTextureFolder(NSURL* source, NSURL* destination) {
    __block NSString* failure = nil;
    NSFileManager* fm = NSFileManager.defaultManager;
    // Accept the extracted archive's root or its GZL directory.
    NSURL* folder = source;
    NSURL* nested = [folder URLByAppendingPathComponent:@"GZL" isDirectory:YES];
    BOOL isDirectory = NO;
    if ([fm fileExistsAtPath:nested.path isDirectory:&isDirectory] && isDirectory) folder = nested;
    NSString* sourcePath = folder.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
    NSString* targetParent = destination.URLByDeletingLastPathComponent.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
    if ([targetParent isEqualToString:sourcePath] ||
        [targetParent hasPrefix:[sourcePath stringByAppendingString:@"/"]]) {
        return @"Select the extracted GZL texture folder, rather than the SwitchWaker folder containing it.";
    }
    NSURL* staging = [destination.URLByDeletingLastPathComponent
        URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".textures-import"]];
    NSError* error = nil;
    BOOL ok = [fm copyItemAtURL:folder toURL:staging error:&error];
    if (ok) {
        // Validate the local copy before replacing the previous pack. A DDS
        // filename alone is not enough: check its magic and reject symlinks.
        NSUInteger textures = 0;
        NSDirectoryEnumerator* files = [fm enumeratorAtURL:staging
            includingPropertiesForKeys:@[NSURLIsSymbolicLinkKey, NSURLIsRegularFileKey]
            options:0 errorHandler:^BOOL(NSURL* url, NSError* readError) {
                (void)url;
                failure = readError.localizedDescription;
                return NO;
            }];
        if (!files) failure = @"Cannot read the texture folder.";
        for (NSURL* file in files) {
            NSNumber* link = nil;
            [file getResourceValue:&link forKey:NSURLIsSymbolicLinkKey error:&error];
            if (link.boolValue || error) {
                failure = @"The texture folder contains a link or an unreadable file. Import an extracted DDS pack.";
                break;
            }
            if ([file.lastPathComponent hasPrefix:@"tex1_"] &&
                [file.pathExtension.lowercaseString isEqualToString:@"dds"]) {
                FILE* input = fopen(file.fileSystemRepresentation, "rb");
                char header[128] = {};
                BOOL valid = input && fread(header, 1, sizeof(header), input) == sizeof(header) &&
                             memcmp(header, "DDS ", 4) == 0;
                if (input) fclose(input);
                if (!valid) {
                    failure = @"A texture is not a valid DDS file. Extract the DDS version of the pack and try again.";
                    break;
                }
                textures++;
            }
        }
        if (!failure && textures == 0) failure = @"No Dolphin DDS textures found. Select the extracted GZL folder, not a ZIP, 7z or PNG pack.";
        ok = failure == nil;
    }
    if (ok) {
        if ([fm fileExistsAtPath:destination.path]) {
            ok = [fm replaceItemAtURL:destination withItemAtURL:staging backupItemName:nil
                options:0 resultingItemURL:nil error:&error];
        } else {
            ok = [fm moveItemAtURL:staging toURL:destination error:&error];
        }
    }
    if (!ok && !failure) failure = error.localizedDescription ?: @"Texture import failed.";
    [fm removeItemAtURL:staging error:nil];
    return failure;
}
