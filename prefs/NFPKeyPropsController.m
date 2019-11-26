#include "NFPKeyPropsController.h"
#import "NFPKeyplaneController.h"
#import "../Utils.h"
#include <objc/runtime.h>

@interface PSSetupController : PSViewController
- (void)dismiss;
@end

@implementation NFPKeyPropsController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
		target:self
		action:@selector(cancelMe:)];

	_saveButton = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemSave
		target:self
		action:@selector(saveMe:)];
	self.navigationItem.rightBarButtonItem = _saveButton;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_displayString = @"";
		_representedString = @"";
		_leftDisplayString = @"";
		_leftRepresentedString = @"";
		_rightDisplayString = @"";
		_rightRepresentedString = @"";
		_mode = NFPModeNothing;

		NSArray *config = [self.specifier propertyForKey:@"fp-key-config"];
		if (config) {
			if (config.count == 2) {
				_mode = NFPModeText;
				_representedString = config[0];
				_displayString = config[1];
			} else if (config.count == 4) {
				_mode = NFPModeDual;
				_leftRepresentedString = config[0];
				_leftDisplayString = config[1];
				_rightRepresentedString = config[2];
				_rightDisplayString = config[3];
			}
		}

		NSMutableArray *specs = [NSMutableArray array];

		_key = [self.specifier propertyForKey:@"fp-key"];
		NSString *niceName = [[_key.name sliceAfterLastUnderscore] hyphensToSpaces];
		self.title = [NSString stringWithFormat:@"%@ (%@)", niceName, _key.displayString];

		PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Action on Swipe Down"];
		[group setProperty:@YES forKey:@"isRadioGroup"];
		[specs addObject:group];

		_modeSpecNothing = [PSSpecifier
			preferenceSpecifierNamed:@"Nothing"
			target:self set:nil get:nil detail:Nil
			cell:PSListItemCell edit:Nil
			];
		[_modeSpecNothing setProperty:@(NFPModeNothing) forKey:@"fp-mode"];
		_modeSpecText = [PSSpecifier
			preferenceSpecifierNamed:@"Text/Character"
			target:self set:nil get:nil detail:Nil
			cell:PSListItemCell edit:Nil
			];
		[_modeSpecText setProperty:@(NFPModeText) forKey:@"fp-mode"];
		_modeSpecDual = [PSSpecifier
			preferenceSpecifierNamed:@"Dual Text/Character (Experimental)"
			target:self set:nil get:nil detail:Nil
			cell:PSListItemCell edit:Nil
			];
		[_modeSpecDual setProperty:@(NFPModeDual) forKey:@"fp-mode"];
		[specs addObject:_modeSpecNothing];
		[specs addObject:_modeSpecText];
		[specs addObject:_modeSpecDual];

		id whom = nil;
		switch (_mode) {
			case NFPModeNothing: whom = _modeSpecNothing; break;
			case NFPModeText:    whom = _modeSpecText;    break;
			case NFPModeDual:    whom = _modeSpecDual;    break;
		}
		[group setProperty:whom forKey:@"radioGroupCheckedSpecifier"];

		_specifiers = specs;

		// populate the mode-specific specifiers
		group = [PSSpecifier groupSpecifierWithName:@"Text"];
		[group setProperty:@"This text will be typed when you swipe down on this key." forKey:@"footerText"];
		_representedStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text to Insert"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_displayStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text on Keycap"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_displayStringSpec.placeholder = @"(optional)";
		_textSpecifierArray = @[group, _representedStringSpec, _displayStringSpec];

		group = [PSSpecifier groupSpecifierWithName:@"Top Left Corner"];
		[group setProperty:@"This text will be typed when you swipe down and to the right on this key." forKey:@"footerText"];
		_leftRepresentedStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text to Insert"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_leftDisplayStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text on Keycap"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_leftDisplayStringSpec.placeholder = @"(optional)";

		PSSpecifier *group2 = [PSSpecifier groupSpecifierWithName:@"Top Right Corner"];
		[group2 setProperty:@"This text will be typed when you swipe down and to the left on this key." forKey:@"footerText"];
		_rightRepresentedStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text to Insert"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_rightDisplayStringSpec = [PSTextFieldSpecifier
			preferenceSpecifierNamed:@"Text on Keycap"
			target:self
			set:@selector(setThing:forSpecifier:)
			get:@selector(getThingForSpecifier:)
			detail:Nil cell:PSEditTextCell edit:Nil];
		_rightDisplayStringSpec.placeholder = @"(optional)";
		_dualSpecifierArray = @[group, _leftRepresentedStringSpec, _leftDisplayStringSpec, group2, _rightRepresentedStringSpec, _rightDisplayStringSpec];

		int startingMode = _mode;
		_mode = NFPModeNothing; // we have no specifiers in the array right now
		[self _setMode:startingMode];
	}

	return _specifiers;
}


- (void)cancelMe:(UIBarButtonItem *)item {
	[(PSSetupController *)self.parentController dismiss];
}

- (void)saveMe:(UIBarButtonItem *)item {
	[self.view endEditing:YES];
	NFPKeyplaneController *kpc = (NFPKeyplaneController *)self.parentController.parentController;
	[kpc saveKeyInfoBackFrom:self];
	[(PSSetupController *)self.parentController dismiss];
}

- (void)tableView:(UITableView*)view didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
	[super tableView:view didSelectRowAtIndexPath:indexPath];

	PSSpecifier *spec = [self specifierAtIndexPath:indexPath];
	id value = [spec propertyForKey:@"fp-mode"];
	if (value != nil) {
		[self _setMode:[value integerValue]];
	}
}


- (NSArray *)specsForMode:(int)mode {
	switch (mode) {
		case NFPModeText: return _textSpecifierArray;
		case NFPModeDual: return _dualSpecifierArray;
	}
	return nil;
}

- (void)_setMode:(int)newMode {
	NSArray *fromArray = [self specsForMode:_mode];
	NSArray *toArray = [self specsForMode:newMode];

	if (fromArray && toArray) {
		[self updateSpecifiers:fromArray withSpecifiers:toArray];
	} else if (fromArray) {
		[self removeContiguousSpecifiers:fromArray];
	} else if (toArray) {
		[self addSpecifiersFromArray:toArray];
	}

	_mode = newMode;
	[self _checkValidity];
}

- (id)getThingForSpecifier:(PSSpecifier *)specifier {
	if (specifier == _displayStringSpec)
		return _displayString;
	else if (specifier == _representedStringSpec)
		return _representedString;
	else if (specifier == _leftDisplayStringSpec)
		return _leftDisplayString;
	else if (specifier == _leftRepresentedStringSpec)
		return _leftRepresentedString;
	else if (specifier == _rightDisplayStringSpec)
		return _rightDisplayString;
	else if (specifier == _rightRepresentedStringSpec)
		return _rightRepresentedString;
	else
		return nil;
}

- (void)setThing:(id)thing forSpecifier:(PSSpecifier *)specifier {
	NSLog(@"setting %@ for %@", thing, specifier);
	if (specifier == _displayStringSpec)
		_displayString = thing;
	else if (specifier == _representedStringSpec)
		_representedString = thing;
	else if (specifier == _leftDisplayStringSpec)
		_leftDisplayString = thing;
	else if (specifier == _leftRepresentedStringSpec)
		_leftRepresentedString = thing;
	else if (specifier == _rightDisplayStringSpec)
		_rightDisplayString = thing;
	else if (specifier == _rightRepresentedStringSpec)
		_rightRepresentedString = thing;
	[self _checkValidity];
}

- (void)_checkValidity {
	// maybe later...
	/*BOOL ok = NO;

	switch (_mode) {
		case NFPModeNothing:
			ok = YES;
			break;
		case NFPModeText:
			ok = (_representedString.length > 0);
			break;
		case NFPModeDual:
			ok = (_leftRepresentedString.length > 0) && (_rightRepresentedString.length > 0);
			break;
	}

	_saveButton.enabled = ok;*/
}


@end


