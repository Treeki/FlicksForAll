#include "NFPRootListController.h"
#import "NFPKeyboardController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Cephei/HBRespringController.h>
#import <CepheiPrefs/HBLinkTableCell.h>
#import "../h/UIKeyboardInputMode.h"
#import "../h/UIKeyboardInputModeController.h"

@interface HBRespringController (TerribleHack)
+ (NSURL *)_preferencesReturnURL;
@end

@implementation NFPRootListController

// + (NSString *)hb_specifierPlist {
// 	return @"Root";
// }

// all of this can be removed once libpackageinfo is updated
// so Cephei works properly again

- (NSArray *)specifiers {
	if (!_specifiers) {
		NSMutableArray *specs = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];

		// cephei does this for us once we use its listcontroller
		for (PSSpecifier *specifier in specs) {
			Class cellClass = specifier.properties[PSCellClassKey];
			if ([cellClass isSubclassOfClass:HBLinkTableCell.class]) {
				specifier.cellType = PSLinkCell;
				specifier.buttonAction = @selector(hb_openURL:);
			}
		}

		NSArray *modes = [[UIKeyboardInputModeController sharedInputModeController] activeInputModes];
		int listIndex = 3;

		// this can maybe be made nicer by using PSListController methods
		// find all the keyboards
		for (UIKeyboardInputMode *mode in modes) {
			NSLog(@"found mode %@", [mode identifier]);
			if (mode.isExtensionInputMode)
				continue;

			PSSpecifier *spec = [PSSpecifier
				preferenceSpecifierNamed:[mode extendedDisplayName]
				target:self
				set:NULL
				get:NULL
				detail:[NFPKeyboardController class]
				cell:PSLinkCell
				edit:Nil];
			// spec.buttonAction = @selector(editKeyboardSettings:);
			[spec setProperty:@YES forKey:@"enabled"];
			[spec setProperty:[mode identifier] forKey:@"fp-keyboard-mode"];
			[specs insertObject:spec atIndex:listIndex++];
		}

		_specifiers = specs;
	}

	return _specifiers;
}

- (void)hb_respringAndReturn:(PSSpecifier *)specifier {
	PSTableCell *cell = [self cachedCellForSpecifier:specifier];
	cell.cellEnabled = NO;
	[HBRespringController respringAndReturnTo:[HBRespringController _preferencesReturnURL]];
}

- (void)hb_openURL:(PSSpecifier *)specifier {
	NSURL *url = [NSURL URLWithString:specifier.properties[@"url"]];
	[[UIApplication sharedApplication] openURL:url];
}



// - (void)editKeyboardSettings:(PSSpecifier *)specifier {
// // 	NSString *modeID = [specifier propertyForKey:@"fp-keyboard-mode"];
// // 	NSLog(@"gonna edit stuff for mode %@", modeID);
// // }

@end
