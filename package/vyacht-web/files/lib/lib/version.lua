local pcall, dofile, _G = pcall, dofile, _G

module "vyacht.version"

if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
else
	distname    = "OpenWrt Firmware"
	distversion = "Barrier Breaker (r33735)"
end

luciname    = "LuCI Trunk"
luciversion = "svn-r9941"
