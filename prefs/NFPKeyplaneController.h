// #import <CepheiPrefs/HBRootListController.h>
#import <Preferences/PSListController.h>
#import "../h/UIKBTree.h"
@class NFPKeyPropsController;
@class HBPreferences;

@interface NFPKeyplaneController : PSListController
{
	UIKBTree *_keyboard, *_keyplane;
	NSString *_prefKey;
	NSMutableDictionary *_configData;
	HBPreferences *_hbPrefs;
}
- (void)saveKeyInfoBackFrom:(NFPKeyPropsController *)kpc;
@end


