#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "pc/pc_settings.h"
#import "texture_import.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {
bool validDisc(NSURL* url) {
    FILE* file = fopen(url.fileSystemRepresentation, "rb");
    if (!file) return false;
    unsigned char header[0x20] = {};
    const size_t count = fread(header, 1, sizeof(header), file);
    fclose(file);
    return count == sizeof(header) && memcmp(header, COS_GAME_ID_STR, 6) == 0 &&
           header[6] == 0 && header[7] == 0 && header[0x1c] == 0xc2 &&
           header[0x1d] == 0x33 && header[0x1e] == 0x9f && header[0x1f] == 0x3d;
}

NSURL* makeDirectory(NSSearchPathDirectory kind, NSString* child, NSError** error) {
    NSFileManager* fm = NSFileManager.defaultManager;
    NSURL* root = [fm URLForDirectory:kind inDomain:NSUserDomainMask
                   appropriateForURL:nil create:YES error:error];
    if (!root) return nil;
    NSURL* dir = [root URLByAppendingPathComponent:child isDirectory:YES];
    return [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:error]
               ? dir : nil;
}
}

@interface COSImportController : UIViewController <UIDocumentPickerDelegate>
@property(nonatomic, strong) NSURL* disc;
@property(nonatomic, strong) UILabel* status;
@property(nonatomic, strong) UIButton* play;
@property(nonatomic, strong) UIButton* importButton;
@property(nonatomic, strong) UIButton* texturesButton;
@property(nonatomic, strong) UILabel* texturesStatus;
@property(nonatomic, strong) NSURL* textures;
@property(nonatomic) BOOL pickingTextures;
@property(nonatomic) BOOL ready;
@end

@implementation COSImportController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel* title = [UILabel new];
    title.text = @"SwitchWaker";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    title.textAlignment = NSTextAlignmentCenter;
    self.status = [UILabel new];
    self.status.numberOfLines = 0;
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.play = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.play setTitle:@"Play" forState:UIControlStateNormal];
    [self.play addTarget:self action:@selector(startGame) forControlEvents:UIControlEventTouchUpInside];
    self.importButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.importButton setTitle:@"Import disc image…" forState:UIControlStateNormal];
    [self.importButton addTarget:self action:@selector(importDisc) forControlEvents:UIControlEventTouchUpInside];
    self.texturesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.texturesButton setTitle:@"Import HD texture folder…" forState:UIControlStateNormal];
    [self.texturesButton addTarget:self action:@selector(importTextures) forControlEvents:UIControlEventTouchUpInside];
    self.texturesStatus = [UILabel new];
    self.texturesStatus.numberOfLines = 0;
    self.texturesStatus.textAlignment = NSTextAlignmentCenter;
    self.texturesStatus.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:
                         @[title, self.status, self.play, self.importButton,
                           self.texturesButton, self.texturesStatus]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    UIScrollView* scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIView* content = [UIView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    [content addSubview:stack];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint* preferredWidth = [stack.widthAnchor constraintEqualToAnchor:content.widthAnchor constant:-48];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [content.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
        [stack.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:560],
        preferredWidth,
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:content.topAnchor constant:24],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-24],
    ]];
    [self updateStatus];
}
- (void)updateStatus {
    self.play.enabled = validDisc(self.disc);
    self.status.text = self.play.enabled
        ? @"Disc ready. Connect a controller. At the title screen, press Back / View / Select (or the touchpad) for graphics and quality-of-life settings."
        : @"Import your own " COS_GAME_ID_STR @" revision 0 disc as an uncompressed ISO or GCM. A game controller is required for this development build.";
    BOOL installed = [NSFileManager.defaultManager fileExistsAtPath:self.textures.path];
    self.texturesStatus.text = installed
        ? @"HD texture folder installed. Enable HD textures in the game's Graphics settings. Widescreen and community quality-of-life options are available there too."
        : @"Optional: import an extracted Dolphin DDS texture folder (GZL). In-game settings include widescreen, HD textures and quality-of-life options. Texture packs are supplied separately.";
}
- (void)startGame {
    if (validDisc(self.disc)) self.ready = YES;
}
- (void)importDisc {
    self.pickingTextures = NO;
    // Providers sometimes identify ISO/GCM as generic data. Validate the actual header,
    // rather than trusting the extension or a provider's content type.
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeData] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)importTextures {
    self.pickingTextures = YES;
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeFolder] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)copyTextureFolder:(NSURL*)source {
    self.play.enabled = NO;
    self.importButton.enabled = NO;
    self.texturesButton.enabled = NO;
    self.texturesStatus.text = @"Importing textures… Keep SwitchWaker open. Large packs can take several minutes.";
    const BOOL scoped = [source startAccessingSecurityScopedResource];
    NSURL* destination = self.textures;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            __block NSString* failure = nil;
            NSError* coordinationError = nil;
            NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:source options:0 error:&coordinationError
                byAccessor:^(NSURL* readable) {
                failure = COSImportTextureFolder(readable, destination);
            }];
            if (scoped) [source stopAccessingSecurityScopedResource];
            if (coordinationError) failure = coordinationError.localizedDescription;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.importButton.enabled = YES;
                self.texturesButton.enabled = YES;
                [self updateStatus];
                if (failure) self.texturesStatus.text = failure;
            });
        }
    });
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller
    didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSURL* source = urls.firstObject;
    if (!source) return;
    if (self.pickingTextures) {
        [self copyTextureFolder:source];
        return;
    }
    self.play.enabled = NO;
    self.importButton.enabled = NO;
    self.texturesButton.enabled = NO;
    self.status.text = @"Importing disc… Keep SwitchWaker open.";
    const BOOL scoped = [source startAccessingSecurityScopedResource];
    NSURL* destination = self.disc;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            __block NSString* failure = nil;
            NSError* coordinationError = nil;
            NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:source options:0 error:&coordinationError
                byAccessor:^(NSURL* readable) {
                if (!validDisc(readable)) {
                    failure = @"Choose an uncompressed " COS_GAME_ID_STR @" revision 0 ISO or GCM. Compressed images and other versions are unsupported.";
                    return;
                }
                NSFileManager* fm = NSFileManager.defaultManager;
                NSURL* staging = [destination.URLByDeletingLastPathComponent
                    URLByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".import"]];
                NSError* error = nil;
                BOOL ok = [fm copyItemAtURL:readable toURL:staging error:&error];
                if (ok && !validDisc(staging)) {
                    ok = NO;
                    failure = @"The copied disc could not be verified. Try importing it again.";
                }
                if (ok) {
                    if ([fm fileExistsAtPath:destination.path]) {
                        ok = [fm replaceItemAtURL:destination withItemAtURL:staging backupItemName:nil
                                         options:0 resultingItemURL:nil error:&error];
                    } else {
                        ok = [fm moveItemAtURL:staging toURL:destination error:&error];
                    }
                }
                if (!ok && !failure) failure = error.localizedDescription ?: @"Disc import failed.";
                [fm removeItemAtURL:staging error:nil];
            }];
            if (scoped) [source stopAccessingSecurityScopedResource];
            if (coordinationError) failure = coordinationError.localizedDescription;
            dispatch_async(dispatch_get_main_queue(), ^{
                self.importButton.enabled = YES;
                self.texturesButton.enabled = YES;
                [self updateStatus];
                if (failure) self.status.text = failure;
            });
        }
    });
}
@end

extern "C" bool cos_ios_prepare() {
    @autoreleasepool {
        if (!NSThread.isMainThread) return false;
        NSError* error = nil;
        NSURL* documents = makeDirectory(NSDocumentDirectory, @"", &error);
        NSURL* user = makeDirectory(NSApplicationSupportDirectory, @"SwitchWaker", &error);
        NSURL* cache = makeDirectory(NSCachesDirectory, @"SwitchWaker", &error);
        if (!documents || !user || !cache) {
            fprintf(stderr, "[ios] Cannot create app directories: %s\n", error.localizedDescription.UTF8String);
            return false;
        }
        NSURL* disc = [documents URLByAppendingPathComponent:@COS_GAME_ID_STR ".iso"];
        setenv("COS_DISC", disc.fileSystemRepresentation, 1);
        setenv("COS_USER_DIR", user.fileSystemRepresentation, 1);
        setenv("COS_SETTINGS", [user URLByAppendingPathComponent:@"settings.ini"].fileSystemRepresentation, 1);
        setenv("COS_CACHE_DIR", cache.fileSystemRepresentation, 1);
        NSURL* textures = [documents URLByAppendingPathComponent:@"hd_textures" isDirectory:YES];
        setenv("COS_HD_PACK", textures.fileSystemRepresentation, 1);
        // Capture explicit launch overrides and saved preferences before supplying
        // platform defaults. Otherwise 720p becomes a locked environment override
        // and the in-game resolution row cannot be changed or restored next launch.
        pc_settings_load_early();
        setenv("COS_BACKEND", "metal", 1);
        setenv("COS_FB_SCALE", "1.5", 0); // Start at 720 lines, independently of Retina output.

        // SDL has started UIApplication before calling main. Keep UIKit responsive while
        // waiting for the explicit Play action, then give window ownership to Aurora/SDL.
        COSImportController* importer = [COSImportController new];
        importer.disc = disc;
        importer.textures = textures;
        UIWindowScene* scene = nil;
        for (UIScene* candidate in UIApplication.sharedApplication.connectedScenes) {
            // SDL calls main while its scene is connecting; it may not have
            // transitioned to ForegroundActive yet. Use the connected scene.
            if ([candidate isKindOfClass:UIWindowScene.class]) {
                scene = (UIWindowScene*)candidate;
                break;
            }
        }
        UIWindow* window = scene ? [[UIWindow alloc] initWithWindowScene:scene]
                                : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        if (scene) window.frame = scene.coordinateSpace.bounds;
        window.rootViewController = importer;
        [window makeKeyAndVisible];
        fprintf(stderr, "[ios] Importer visible (scene=%s, size=%.0fx%.0f)\n",
                scene ? "connected" : "legacy", window.bounds.size.width, window.bounds.size.height);
        while (!importer.ready) {
            @autoreleasepool {
                [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
        }
        window.hidden = YES;
        window.rootViewController = nil;
        return true;
    }
}
