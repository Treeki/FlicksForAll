#include "NFPRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Cephei/HBRespringController.h>
#import <CepheiPrefs/HBLinkTableCell.h>

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
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

		for (PSSpecifier *specifier in _specifiers) {
			Class cellClass = specifier.properties[PSCellClassKey];
			if ([cellClass isSubclassOfClass:HBLinkTableCell.class]) {
				specifier.cellType = PSLinkCell;
				specifier.buttonAction = @selector(hb_openURL:);
			}
		}
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

@end
