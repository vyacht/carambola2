#
# Copyright (C) 2013 Bernd Ocklin <bernd@vyacht.net>
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=vyacht-init
PKG_VERSION:=0.3
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/vyacht-init
	CATEGORY:=VYACHT
        DEPENDS:=+vyacht-web
	TITLE:=provides initial setup and hardware config files
	MAINTAINER:=Bernd Ocklin <bernd@vyacht.net>
endef

define Package/vyacht-init/description
  Initial setup and hardware configuration files.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/vyacht-init/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN)  ./files/vyacht-init-setup.lua $(1)/usr/sbin
	$(INSTALL_BIN)  ./files/vyacht-fetch-sysupgrade $(1)/usr/sbin
	$(INSTALL_DATA) ./files/vyacht.config $(1)/etc/config/vyacht
	$(INSTALL_BIN)  ./files/fixboot $(1)/etc/init.d/fixboot
endef

$(eval $(call BuildPackage,vyacht-init))
