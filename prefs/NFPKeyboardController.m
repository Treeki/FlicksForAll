#include "NFPKeyboardController.h"
#import <Preferences/PSSpecifier.h>

@implementation NFPKeyboardController

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specs = [[self loadSpecifiersFromPlistName:@"Keyboard" target:self] mutableCopy];

		NSString *kbIdentifier = [self.specifier propertyForKey:@"fp-keyboard-mode"];
		NSLog(@"Gonna edit %@", kbIdentifier);

		_mode = [UIKeyboardInputMode keyboardInputModeWithIdentifier:kbIdentifier];
		self.title = _mode.extendedDisplayName;

		_specifiers = specs;
	}

	return _specifiers;
}

@end
