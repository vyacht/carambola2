#
# Copyright (C) 2006-2012 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=gpsd-vy
PKG_VERSION:=3.11
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tgz
#PKG_SOURCE_URL:=http://download-mirror.savannah.gnu.org/releases/gpsd
#PKG_MD5SUM:=53a88f24a0973d23427e82e9a8914f19

PKG_BUILD_DEPENDS:=libncurses

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/scons.mk

define Package/gpsd-vy/Default
  DEPENDS:=+librt
  URL:=http://catb.org/gpsd/
endef

define Package/gpsd-vy/Default/description
  gpsd is a userland daemon acting as a translator between GPS and AIS receivers
  and their clients. gpsd listens on port 2947 for clients requesting
  position/time/velocity information.  The receivers are expected to generate
  position information in a well-known format -- as NMEA-0183 sentences, SiRF
  binary, Rockwell binary, Garmin binary format, or other vendor binary
  protocols.  gpsd takes this information from the GPS and translates it into
  something uniform and easier to understand for clients.
endef

define Package/gpsd-vy
  $(call Package/gpsd-vy/Default)
  CATEGORY:=VYACHT
  DEPENDS+= +libgps-vy +libgpsd-vy
  TITLE:=An interface daemon for GPS receivers
endef

define Package/gpsd-vy/conffiles
/etc/config/gpsd
endef

define Package/gpsd-vy/description
  $(call Package/gpsd-vy/Default/description)
  This package contains the GPS daemon.
endef

define Package/gpsd-vy-clients
  $(call Package/gpsd-vy/Default)
  SECTION:=net
  CATEGORY:=VYACHT
  DEPENDS+= +libgps-vy +libgpsd-vy +libncurses
  TITLE:=GPS tools and clients
endef

define Package/gpsd-vy-clients/description
  $(call Package/gpsd-vy/Default/description)
  This package contains auxiliary tools and example clients for monitoring and
  testing the GPS daemon.
endef

define Package/libgps-vy
  $(call Package/gpsd-vy/Default)
  SECTION:=libs
  CATEGORY:=VYACHT
  DEPENDS+= +libcap
  TITLE:=C service library for communicating with the GPS daemon
endef

define Package/libgps-vy/description
  $(call Package/gpsd-vy/Default/description)
  This package contains the libgps library.
endef

define Package/libgpsd-vy
  $(call Package/gpsd-vy/Default)
  SECTION:=libs
  CATEGORY:=VYACHT
  DEPENDS+= +libcap +libusb-1.0
  TITLE:=C service library for GPS applications
endef

define Package/libgpsd-vy/description
  $(call Package/gpsd-vy/Default/description)
  This package contains the libgpsd library.
endef

SCONS_OPTIONS += \
	dbus_export=no \
	tsip=no \
	fv18=no \
	tripmate=no \
	earthmate=no \
	itrax=no \
	navcom=no \
	ubx=no \
	evermore=no \
	ntrip=no \
	libgpsmm=no \
	libQgpsmm=no \
	bluez=no \
	strip=no \
	python=no \
	implicit_link=no \
	chrpath=no

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/gps.h $(1)/usr/include/
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libgps*.so* $(1)/usr/lib/
	$(INSTALL_DIR) $(1)/usr/lib/pkgconfig
	$(CP) \
		$(PKG_INSTALL_DIR)/usr/lib/pkgconfig/libgps*.pc \
		$(1)/usr/lib/pkgconfig/
endef

define Package/gpsd-vy/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/gpsd.config $(1)/etc/config/gpsd
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/gpsd.init $(1)/etc/init.d/gpsd
	$(INSTALL_DIR) $(1)/etc/hotplug.d/usb
	$(INSTALL_DATA) ./files/gpsd.hotplug $(1)/etc/hotplug.d/usb/20-gpsd
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/sbin/gpsd $(1)/usr/sbin/
endef

define Package/gpsd-vy-clients/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) \
		$(PKG_INSTALL_DIR)/usr/bin/cgps \
		$(PKG_INSTALL_DIR)/usr/bin/gps{ctl,decode,mon,pipe} \
		$(PKG_INSTALL_DIR)/usr/bin/gpxlogger \
		$(PKG_INSTALL_DIR)/usr/bin/lcdgps \
		$(1)/usr/bin/
endef

define Package/libgps-vy/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libgps.so.* $(1)/usr/lib/
endef

define Package/libgpsd-vy/install
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libgpsd.so.* $(1)/usr/lib/
endef

$(eval $(call BuildPackage,gpsd-vy))
$(eval $(call BuildPackage,gpsd-vy-clients))
$(eval $(call BuildPackage,libgps-vy))
$(eval $(call BuildPackage,libgpsd-vy))
