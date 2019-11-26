include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FlickPlusPrefs
ARCHS = arm64 arm64e

FlickPlusPrefs_FILES = NFPRootListController.m NFPKeyboardController.m NFPKeyplaneController.m NFPKeyPropsController.m
FlickPlusPrefs_INSTALL_PATH = /Library/PreferenceBundles
FlickPlusPrefs_FRAMEWORKS = UIKit
FlickPlusPrefs_EXTRA_FRAMEWORKS += Cephei CepheiPrefs
FlickPlusPrefs_PRIVATE_FRAMEWORKS = Preferences
FlickPlusPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FlickPlusPrefs.plist$(ECHO_END)
