INSTALL_TARGET_PROCESSES = SpringBoard

# simulator only
# TARGET = simulator:clang::13.2
# ARCHS = x86_64

# for final
ARCHS = arm64 arm64e


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = flickplus

flickplus_FILES = Tweak.xm
flickplus_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
