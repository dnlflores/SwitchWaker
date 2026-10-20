#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

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
    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:
                         @[title, self.status, self.play, self.importButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:560],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:24],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-24],
    ]];
    [self updateStatus];
}
- (void)updateStatus {
    self.play.enabled = validDisc(self.disc);
    self.status.text = self.play.enabled
        ? @"Disc ready. Connect a game controller before playing."
        : @"Import your own " COS_GAME_ID_STR @" revision 0 disc as an uncompressed ISO or GCM. A game controller is required for this development build.";
}
- (void)startGame {
    if (validDisc(self.disc)) self.ready = YES;
}
- (void)importDisc {
    // Providers sometimes identify ISO/GCM as generic data. Validate the actual header,
    // rather than trusting the extension or a provider's content type.
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeData] asCopy:NO];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller
    didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSURL* source = urls.firstObject;
    if (!source) return;
    self.play.enabled = NO;
    self.importButton.enabled = NO;
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
        setenv("COS_BACKEND", "metal", 1);
        setenv("COS_FB_SCALE", "1.5", 0); // Start at 720 lines, independently of Retina output.

        // SDL has started UIApplication before calling main. Keep UIKit responsive while
        // waiting for the explicit Play action, then give window ownership to Aurora/SDL.
        COSImportController* importer = [COSImportController new];
        importer.disc = disc;
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
