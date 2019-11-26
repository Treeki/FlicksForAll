// #import <CepheiPrefs/HBRootListController.h>
#import <Preferences/PSListController.h>
#import "../h/UIKeyboardInputMode.h"
#import "../h/UIKBTree.h"
#import "../h/TUIKeyboardLayoutFactory.h"

@interface NFPKeyboardController : PSListController
{
	UIKBTree *_keyboard;

	UIKBTree *_smallLettersKeyplane, *_capitalLettersKeyplane;
	PSSpecifier *_separateSpecifier;
	PSSpecifier *_capitalLettersKeyplaneSpecifier;
}
@end

