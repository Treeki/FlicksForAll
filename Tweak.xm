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
#include "h/UIKBKeyView.h"
#include "h/UIKBKeyViewAnimator.h"
#include <dlfcn.h>
#include <version.h>
#include "Utils.h"

#ifndef FP_NO_CEPHEI
#include <Cephei/HBPreferences.h>
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_13_0
#define kCFCoreFoundationVersionNumber_iOS_13_0 1665.15
#endif

#ifndef FP_NO_CEPHEI
static HBPreferences *preferences;
#else
@interface NSUserDefaults (Private)
- (instancetype)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end
static NSUserDefaults *preferences;
#endif
static NSMutableDictionary *kbPropCache;
static NSString *lightSymbolsColour, *darkSymbolsColour;
static bool hapticFeedbackEnabled = YES;
static double symbolFontScale = 1.0;

static id kbFetchProp(NSString *key) {
	id value = kbPropCache[key];
	if (value == nil) {
		value = [preferences objectForKey:key];
		kbPropCache[key] = value;
	}
	return value;
}

@interface _UIClickFeedbackGenerator : UIFeedbackGenerator
-(id)initWithCoordinateSpace:(id)arg1;
-(void)pressedDown;
-(void)pressedUp;
@end

static bool lieAboutGestureKeys = false;
static bool doingDragOnKey = false;
static _UIClickFeedbackGenerator *clickFeedback = nil;
static bool lastFeedbackWasDown = false;

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
		if (clickFeedback != nil) {
			// if we played a click-down feedback, nullify it
			// to signal to the user that the flick is now off-limitsb
			if (lastFeedbackWasDown)
				[clickFeedback pressedUp];
			clickFeedback = nil;
		}

		lieAboutGestureKeys = true;
		%orig;
		lieAboutGestureKeys = false;
	} else {
		%orig;
	}
}

- (void)updatePanAlternativesForTouchInfo:(UIKeyboardTouchInfo *)touchInfo {
	if (clickFeedback == nil && hapticFeedbackEnabled) {
		// delaying the prepare call might be possible slightly
		// to potentially save a bit of battery
		clickFeedback = [[_UIClickFeedbackGenerator alloc] initWithCoordinateSpace:self];
		[clickFeedback prepare];
		lastFeedbackWasDown = false;
	}

	doingDragOnKey = true;
	%orig;
	doingDragOnKey = false;
}

- (void)resetPanAlternativesForEndedTouch:(id)touch {
	if (clickFeedback != nil) {
		clickFeedback = nil;
	}
}
%end

%hook UIKBTree
- (void)setSelectedVariantIndex:(long long)index {
	if (doingDragOnKey && clickFeedback != nil) {
		if (self.selectedVariantIndex != index) {
			if (index == 0 || index == 1) {
				[clickFeedback pressedDown];
				lastFeedbackWasDown = true;
			} else {
				[clickFeedback pressedUp];
				lastFeedbackWasDown = false;
			}
		}
	}
	%orig;
}
%end

@implementation UIKBTree (FlickPlus)
- (NSDictionary *)nfpGenerateKeylayoutConfigBasedOffKeylayout:(UIKBTree *)subLayout inKeyplane:(UIKBTree *)keyplane rewriteCapitalToSmall:(BOOL)capsToSmall {
	// context: keylayout (NOT keyplane!)
	if (subLayout == nil) {
		NSLog(@"nfpGenerateKeylayoutConfigBasedOffKeylayout passed null sublayout!");
		return [NSDictionary dictionary];
	}

	// mostly same as pre-0.0.6 versions of the tweak
	NSMutableDictionary *result = [NSMutableDictionary dictionary];

	UIKBTree *thisKeyset = self.keySet, *subKeyset = subLayout.keySet;

	UIKBTree *thisTopRow = thisKeyset.subtrees[0];
	UIKBTree *thisMiddleRow = thisKeyset.subtrees[1];
	UIKBTree *thisBottomRow = thisKeyset.subtrees[2];
	UIKBTree *subTopRow = subKeyset.subtrees[0];
	UIKBTree *subMiddleRow = subKeyset.subtrees[1];
	UIKBTree *subBottomRow = subKeyset.subtrees[2];

	// top row is mapped as-is
	int count = MIN(thisTopRow.subtrees.count, subTopRow.subtrees.count);
	for (int i = 0; i < count; i++) {
		UIKBTree *thisKey = thisTopRow.subtrees[i], *subKey = subTopRow.subtrees[i];
		NSString *cleanName = [thisKey.name stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];
		if (capsToSmall) cleanName = [cleanName stringByReplacingOccurrencesOfString:@"-Capital-Letter" withString:@"-Small-Letter"];
		result[cleanName] = @[subKey.representedString, subKey.displayString];
	}

	// middle row is mapped as-is
	count = MIN(thisMiddleRow.subtrees.count, subMiddleRow.subtrees.count);
	for (int i = 0; i < count; i++) {
		UIKBTree *thisKey = thisMiddleRow.subtrees[i], *subKey = subMiddleRow.subtrees[i];
		NSString *cleanName = [thisKey.name stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];
		if (capsToSmall) cleanName = [cleanName stringByReplacingOccurrencesOfString:@"-Capital-Letter" withString:@"-Small-Letter"];
		result[cleanName] = @[subKey.representedString, subKey.displayString];
	}

	// bottom row requires a bit more work
	NSMutableArray *bottomKeys = [NSMutableArray array];
	if (thisMiddleRow.subtrees.count == (subMiddleRow.subtrees.count - 1)) {
		// carry the last key over if it's been left behind
		UIKBTree *subKey = subMiddleRow.subtrees.lastObject;
		[bottomKeys addObject:@[subKey.representedString, subKey.displayString]];
	}

	for (UIKBTree *subKey in subBottomRow.subtrees) {
		[bottomKeys addObject:@[subKey.representedString, subKey.displayString]];
	}

	// add the ellipsis because it's cool
	if ([keyplane.name containsString:@"-Letters"] && bottomKeys.count < thisBottomRow.subtrees.count) {
		[bottomKeys insertObject:@[@"…", @"…"] atIndex:2];
	}

	// now shove all those in
	count = MIN(thisBottomRow.subtrees.count, bottomKeys.count);
	for (int i = 0; i < count; i++) {
		UIKBTree *thisKey = thisBottomRow.subtrees[i];
		NSString *cleanName = [thisKey.name stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];
		if (capsToSmall) cleanName = [cleanName stringByReplacingOccurrencesOfString:@"-Capital-Letter" withString:@"-Small-Letter"];
		if (![thisKey.representedString isEqualToString:bottomKeys[i][0]])
			result[cleanName] = bottomKeys[i];
	}

	// NSLog(@"Built:: %@", result);
	return [NSDictionary dictionaryWithDictionary:result];
}
@end



extern "C" {
NSString *UIKeyboardGetCurrentInputMode();
NSString *UIKeyboardLocalizedString(NSString *key, NSString *language, NSString *unk, NSString *def);
id UIKeyboardLocalizedObject(NSString *key, NSString *language, NSString *unk, id def, BOOL unk2);
};

@interface NSLocale (MissingStuff)
+ (NSLocale *)preferredLocale; // iOS 13+
+ (NSLocale *)_UIKBPreferredLocale; // iOS 12
@end

%group Polyfill12
%hook NSLocale
%new + (NSLocale *)preferredLocale {
	return [NSLocale _UIKBPreferredLocale];
}
%end
%end

static NSString *currencyFix(NSString *str) {
	// based heavily off the logic in -[UIKeyboardLayoutStar setCurrencyKeysForCurrentLocaleOnKeyplane:]
	NSString *localObjName = nil, *defChar = nil;
	if ([str isEqualToString:@"¤1"]) {
		localObjName = @"UI-PrimaryCurrencySign";
		defChar = @"$";
	} else if ([str isEqualToString:@"¤2"]) {
		localObjName = @"UI-AlternateCurrencySign-1";
		defChar = @"€";
	} else if ([str isEqualToString:@"¤3"]) {
		localObjName = @"UI-AlternateCurrencySign-2";
		defChar = @"@";
	} else if ([str isEqualToString:@"¤4"]) {
		localObjName = @"UI-AlternateCurrencySign-3";
		defChar = @"¥";
	} else if ([str isEqualToString:@"¤5"]) {
		localObjName = @"UI-AlternateCurrencySign-4";
		defChar = @"₩";
	} else {
		return str;
	}

	// could probably optimise things by caching some of these calls...?
	str = UIKeyboardLocalizedObject(localObjName, [[NSLocale preferredLocale] localeIdentifier], 0, 0, NO);
	if (!str)
		str = UIKeyboardLocalizedString(localObjName, UIKeyboardGetCurrentInputMode(), 0, defChar);
	return str;
}

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
	NSLog(@"I'm being patched...! %@ -> %@", self.name, [self stringForProperty:@"fp-kb-name"]);

	// two cases:
	//    altflag is capsAreSeparate
	//    true  -> two planes, one Capital, one Small
	//    false -> one Small plane, used for both
	//    in which case we need to do special work on Capital plane
	BOOL replaceCapitalBySmall = NO;

	NSString *kbName = [self stringForProperty:@"fp-kb-name"];
	if (kbName == nil)
		return;

	if ([self.name hasSuffix:@"Capital-Letters"]) {
		// we might need to fallback
		NSString *propName = [self stringForProperty:@"fp-kb-altflag"];
		id flag = kbFetchProp(propName);
		if (![flag boolValue]) {
			// user is not using separate caps
			// so, use the Small plane, and pretend every key is Small
			kbName = [self stringForProperty:@"fp-kb-altname"];
			replaceCapitalBySmall = YES;
			if (flag == nil)
				kbPropCache[propName] = @NO;
		}
	}

	NSDictionary *config = kbFetchProp(kbName);
	if (config == nil) {
		NSLog(@"Can't find config %@!! Using a default...", kbName);
		UIKBTree *keylayout = self.subtrees[0];
		UIKBTree *subKeylayout = keylayout.cachedGestureLayout;
		config = [keylayout nfpGenerateKeylayoutConfigBasedOffKeylayout:subKeylayout inKeyplane:self rewriteCapitalToSmall:replaceCapitalBySmall];
		// we store this in the propcache but not to preferences
		kbPropCache[kbName] = config;
	}

	for (UIKBTree *keylayout in self.subtrees) {
		if (keylayout.type != 3)
			continue;

		UIKBTree *keySet = [keylayout keySet];
		
		for (UIKBTree *list in keySet.subtrees) {
			for (UIKBTree *key in list.subtrees) {
				if (key.displayType == 0 || key.displayType == 8) {
					NSString *checkName = [key.name stringByReplacingOccurrencesOfString:@"-Small-Display" withString:@""];
					if (replaceCapitalBySmall)
						checkName = [checkName stringByReplacingOccurrencesOfString:@"-Capital" withString:@"-Small"];

					NSArray *cfgKey = config[checkName];
					if (cfgKey == nil) {
						// NSLog(@"map for %@ not found", checkName);
						if (key.displayTypeHint == 10) {
							// clear existing gesture keys just in case
							key.displayTypeHint = 0;
						}
					} else if (cfgKey.count == 2) {
						// NSLog(@"map for %@ found -> %@", checkName, cfgKey);
						// text key
						key.displayTypeHint = 10;
						NSString *rep = cfgKey[0], *disp = cfgKey[1];
						if ([rep hasPrefix:@"¤"]) rep = currencyFix(rep);
						if ([disp hasPrefix:@"¤"]) disp = currencyFix(disp);
						key.secondaryRepresentedStrings = @[rep];
						key.secondaryDisplayStrings = @[
							(disp && disp.length) ? disp : rep
						];
					} else if (cfgKey.count == 4) {
						// dual key
						key.displayTypeHint = 10;
						NSString *repA = cfgKey[0], *dispA = cfgKey[1];
						NSString *repB = cfgKey[2], *dispB = cfgKey[3];
						if ([repA hasPrefix:@"¤"]) repA = currencyFix(repA);
						if ([repB hasPrefix:@"¤"]) repB = currencyFix(repB);
						if ([dispA hasPrefix:@"¤"]) dispA = currencyFix(dispA);
						if ([dispB hasPrefix:@"¤"]) dispB = currencyFix(dispB);
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

	// for now, we exclude certain ones...
	if ([cleanName hasSuffix:@"-URL"]) return tree;
	if ([cleanName hasSuffix:@"-NumberPad"]) return tree;
	if ([cleanName hasSuffix:@"-PhonePad"]) return tree;
	if ([cleanName hasSuffix:@"-NamePhonePad"]) return tree;
	if ([cleanName hasSuffix:@"-Email"]) return tree;
	if ([cleanName hasSuffix:@"-DecimalPad"]) return tree;
	if ([cleanName hasSuffix:@"-AlphaWithURL"]) return tree;
	if ([cleanName containsString:@"Emoji"]) return tree;

	// Twitter keyboard just uses standard stuff
	if ([cleanName hasSuffix:@"-Twitter"])
		cleanName = [cleanName substringToIndex:(cleanName.length - 8)];

	// take out iPhone-{variant}-
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

		// this is necessary so that cachedGestureLayout will be set
		// which we need when calling nfpGenerateKeylayoutConfigBasedOffKeylayout
		// to generate a default config
		if ([cleanPlaneName hasSuffix:@"Letters"])
			[keyplane setObject:[keyplane alternateKeyplaneName] forProperty:@"gesture-keyplane"];
		else if ([cleanPlaneName isEqualToString:@"Numbers-And-Punctuation"])
			[keyplane setObject:[keyplane shiftAlternateKeyplaneName] forProperty:@"gesture-keyplane"];
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
			style.fontSize *= symbolFontScale;
		}

		// force the blurred background to be applied to light KB
		// stops the label from showing through and making things weird
		if (!self.allowsPaddles)
			traits.blurBlending = YES;
	}

	return traits;
}
%end

// make animations less of a disaster
enum AnimHackMode { AHMNone, AHMPaddles, AHMNoPaddles };
static AnimHackMode animHackMode = AHMNone;

static void enterAnimHackMode(UIKBKeyView *keyView) {
	// TODO: might want to check the keyboard's interface idiom
	// in case people decide to run this on an iPad
	animHackMode = keyView.factory.allowsPaddles ? AHMPaddles : AHMNoPaddles;
}

static void endAnimHackMode(UIKBKeyView *keyView) {
	animHackMode = AHMNone;
}

%hook UIKBKeyViewAnimator
- (void)transitionKeyView:(UIKBKeyView *)keyView fromState:(int)from toState:(int)to completion:(void *)c {
	enterAnimHackMode(keyView);
	%orig;
	if (animHackMode != AHMNone) {
		// force the symbol opacity to zero
		// we can't change a double constant with a simple hook, alas
		UIKBTree *key = keyView.key;
		if (to == 4 && key.displayType != 7 && key.displayTypeHint == 10) {
			CALayer *symbolLayer = [keyView layerForRenderFlags:16];
			if (symbolLayer)
				symbolLayer.opacity = 0;
		}
	}
	endAnimHackMode(keyView);
}
- (void)updateTransitionForKeyView:(UIKBKeyView *)keyView normalizedDragSize:(CGSize)size {
	enterAnimHackMode(keyView);
	%orig;
	endAnimHackMode(keyView);
}
- (void)endTransitionForKeyView:(UIKBKeyView *)keyView {
	enterAnimHackMode(keyView);
	%orig;
	endAnimHackMode(keyView);
}
+ (id)normalizedAnimationWithKeyPath:(NSString *)path fromValue:(id)from toValue:(id)to {
	// we want to force symbol opacity to 0...
	if (animHackMode != AHMNone && [path isEqualToString:@"opacity"]) {
		// awful kludge alert!!
		double v = [from doubleValue];
		if (v >= 0.2 && v <= 0.35) {
			return %orig(path, @0, to);
		}
	}
	return %orig;
}
+ (id)normalizedUnwindOpacityAnimationWithKeyPath:(NSString *)path originallyFromValue:(id)from toValue:(id)to offset:(double)offset {
	// it's a great day in UIKit, and you are a horrible goose
	if (animHackMode != AHMNone && [path isEqualToString:@"opacity"]) {
		// awful kludge alert!! (part 2)
		double v = [from doubleValue];
		if (v >= 0.2 && v <= 0.35) {
			return %orig(path, @0, to, offset);
		}
	}
	return %orig;
}

- (id)keycapPrimaryTransform {
	// don't relocate the primary keycap, at all
	if (animHackMode == AHMNone)
		return %orig;
	else
		return self.keycapNullTransform;
}

- (id)keycapAlternateTransform:(UIKBKeyView *)keyView {
	// move the symbol out of view at the top
	// not ideal, but it's less glitchy-looking than the default...
	if (animHackMode == AHMNone)
		return %orig;
	else {
		return [self keycapMeshTransformFromRect:CGRectMake(0.115, 0.28, 0.77, 0.44)
		                                  toRect:CGRectMake(0.5, 0, 0, 0)];
	}
	// eventually, it would be good to render paddle-less mode to match
	// the non-pressed keys, but that requires more work to determine the
	// correct rects for all configurations
}

// TODO: do similar stopgap animations for the left/right bits
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


static void syncPreferences() {
	lightSymbolsColour = resolveColour([preferences objectForKey:@"lightSymbols"]);
	darkSymbolsColour = resolveColour([preferences objectForKey:@"darkSymbols"]);
	hapticFeedbackEnabled = [preferences boolForKey:@"hapticFeedback"];
	symbolFontScale = [preferences boolForKey:@"smallSymbols"] ? 0.7 : 1.0;
	[kbPropCache removeAllObjects];
	[[%c(UIKeyboardCache) sharedInstance] purge];
	// maybe also [UIKBRenderer clearInternalCaches] ??
}


%ctor {
	kbPropCache = [NSMutableDictionary dictionary];

#ifndef FP_NO_CEPHEI
	preferences = [[HBPreferences alloc] initWithIdentifier:@"org.wuffs.flickplus"];
	[preferences registerDefaults:@{
		@"lightSymbols": @"lgrey",
		@"darkSymbols": @"lgrey",
		@"hapticFeedback": @YES,
		@"smallSymbols": @NO
	}];
	[preferences registerPreferenceChangeBlock:^{
		syncPreferences();
	}];
#else
	preferences = [[NSUserDefaults alloc] _initWithSuiteName:@"org.wuffs.flickplus" container:[NSURL URLWithString:@"/var/mobile"]];
	// TODO watch for a thing, probably
	syncPreferences();
#endif

	// trick thanks to poomsmart
	// https://github.com/PoomSmart/EmojiPort-Legacy/blob/8573de11226ac2e1c4108c044078109dbfb07a02/KBResizeLegacy.xm
	dlopen("/System/Library/PrivateFrameworks/TextInputUI.framework/TextInputUI", RTLD_LAZY);

	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		%init(SpringBoard);
	}

	if (!IS_IOS_OR_NEWER(iOS_13_0)) {
		%init(Polyfill12);
	}
	%init;
}
