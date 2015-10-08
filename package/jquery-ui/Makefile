#
# Copyright (C) 2014 Bernd Ocklin <bernd@vyacht.net>
#
# This file is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
# 
# For the license of the actually jquery please check subfolders.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=jquery-ui
PKG_VERSION:=1.10.4
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/jquery-ui
	CATEGORY:=VYACHT
	TITLE:=allows easy web based configuartion of an vYachtWiFi Router
	MAINTAINER:=Bernd Ocklin <bernd@vyacht.net>
endef

define Package/jquery-ui/description
  Tiny package for necessary jquery-ui dependencies.
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/jquery-ui/install
	$(INSTALL_DIR) $(1)/www
	$(INSTALL_DIR) $(1)/www/jquery-ui
	$(INSTALL_DIR) $(1)/www/jquery-ui/js
	$(INSTALL_DIR) $(1)/www/jquery-ui/css
	$(INSTALL_DIR) $(1)/www/jquery-ui/css/ui-lightness
	$(INSTALL_DIR) $(1)/www/jquery-ui/css/ui-lightness/images
	$(INSTALL_DATA) ./files/index.html $(1)/www/jquery-ui/index.html
	$(INSTALL_DATA) $(addprefix ./files/js/, \
			jquery-ui-1.10.4.custom.min.js \
			jquery-ui-1.10.4.custom.js \
			jquery-ui-1.10.2.custom.js \
			jquery-1.10.2.js) \
			$(1)/www/jquery-ui/js
	$(INSTALL_DATA) $(addprefix ./files/css/ui-lightness/, \
			jquery-ui-1.10.4.custom.css \
			jquery-ui-1.10.4.custom.min.css) \
			$(1)/www/jquery-ui/css/ui-lightness
	$(INSTALL_DATA) $(addprefix ./files/css/ui-lightness/images/, \
			ui-bg_diagonals-thick_18_b81900_40x40.png \
			ui-bg_glass_100_f6f6f6_1x400.png \
			ui-bg_glass_100_fdf5ce_1x400.png \
			ui-bg_diagonals-thick_20_666666_40x40.png \
			ui-icons_ffd27a_256x240.png \
			ui-bg_glass_65_ffffff_1x400.png \
			ui-icons_228ef1_256x240.png \
			ui-bg_highlight-soft_75_ffe45c_1x100.png \
			ui-icons_ef8c08_256x240.png \
			ui-bg_highlight-soft_100_eeeeee_1x100.png \
			ui-icons_222222_256x240.png \
			ui-icons_ffffff_256x240.png \
			ui-bg_flat_10_000000_40x100.png \
			animated-overlay.gif \
			ui-bg_gloss-wave_35_f6a828_500x100.png) \
			$(1)/www/jquery-ui/css/ui-lightness/images
endef

$(eval $(call BuildPackage,jquery-ui))
