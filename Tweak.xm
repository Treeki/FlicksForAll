#include "UIKBTree.h"
#include "UIKeyboardCache.h"
#include "UIKBTouchState.h"
#include "UIKeyboardTaskExecutionContext.h"
#include "UIKeyboardTouchInfo.h"
#include "UIKeyboardLayout.h"
#include "UIKeyboardLayoutStar.h"

static UIKBTree *findLettersKeylayout(UIKBTree *keyplane) {
	for (UIKBTree *keylayout in keyplane.subtrees) {
		if ([keylayout.name hasSuffix:@"Letters-Keylayout"])
			return keylayout;
	}
	return nil;
}

static bool lieAboutGestureKeys = false;

%hook UIKeyboardTouchInfo
%property (nonatomic, assign) bool fpAllow;
- (id)init {
	self.fpAllow = false;
	return %orig;
}
%end

%hook UIKeyboardLayoutStar
- (void)touchDragged:(UIKBTouchState *)state executionContext:(UIKeyboardTaskExecutionContext *)ctx {
	UIKeyboardTouchInfo *touchInfo = [self infoForTouch:state]; // UIKeyboardTouchInfo *

	// are we gonna let this one become a continuous path?
	CGPoint initial = touchInfo.initialPoint;
	CGPoint now = touchInfo.initialDragPoint; // TODO check if this is correct
	double deltaX = now.x - initial.x;
	double deltaY = now.y - initial.y;
	double distanceSq = (deltaX * deltaX) + (deltaY * deltaY);

	NSLog(@"delta:%f,%f distanceSq:%f", deltaX, deltaY, distanceSq);
	if (deltaX < -30 || deltaX > 30 || distanceSq > (85*85))
		touchInfo.fpAllow = true;

	if (touchInfo.fpAllow) {
		// this lets a continuous path happen
		lieAboutGestureKeys = true;
		%orig;
		lieAboutGestureKeys = false;
	} else {
		%orig;
	}
}
%end

%hook UIKBTree
- (int)displayTypeHint {
	int type = %orig;
	if (lieAboutGestureKeys && type == 10)
		return 0;
	else
		return type;
}

- (void)updateFlickKeycapOnKeys {
	%orig;

	// we only want to patch certain planes
	bool ok = [self.name hasSuffix:@"-Letters"] || [self.name hasSuffix:@"-Letters-Small-Display"];
	if (!ok)
		return;

	UIKBTree *mainKeylayout = findLettersKeylayout(self);
	if (mainKeylayout == nil) {
		NSLog(@"WARNING: could not find letters keylayout in %@", self.description);
		return;
	}
	UIKBTree *subKeylayout = mainKeylayout.cachedGestureLayout;

	UIKBTree *origKeyset = mainKeylayout.keySet;
	UIKBTree *subKeyset = subKeylayout.keySet;

	// for now, we'll trust the OS to do the right thing on rows 1/2 (mostly)
	// and redo row 3 with our own mapping
	NSMutableArray *displayStrings = [NSMutableArray array];
	NSMutableArray *representedStrings = [NSMutableArray array];

	// under some layouts, the first key gets left behind, so we wanna map that
	UIKBTree *origMiddleRow = [origKeyset.subtrees objectAtIndex:1];
	UIKBTree *subMiddleRow = [subKeyset.subtrees objectAtIndex:1];
	if (origMiddleRow.subtrees.count == (subMiddleRow.subtrees.count - 1)) {
		UIKBTree *key = subMiddleRow.subtrees.firstObject;
		[displayStrings addObject:key.displayString];
		[representedStrings addObject:key.representedString];
	}

	// now we want to add the sub row
	UIKBTree *origBottomRow = [origKeyset.subtrees objectAtIndex:2];
	UIKBTree *subBottomRow = [subKeyset.subtrees objectAtIndex:2];
	for (UIKBTree *key in subBottomRow.subtrees) {
		[displayStrings addObject:key.displayString];
		[representedStrings addObject:key.representedString];
	}

	// is there space to add the ellipsis?
	if (displayStrings.count < origBottomRow.subtrees.count) {
		int i = 2;
		[displayStrings insertObject:@"…" atIndex:i];
		[representedStrings insertObject:@"…" atIndex:i];
	}

	// iOS doesn't seem to care *what* key is assigned to gestureKey
	// ... so we just fake it
	// (nil also seems to work, in preliminary testing)
	UIKBTree *surrogateKey = subBottomRow.subtrees.firstObject;

	int mapCount = MIN(origBottomRow.subtrees.count, displayStrings.count);
	NSLog(@"mapping %d keys", mapCount);
	for (int i = 0; i < mapCount; i++) {
		UIKBTree *origKey = [origBottomRow.subtrees objectAtIndex:i];

		origKey.secondaryDisplayStrings = @[[displayStrings objectAtIndex:i]];
		origKey.secondaryRepresentedStrings = @[[representedStrings objectAtIndex:i]];
		origKey.displayTypeHint = 10; // this enables the gesture behaviour!
		origKey.gestureKey = surrogateKey;
	}
	NSLog(@"all done");
}
%end

%hook TUIKBGraphSerialization

- (UIKBTree *)keyboardForName:(NSString *)name {
	// TODO: do not patch the same keyboard multiple times!
	NSLog(@"Requesting deserialisation of keyboard %@", name);
	UIKBTree *tree = %orig;

	for (UIKBTree *keyplane in tree.subtrees) {
		if ([keyplane.name hasSuffix:@"-Letters"] || [keyplane.name hasSuffix:@"-Letters-Small-Display"]) {
			NSString *other = [keyplane alternateKeyplaneName];
			[keyplane setObject:other forProperty:@"gesture-keyplane"];
		}

		if ([keyplane.name hasSuffix:@"_Numbers-And-Punctuation"]) {
			NSString *other = [keyplane shiftAlternateKeyplaneName];
			[keyplane setObject:other forProperty:@"gesture-keyplane"];
		}
	}

	return tree;
}

%end

%hook TIPreferencesController
- (bool)boolForPreferenceKey:(NSString *)key {
	if ([key isEqualToString:@"GesturesEnabled"]) {
		return YES;
	} else {
		return %orig;
	}
}
%end

%group SpringBoard
%hook SpringBoard
// clear the KB cache on respring
- (void)applicationDidFinishLaunching:(id)application {
	[[%c(UIKeyboardCache) sharedInstance] purge];
	%orig;
}
%end
%end

%ctor {
	NSLog(@"Doing it!!");

	// trick thanks to poomsmart
	// https://github.com/PoomSmart/EmojiPort-Legacy/blob/8573de11226ac2e1c4108c044078109dbfb07a02/KBResizeLegacy.xm
	dlopen("/System/Library/PrivateFrameworks/TextInputUI.framework/TextInputUI", RTLD_LAZY);

	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		%init(SpringBoard);
	}

	%init;
}
