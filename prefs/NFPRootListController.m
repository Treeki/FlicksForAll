#include "NFPRootListController.h"
#import "NFPKeyboardController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Cephei/HBRespringController.h>
#import <Cephei/HBPreferences.h>
#import <CepheiPrefs/HBLinkTableCell.h>
#import "../h/UIKeyboardInputMode.h"
#import "../h/UIKeyboardInputModeController.h"
#import "../h/UIKeyboardCache.h"
#include <objc/runtime.h>

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

		NSArray *inputModeIDs = [[UIKeyboardInputModeController sharedInputModeController] activeInputModeIdentifiers];
		NSSet *layouts = [[objc_getClass("UIKeyboardCache") sharedInstance] uniqueLayoutsFromInputModes:inputModeIDs];
		int listIndex = 3;

		// this can maybe be made nicer by using PSListController methods
		for (NSString *layout in layouts) {
			if ([layout isEqualToString:@"Emoji"])
				continue;

			PSSpecifier *spec = [PSSpecifier
				preferenceSpecifierNamed:layout
				target:self
				set:NULL
				get:NULL
				detail:[NFPKeyboardController class]
				cell:PSLinkCell
				edit:Nil];
			[spec setProperty:@YES forKey:@"enabled"];
			[spec setProperty:layout forKey:@"fp-keyboard-layout"];
			[specs insertObject:spec atIndex:listIndex++];
		}

		_specifiers = specs;
	}

	return _specifiers;
}


- (void)resetSettingsTapped:(PSSpecifier *)specifier {
	HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"org.wuffs.flickplus"];
	[prefs removeAllObjects];
	[self reloadSpecifiers];
}


- (void)hb_openURL:(PSSpecifier *)specifier {
	NSURL *url = [NSURL URLWithString:specifier.properties[@"url"]];
	[[UIApplication sharedApplication] openURL:url];
}

@end
