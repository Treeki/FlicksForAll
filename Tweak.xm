#include "h/UIKBTree.h"
#include "h/UIKeyboardCache.h"
#include "h/UIKBTouchState.h"
#include "h/UIKeyboardTaskExecutionContext.h"
#include "h/UIKeyboardTouchInfo.h"
#include "h/UIKeyboardLayout.h"
#include "h/UIKeyboardLayoutStar.h"
#include "h/UIKBTextStyle.h"
#include "h/UIKBRenderTraits.h"
#include "h/UIKBRenderConfig.h"
#include "h/UIKBRenderFactory.h"
#include "h/UIKBRenderFactoryiPhone.h"
#include "Utils.h"
#include <Cephei/HBPreferences.h>

static HBPreferences *preferences;
static NSMutableDictionary *kbPropCache;
static NSString *lightSymbolsColour, *darkSymbolsColour;

static id kbFetchProp(NSString *key) {
	id value = kbPropCache[key];
	if (value == nil) {
		value = preferences[key];
		kbPropCache[key] = value;
	}
	return value;
}

static bool lieAboutGestureKeys = false;

// looks like we need this silliness
// else the compiler complains that it doesn't know about fpAllow
@interface UIKeyboardTouchInfo (FlickPlus)
@property (nonatomic, assign) bool fpAllow;
@end

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

	// NSLog(@"delta:%f,%f distanceSq:%f", deltaX, deltaY, distanceSq);
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
	// it's Keyboard Fun Time!
	// we are in a keyplane, we need to know what keyboard we are
	NSLog(@"I'm being patched...! %@", [self stringForProperty:@"fp-kb-name"]);

	NSString *kbName = [self stringForProperty:@"fp-kb-name"];
	if ([self.name hasSuffix:@"Capital-Letters"]) {
		// we might need to fallback
		id flag = kbFetchProp([self stringForProperty:@"fp-kb-altflag"]);
		if (![flag boolValue]) {
			// user is not using separate caps
			kbName = [self stringForProperty:@"fp-kb-altname"];
		}
	}

	NSDictionary *config = kbFetchProp(kbName);
	if (config == nil) {
		// warn...?
		NSLog(@"Can't find config %@!!", kbName);
		return;
	}

	for (UIKBTree *keylayout in self.subtrees) {
		if (keylayout.type != 3)
			continue;

		UIKBTree *keySet = [keylayout keySet];
		
		for (UIKBTree *list in keySet.subtrees) {
			for (UIKBTree *key in list.subtrees) {
				if (key.displayType == 0 || key.displayType == 8) {
					NSString *checkName = [key.name stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];
					NSArray *cfgKey = config[checkName];
					if (cfgKey == nil) {
						if (key.displayTypeHint == 10) {
							// clear existing gesture keys just in case
							key.displayTypeHint = 0;
						}
					} else if (cfgKey.count == 2) {
						// text key
						key.displayTypeHint = 10;
						NSString *rep = cfgKey[0], *disp = cfgKey[1];
						key.secondaryRepresentedStrings = @[rep];
						key.secondaryDisplayStrings = @[
							(disp && disp.length) ? disp : rep
						];
					} else if (cfgKey.count == 4) {
						// dual key
						key.displayTypeHint = 10;
						NSString *repA = cfgKey[0], *dispA = cfgKey[1];
						NSString *repB = cfgKey[2], *dispB = cfgKey[3];
						key.secondaryRepresentedStrings = @[repA, repB];
						key.secondaryDisplayStrings = @[
							(dispA && dispA.length) ? dispA : repA,
							(dispB && dispB.length) ? dispB : repB
						];
					}
				}
			}
		}
	}
}
%end

%hook TUIKBGraphSerialization

- (UIKBTree *)keyboardForName:(NSString *)name {
	// TODO: do not patch the same keyboard multiple times!
	NSLog(@"Requesting deserialisation of keyboard %@", name);
	UIKBTree *tree = %orig;

	NSString *cleanName = name;
	if ([cleanName hasPrefix:@"iPhone-"]) {
		NSRange searchRange = NSMakeRange(7, cleanName.length - 7);
		NSUInteger secondHyphen = [cleanName rangeOfString:@"-" options:0 range:searchRange].location;
		if (secondHyphen != NSNotFound)
			cleanName = [cleanName substringFromIndex:secondHyphen + 1];
	}

	for (UIKBTree *keyplane in tree.subtrees) {
		NSString *cleanPlaneName = [keyplane.name sliceAfterLastUnderscore];
		cleanPlaneName = [cleanPlaneName stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];

		NSString *mainName = [NSString stringWithFormat:@"kb-%@--%@--flicks", cleanName, cleanPlaneName];
		[keyplane setObject:mainName forProperty:@"fp-kb-name"];
		if ([cleanPlaneName isEqualToString:@"Capital-Letters"]) {
			NSString *flagName = [NSString stringWithFormat:@"kb-%@-capsAreSeparate", cleanName];
			[keyplane setObject:flagName forProperty:@"fp-kb-altflag"];
			NSString *altName = [NSString stringWithFormat:@"kb-%@--Small-Letters--flicks", cleanName];
			[keyplane setObject:altName forProperty:@"fp-kb-altname"];
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


// recolour the symbols

%hook UIKBRenderFactoryiPhone
- (UIKBRenderTraits *)_traitsForKey:(UIKBTree *)key onKeyplane:(UIKBTree *)plane {
	UIKBRenderTraits *traits = %orig;

	NSArray *styles = traits.secondarySymbolStyles;
	if (styles != nil) {
		NSString *which = self.renderConfig.lightKeyboard ? lightSymbolsColour : darkSymbolsColour;

		for (UIKBTextStyle *style in styles) {
			style.textColor = which;
			style.textOpacity = 1.0;
		}
	}

	return traits;
}
%end


static NSString *resolveColour(NSString *name) {
	if ([name isEqualToString:@"white"]) {
		return @"UIKBColorWhite";
	} else if ([name isEqualToString:@"lgrey"]) {
		return @"UIKBColorGray_Percent68";
	} else if ([name isEqualToString:@"dgrey"]) {
		return @"UIKBColorGray_Percent31_37";
	} else if ([name isEqualToString:@"black"]) {
		return @"UIKBColorBlack";
	} else {
		return @"UIKBColorRed";
	}
}


%ctor {
	kbPropCache = [NSMutableDictionary dictionary];

	preferences = [[HBPreferences alloc] initWithIdentifier:@"org.wuffs.flickplus"];
	[preferences registerDefaults:@{
		@"lightSymbols": @"lgrey",
		@"darkSymbols": @"lgrey"
	}];
	[preferences registerPreferenceChangeBlock:^{
		NSLog(@"I'm %@ and I've seen a change!", [[NSBundle mainBundle] bundleIdentifier]);
		lightSymbolsColour = resolveColour([preferences objectForKey:@"lightSymbols"]);
		darkSymbolsColour = resolveColour([preferences objectForKey:@"darkSymbols"]);
		NSLog(@"Now using %@ and %@", lightSymbolsColour, darkSymbolsColour);
		[kbPropCache removeAllObjects];
		[[%c(UIKeyboardCache) sharedInstance] purge];
		// maybe also [UIKBRenderer clearInternalCaches] ??
	}];

	// trick thanks to poomsmart
	// https://github.com/PoomSmart/EmojiPort-Legacy/blob/8573de11226ac2e1c4108c044078109dbfb07a02/KBResizeLegacy.xm
	dlopen("/System/Library/PrivateFrameworks/TextInputUI.framework/TextInputUI", RTLD_LAZY);

	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		%init(SpringBoard);
	}

	%init;
}
