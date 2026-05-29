export THEOS_PACKAGE_SCHEME = rootless
export _THEOS_PACKAGE_FORMAT_COMPRESSION = gzip

ARCHS = arm64 arm64e
TARGET = iphone:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MapleStoryMGlobal
MapleStoryMGlobal_FILES = Tweak.x
MapleStoryMGlobal_FRAMEWORKS = UIKit
MapleStoryMGlobal_LDFLAGS += -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/tweak.mk
