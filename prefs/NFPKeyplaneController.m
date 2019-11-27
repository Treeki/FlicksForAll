#include "NFPKeyplaneController.h"
#import <Preferences/PSSpecifier.h>
#import "NFPKeyPropsController.h"
#import "../Utils.h"
#import <Cephei/HBPreferences.h>
#include <objc/runtime.h>
#import <notify.h>

// not nice, but Theos is missing this >.<
@interface PSConfirmationSpecifier : PSSpecifier
@property(retain, nonatomic) NSString *prompt;
@property(retain, nonatomic) NSString *title;
@property(retain, nonatomic) NSString *okButton;
@property(retain, nonatomic) NSString *cancelButton;
@end

@interface PSSpecifier (MissingStuff)
- (id)performGetter;
@end

@interface PSTableCell (MissingStuff)
- (void)setValue:(id)value;
@end

@interface NFPForcedValueTableCell : PSTableCell
@end

@implementation NFPForcedValueTableCell
// because PSLinkCell doesn't get a value by default
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
	[super refreshCellContentsWithSpecifier:specifier];
	self.value = [specifier performGetter];
}
@end

@interface UIKBTree (FlickPlus)
- (NSDictionary *)nfpGenerateKeylayoutConfigBasedOffKeylayout:(UIKBTree *)subLayout inKeyplane:(UIKBTree *)keyplane rewriteCapitalToSmall:(BOOL)capsToSmall;
@end

enum {
	scClearAll,
	scCopyFromPlane
};

@implementation NFPKeyplaneController

- (NSArray *)selectAlternativeKeyplanesFrom:(UIKBTree *)keyboard ignoringPlane:(UIKBTree *)planeToIgnore {
	NSMutableArray *results = [NSMutableArray array];

	for (UIKBTree *plane in keyboard.subtrees) {
		if (plane == planeToIgnore)
			continue;
		if ([plane.name containsString:@"Letters"])
			continue;

		[results addObject:plane];
	}

	return results;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specs = [NSMutableArray array];

		NSString *layoutName = [self.specifier propertyForKey:@"fp-layout-name"];
		_keyboard = [self.specifier propertyForKey:@"fp-keyboard"];
		_keyplane = [self.specifier propertyForKey:@"fp-keyplane"];

		NSString *slicedKeyplaneName = [_keyplane.name sliceAfterLastUnderscore];
		self.title = [slicedKeyplaneName hyphensToSpaces];

		_hbPrefs = [[HBPreferences alloc] initWithIdentifier:@"org.wuffs.flickplus"];
		_prefKey = [NSString stringWithFormat:@"kb-%@--%@--flicks", layoutName, slicedKeyplaneName];
		NSDictionary *storedConfig = [_hbPrefs objectForKey:_prefKey];
		if (storedConfig == nil) {
			UIKBTree *keylayout = _keyplane.subtrees[0];
			UIKBTree *gestureKeyplane = [_keyboard subtreeWithName:_keyplane.gestureKeyplaneName];
			if (gestureKeyplane) {
				NSLog(@"NFPKeyplaneController creating new default config with gestureKeyplane=%@", gestureKeyplane.name);
				UIKBTree *gestureKeylayout = gestureKeyplane.subtrees[0];
				_configData = [[keylayout nfpGenerateKeylayoutConfigBasedOffKeylayout:gestureKeylayout inKeyplane:_keyplane rewriteCapitalToSmall:NO] mutableCopy];
			} else {
				NSLog(@"NFPKeyplaneController creating new blank config");
				_configData = [NSMutableDictionary dictionary];
			}
		} else {
			NSLog(@"NFPKeyplaneController loading existing config");
			_configData = [storedConfig mutableCopy];
		}

		// Spawn some templates
		[self addTemplateSpecTo:specs named:@"Clear All Shortcuts" withEnum:scClearAll andExtra:nil];

		NSArray *alternativeKeyplanes = [self selectAlternativeKeyplanesFrom:_keyboard ignoringPlane:_keyplane];
		if (alternativeKeyplanes.count > 0) {
			PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Templates"];
			[group setProperty:@"Sets up shortcuts so that flicking a key will give you the corresponding key on the other page, like the default iPad keyboard. A good default starting point." forKey:@"footerText"];
			[specs addObject:group];

			for (UIKBTree *alternative in alternativeKeyplanes) {
				NSString *name = [@"Keys from " stringByAppendingString:[[alternative.name sliceAfterLastUnderscore] hyphensToSpaces]];
				[self addTemplateSpecTo:specs named:name withEnum:scCopyFromPlane andExtra:alternative.name];
			}
		}

		// Spawn all keys
		for (UIKBTree *keylayout in _keyplane.subtrees) {
			if (keylayout.type != 3)
				continue;
			
			NSString *niceKeylayoutName = [keylayout.name sliceAfterLastUnderscore];
			niceKeylayoutName = [niceKeylayoutName hyphensToSpaces];
			niceKeylayoutName = [niceKeylayoutName stringByReplacingOccurrencesOfString:@"iPhone " withString:@""];
			UIKBTree *keySet = [keylayout keySet];

			for (UIKBTree *list in keySet.subtrees) {
				NSString *niceListName = [list.name sliceAfterLastUnderscore];
				niceListName = [niceListName stringByReplacingOccurrencesOfString:@"Row" withString:@"Row "];
				niceListName = [NSString stringWithFormat:@"%@: %@", niceKeylayoutName, niceListName];

				PSSpecifier *group = [PSSpecifier groupSpecifierWithName:niceListName];
				[specs addObject:group];

				for (UIKBTree *key in list.subtrees) {
					PSSpecifier *keySpec = [PSSpecifier
						preferenceSpecifierNamed:[self niceLabelForKey:key]
						target:self
						set:NULL
						get:@selector(shortcutTextForKeySpecifier:)
						detail:objc_getClass("PSSetupController")
						cell:PSLinkCell
						edit:Nil];
					[keySpec setProperty:[NFPForcedValueTableCell class] forKey:@"cellClass"];
					[keySpec setProperty:@"NFPKeyPropsController" forKey:@"customControllerClass"];
					[keySpec setProperty:key forKey:@"fp-key"];
					[keySpec setProperty:_configData[key.name] forKey:@"fp-key-config"];
					[specs addObject:keySpec];
				}
			}

			// for now, only show the first keylayout...
			break;
		}

		_specifiers = specs;
	}

	return _specifiers;
}


- (NSString *)niceLabelForKey:(UIKBTree *)key {
	switch (key.displayType) {
		case 0: // String
		case 8: // DynamicString
			return key.displayString;
		default:
			return [NSString stringWithFormat:@"<Type %i>", key.displayType];
	}
}


- (void)addTemplateSpecTo:(NSMutableArray *)specs named:(NSString *)name withEnum:(int)shortcut andExtra:(NSString *)extra {
	PSConfirmationSpecifier *spec = [PSConfirmationSpecifier
		preferenceSpecifierNamed:name
		target:self
		set:NULL
		get:NULL
		detail:Nil
		cell:PSButtonCell
		edit:Nil];
	spec.confirmationAction = @selector(processTemplate:);
	if (shortcut == scClearAll)
		spec.prompt = @"All the existing shortcuts on this page will be removed.";
	else
		spec.prompt = @"All the existing shortcuts on this page will be removed and replaced with new ones.";
	spec.title = @"Continue";
	spec.okButton = @"Continue"; // the fuck does this do...?
	spec.cancelButton = @"Cancel";
	[spec setProperty:[NSNumber numberWithInt:shortcut] forKey:@"fp-shortcut"];
	[spec setProperty:extra forKey:@"fp-shortcut-extra"];
	[specs addObject:spec];
}


- (void)processTemplate:(PSSpecifier *)specifier {
	int shortcut = [[specifier propertyForKey:@"fp-shortcut"] integerValue];

	if (shortcut == scClearAll) {
		[_configData removeAllObjects];
	} else if (shortcut == scCopyFromPlane) {
		NSString *srcKeyplaneName = [specifier propertyForKey:@"fp-shortcut-extra"];
		UIKBTree *srcKeyplane = [_keyboard subtreeWithName:srcKeyplaneName];
		UIKBTree *srcKeylayout = srcKeyplane.subtrees[0];
		UIKBTree *destKeylayout = _keyplane.subtrees[0];
		_configData = [[destKeylayout nfpGenerateKeylayoutConfigBasedOffKeylayout:srcKeylayout inKeyplane:_keyplane rewriteCapitalToSmall:NO] mutableCopy];
	}

	// give all key specifiers back the latest info
	for (PSSpecifier *specifier in _specifiers) {
		UIKBTree *key = [specifier propertyForKey:@"fp-key"];
		if (key != nil) {
			NSArray *keyData = _configData[key.name];
			if (keyData == nil)
				[specifier removePropertyForKey:@"fp-key-config"];
			else
				[specifier setProperty:keyData forKey:@"fp-key-config"];
			[self reloadSpecifier:specifier];
		}
	}
	[self writeSettings];
}


- (NSString *)shortcutTextForKeySpecifier:(PSSpecifier *)specifier {
	NSArray *info = [specifier propertyForKey:@"fp-key-config"];
	if (info != nil) {
		if (info.count == 2)
			return info[0];
		else if (info.count == 4)
			return [NSString stringWithFormat:@"%@ / %@", info[0], info[2]];
	}
	return @"";
}


- (void)saveKeyInfoBackFrom:(NFPKeyPropsController *)kpc {
	PSSpecifier *specifier = kpc.specifier;
	UIKBTree *key = [specifier propertyForKey:@"fp-key"];

	switch (kpc.mode) {
		case NFPModeNothing:
			[_configData removeObjectForKey:key.name];
			break;
		case NFPModeText:
			_configData[key.name] = @[
				kpc.representedString, kpc.displayString
			];
			break;
		case NFPModeDual:
			_configData[key.name] = @[
				kpc.leftRepresentedString, kpc.leftDisplayString,
				kpc.rightRepresentedString, kpc.rightDisplayString
			];
			break;
	}

	[specifier setProperty:_configData[key.name] forKey:@"fp-key-config"];
	[self reloadSpecifier:specifier];
	[self writeSettings];
}


- (void)writeSettings {
	[_hbPrefs setObject:[NSDictionary dictionaryWithDictionary:_configData] forKey:_prefKey];
	notify_post("org.wuffs.flickplus/ReloadPrefs");
}

@end

