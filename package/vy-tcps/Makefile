#
# Copyright (C) 2009 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=vy-tcps
PKG_RELEASE:=$(LINUX_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/vy-tcps
  CATEGORY:=VYACHT
  DEPENDS:=+libpthread +lm
  TITLE:=NMEA testing utility
  VERSION:=$(LINUX_VERSION)-$(PKG_RELEASE)
endef

define Package/vy-tcps/description
  NMEA testing utility.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	$(TARGET_CC) $(TARGET_CFLAGS) -o $(PKG_BUILD_DIR)/vy-tcps \
		$(PKG_BUILD_DIR)/tcps.c -lm -lpthread
	$(TARGET_CC) $(TARGET_CFLAGS) -o $(PKG_BUILD_DIR)/vy-udp \
		$(PKG_BUILD_DIR)/udp.c
	$(TARGET_CC) $(TARGET_CFLAGS) -o $(PKG_BUILD_DIR)/vy-getifaddr \
		$(PKG_BUILD_DIR)/getifaddr.c
endef

define Package/vy-tcps/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/vy-tcps $(1)/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/vy-udp $(1)/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/vy-getifaddr $(1)/bin/
endef

$(eval $(call BuildPackage,vy-tcps))
