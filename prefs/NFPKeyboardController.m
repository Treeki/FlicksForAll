#include "NFPKeyboardController.h"
#import "NFPKeyplaneController.h"
#import <Preferences/PSSpecifier.h>
#import "../Utils.h"
#include <objc/runtime.h>

@implementation NFPKeyboardController

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specs = [NSMutableArray array];

		NSString *layoutName = [self.specifier propertyForKey:@"fp-keyboard-layout"];
		NSLog(@"Gonna edit %@", layoutName);

		self.title = layoutName;

		NSString *kbName = [NSString stringWithFormat:@"iPhone-Portrait-%@", layoutName];
		_keyboard = [[objc_getClass("TUIKeyboardLayoutFactory") sharedKeyboardFactory] keyboardWithName:kbName inCache:nil];
		NSLog(@"Found keyboard: %@", _keyboard);

		_smallLettersKeyplane = nil;
		_capitalLettersKeyplane = nil;

		NSString *prefBase = [NSString stringWithFormat:@"kb-%@-", layoutName];

		// Build Keyplanes
		PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Keyplanes"];
		[group setProperty:@"Each of these is a separate 'page' on the keyboard." forKey:@"footerText"];
		[specs addObject:group];

		for (UIKBTree *keyplane in _keyboard.subtrees) {
			if ([keyplane.name hasSuffix:@"-Small-Display"])
				continue;
			else if ([keyplane.name hasSuffix:@"_Capital-Letters"])
				_capitalLettersKeyplane = keyplane;
			else if ([keyplane.name hasSuffix:@"_Small-Letters"])
				_smallLettersKeyplane = keyplane;

			NSString *slicedKeyplaneName = [keyplane.name sliceAfterLastUnderscore];

			PSSpecifier *spec = [PSSpecifier
				preferenceSpecifierNamed:[slicedKeyplaneName hyphensToSpaces]
				target:self
				set:NULL
				get:NULL
				detail:[NFPKeyplaneController class]
				cell:PSLinkCell
				edit:Nil];
			[spec setProperty:@YES forKey:@"enabled"];
			[spec setProperty:layoutName forKey:@"fp-layout-name"];
			[spec setProperty:_keyboard forKey:@"fp-keyboard"];
			[spec setProperty:keyplane forKey:@"fp-keyplane"];
			[specs addObject:spec];

			if ([keyplane.name hasSuffix:@"_Capital-Letters"])
				_capitalLettersKeyplaneSpecifier = spec;
		}

		// Niceties
		_separateSpecifier = nil;

		if (_capitalLettersKeyplane && _smallLettersKeyplane) {
			PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Options"];
			[group setProperty:@"Use different shortcuts on the Small Letters and Capital Letters keyboards." forKey:@"footerText"];

			_separateSpecifier = [PSSpecifier
				preferenceSpecifierNamed:@"Separate Small/Capital Letters"
				target:self
				set:@selector(setPreferenceValue:specifier:)
				get:@selector(readPreferenceValue:)
				detail:Nil
				cell:PSSwitchCell
				edit:Nil
				];
			[_separateSpecifier setProperty:[prefBase stringByAppendingString:@"capsAreSeparate"] forKey:@"key"];
			[_separateSpecifier setProperty:@NO forKey:@"default"];
			[_separateSpecifier setProperty:@"org.wuffs.flickplus" forKey:@"defaults"];
			[_separateSpecifier setProperty:@"org.wuffs.flickplus/ReloadPrefs" forKey:@"PostNotification"];

			[specs addObject:group];
			[specs addObject:_separateSpecifier];
		}

		_specifiers = specs;
	}

	[self _refreshSeparateState];
	return _specifiers;
}


- (void)_refreshSeparateState {
	if (_separateSpecifier) {
		id isSeparate = [self readPreferenceValue:_separateSpecifier];
		[_capitalLettersKeyplaneSpecifier setProperty:isSeparate forKey:@"enabled"];
		[self reloadSpecifier:_capitalLettersKeyplaneSpecifier];
	}
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[super setPreferenceValue:value specifier:specifier];

	if (specifier == _separateSpecifier)
		[self _refreshSeparateState];
}

@end
