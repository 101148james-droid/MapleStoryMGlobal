ARCHS = arm64e
TARGET = iphone:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MapleStoryMGlobal
MapleStoryMGlobal_FILES = Tweak.x
MapleStoryMGlobal_FRAMEWORKS = UIKit Foundation StoreKit Security
MapleStoryMGlobal_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MapleStoryMGlobal_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk
