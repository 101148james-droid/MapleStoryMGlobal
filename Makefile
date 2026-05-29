ARCHS = arm64 arm64e
TARGET = iphone:latest:14.0

include $(THEOS)/makefiles/common.mk
_THEOS_PACKAGE_FORMAT_COMPRESSION = gzip

TWEAK_NAME = MapleStoryMGlobal
MapleStoryMGlobal_FILES = Tweak.x
MapleStoryMGlobal_FRAMEWORKS = UIKit
# MapleStoryMGlobal_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk

