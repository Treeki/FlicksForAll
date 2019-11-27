INSTALL_TARGET_PROCESSES = SpringBoard

ifeq ($(FP_SIMULATOR),1)
TARGET = simulator:clang::13.2
ARCHS = x86_64
else
ARCHS = arm64 arm64e
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = flickplus

flickplus_FILES = Tweak.xm Utils.m
flickplus_CFLAGS = -fobjc-arc
ifeq ($(FP_SIMULATOR),1)
flickplus_CFLAGS += -DFP_NO_CEPHEI
else
flickplus_EXTRA_FRAMEWORKS += Cephei
endif

include $(THEOS_MAKE_PATH)/tweak.mk

ifneq ($(FP_SIMULATOR),1)
SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
endif

ifneq (,$(filter x86_64 i386,$(ARCHS)))
setup:: clean all
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).dylib
	@codesign -f -s - /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
endif
