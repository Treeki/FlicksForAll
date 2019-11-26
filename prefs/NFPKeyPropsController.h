// #import <CepheiPrefs/HBRootListController.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "../h/UIKBTree.h"

@interface PSTextFieldSpecifier : PSSpecifier
@property (nonatomic, retain) NSString *placeholder;
@end

enum {
	NFPModeNothing = 0,
	NFPModeText = 1,
	NFPModeDual = 2
};

@interface NFPKeyPropsController : PSListController
{
	UIKBTree *_key;
	UIBarButtonItem *_saveButton;

	int _mode;
	NSString *_representedString, *_displayString;
	NSString *_leftRepresentedString, *_leftDisplayString;
	NSString *_rightRepresentedString, *_rightDisplayString;

	PSSpecifier *_modeSpecNothing, *_modeSpecText, *_modeSpecDual;

	NSArray *_textSpecifierArray;
	PSTextFieldSpecifier *_displayStringSpec, *_representedStringSpec;
	
	NSArray *_dualSpecifierArray;
	PSTextFieldSpecifier *_leftDisplayStringSpec, *_leftRepresentedStringSpec;
	PSTextFieldSpecifier *_rightDisplayStringSpec, *_rightRepresentedStringSpec;
}

@property int mode;
@property (nonatomic,retain) NSString *representedString;
@property (nonatomic,retain) NSString *displayString;
@property (nonatomic,retain) NSString *leftRepresentedString;
@property (nonatomic,retain) NSString *leftDisplayString;
@property (nonatomic,retain) NSString *rightRepresentedString;
@property (nonatomic,retain) NSString *rightDisplayString;
@end



