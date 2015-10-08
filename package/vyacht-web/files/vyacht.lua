local io       = require "io"
local os       = require "os"
local table    = require "table"
local nixio    = require "nixio"
local fs       = require "nixio.fs"
local uci      = require "uci"
local bus      = require "ubus"
local sys      = require "vyacht.sys"
local version  = require "vyacht.version"
local protocol = require "vyacht.protocol"
local _ip      = require "vyacht.ip"
local mime     = require "vyacht.mime"
local json     = require "vyacht.json"

local LANNAME  = "eth0"
local WANNAME  = "eth1"

if mtest == 1 then
-- module only for testing
module(..., package.seeall)
end

-- only change files but do not restart network, etc.
ptest = 0

-- print to out instead of web server
-- vtest = 0
            
function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then 
    io.close(f) 
    return true 
  else 
    return false
  end
end

function uuid()
  local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  return string.gsub(template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

function cmdExecute(command)
  
  local resultfile = "/tmp" .. uuid()

  local rs = os.execute(command .. " > " .. resultfile ..  " 2>&1")

  if rs ~= 0 then
    local data = readFile(resultfile)
    return false, data 
  end
  
  return true
  
end 

function readFile(file)
  local f = io.open(file, "rb")
  local content = nil
  if f then 
    content = f:read("*all")
    f:close()
  end
  return content
end

function isNumber(num)

	if type(num) == "number" then
		return true
	end

        if num == nil or type(num) ~= "string" then
		return false
	end

        if num:match("^%d+$") then
		return true
        else
		return false
        end

end


function vWrite(txt)
  if vtest == 1 then
    print(txt)
  else
    uhttpd.send(txt)
  end
end

--- Send the given data as JSON encoded string.
-- @param data          Data to send
function _write_json(x)
	json.write_json(x, vWrite)
end


function wrap(txt)
  return "\"" .. txt .. "\"";
end

function keyvalue(key, val)
  if type(val) == "string" then
    return wrap(key) .. ": " .. wrap(val)
  else 
    return wrap(key) .. ": " .. val
  end
end

function send_header()
	vWrite("HTTP/1.0 200 OK")
        vWrite("Content-Type: application/json\r\n\r\n")
end

function handle_request(env)

        exectime = os.clock()
        local renv = {
                CONTENT_LENGTH  = env.CONTENT_LENGTH,
                CONTENT_TYPE    = env.CONTENT_TYPE,
                REQUEST_METHOD  = env.REQUEST_METHOD,
                REQUEST_URI     = env.REQUEST_URI,
                PATH_INFO       = env.PATH_INFO,
                SCRIPT_NAME     = env.SCRIPT_NAME:gsub("/+$", ""),
                SCRIPT_FILENAME = env.SCRIPT_NAME,
                SERVER_PROTOCOL = env.SERVER_PROTOCOL,
                QUERY_STRING    = env.QUERY_STRING
        }

	-- get parameter from query string
	local params = protocol.urldecode_params(env.QUERY_STRING or "")
	local path = ""
	_uci_real  = cursor or _uci_real or uci.cursor()
        vubus = bus.connect()

	os.execute("logger -s -t device -p daemon.info " .. "uri: " .. env.REQUEST_URI)

	if (env.PATH_INFO) then
		path = env.PATH_INFO
  		os.execute("logger -s -t device -p daemon.info " .. "path: " .. env.PATH_INFO)
  	end

        for k, v in pairs(params) do
		os.execute("logger -s -t device -p daemon.info " .. k .. ": " .. tostring(v))
        end

	if string.find(path, "getStatus") then
		return getStatus()
	elseif string.find(path, "changeWifi") then
		return changeWifi(params)
	elseif string.find(path, "changeGps") then
		return changeGps(params)
	elseif string.find(path, "changeNMEA") then
		return changeNMEA(params)
	elseif string.find(path, "resetSystem") then
		return resetSystem(params)
	elseif string.find(path, "systemStatus") then
		return systemStatus(params)
	elseif string.find(path, "changeEthernet") then
		return changeEthernet(params)
	elseif string.find(path, "upload") then
	        return uploadFile(env)
	else
		send_header()
        	vWrite("{}")
	end
end

function makeVersionFromStrings(v1, v2, v3)

  local version = {x = 0, y = 0, z = 0}

  if v1 then
    version.x = tonumber(v1)
  end
  if v2 then
    version.y = tonumber(v2)
  end
  if v3 then
    version.z = tonumber(v3)
  end
  if not version.x then
    version.x = 0
  end
  if not version.y then
    version.y = 0
  end
  if not version.z then
    version.z = 0
  end
  
  return version
  
end

function extractVersionFromString(str)

  b, e, v1, v2, v3 = string.find( str , "(%d+)%.(%d)%.*(%d*)" )
  
  if not b then 
    local version = {x = 0, y = 0, z = 0}
    return version
  end
  
  return makeVersionFromStrings(v1, v2, v3)
  
end

function versionToString(version)

  return string.format("%d.%d.%d", version.x, version.y, version.z)  

end

function readHardwareOptions()

--  config hardware board
--    option version '8.3'
--        
--  config platform software
--    option version '1.0.0'
--        
--  config hardware module
--    option type nmea-iso
--    option version '1.2'
--                       
--  config hardware network
--    list device radio0
--    list device eth0.1
--    list device eth0.2
--
--  config interface 'port2'
--    option port '2'
--    option type 'seatalk'
--    option speed 4800
--    option enabled '1'

  if not file_exists("/etc/config/vyacht") then
    return nil
  end
 
  local hw = {
    board = {version = {x = 0, y = 0, z = 0}},
    software = {version = {x = 0, y = 0, z = 0}},
    module = {type = "", version = {x = 0, y = 0, z = 0}, interface = "spi"},
    network = {devices = {}},
    interfaces = {}
  }
  
  bv = _uci_real:get("vyacht", "board", "version") or "0.0.0"
  hw.board.version = extractVersionFromString(bv)
  
  sv = _uci_real:get("vyacht", "software", "version") or "0.0.0"
  hw.software.version = extractVersionFromString(sv)
  
  mv = _uci_real:get("vyacht", "module", "version") or "0.0.0"
  hw.module.version = extractVersionFromString(mv)
  
  hw.module.type = _uci_real:get("vyacht", "module", "type")

  hw.module.interface = _uci_real:get("vyacht", "module", "interface")

  if hw.module.interface == '' or hw.module.interface == nil then
    hw.module.interface = 'serial'
  end
  
  local lst = _uci_real:get("vyacht", "network", "device")                                                                            
  for i = 1, #lst do                                                                                                            
    table.insert(hw.network.devices, lst[i])
  end
  
  if file_exists("/etc/config/vymodule") then
    _uci_real:foreach("vymodule", "interface", function(s)
      name = s[".name"]
      
      local itf = {
        port = 0, speed = 0, type = "", enabled = 0 } 
      
      itf.port = _uci_real:get("vymodule", name, "port")
      itf.speed = _uci_real:get("vymodule", name, "speed")
      itf.type = _uci_real:get("vymodule", name, "type")
      itf.enabled = _uci_real:get("vymodule", name, "enabled")
    
      table.insert(hw.interfaces, itf) 
    end)
  else
    _uci_real:foreach("gpsd", "interface", function(s)
      name = s[".name"]
      
      local itf = {
        port = 0, speed = 0, type = "", enabled = 0, device = "" } 

      local d = _uci_real:get("gpsd", name, "device")

      if d then
        itf.device = d
        itf.port = _uci_real:get("gpsd", name, "port")
        itf.speed = _uci_real:get("gpsd", name, "speed")
        itf.type = _uci_real:get("gpsd", name, "type")
        itf.enabled = _uci_real:get("gpsd", name, "enabled")
        table.insert(hw.interfaces, itf) 
      end
    end)
  end
 
  return hw
  
end

function writeHardwareOptions(hw)

  _uci_real:set("vyacht", "board", "version", versionToString(hw.board.version))
  _uci_real:set("vyacht", "software", "version", versionToString(hw.software.version))
  _uci_real:set("vyacht", "module", "version", versionToString(hw.module.version))
  _uci_real:set("vyacht", "module", "type", hw.module.type)
  _uci_real:set("vyacht", "module", "interface", hw.module.interface)
  _uci_real:set("vyacht", "network", "device", hw.network.devices)
  
  if file_exists("/etc/config/gpsd") then
    for i = 1, #hw.interfaces do
      local secname = "port" .. hw.interfaces[i].port
      _uci_real:set("gpsd", secname, "interface")
      _uci_real:set("gpsd", secname, "port", hw.interfaces[i].port)
      _uci_real:set("gpsd", secname, "type", hw.interfaces[i].type)
      _uci_real:set("gpsd", secname, "speed", hw.interfaces[i].speed)
      _uci_real:set("gpsd", secname, "enabled", hw.interfaces[i].enabled)
      _uci_real:set("gpsd", secname, "device", "vyspi:///dev/ttyATH0")
    end
    _uci_real:commit("gpsd")
  end

  _uci_real:commit("vyacht")
  
end

function isSystemUpgradeable(hw)

  -- need to check if the vyacht config file is there
  
  if not hw then
    return false, "System too old. No hardware description file found."
  end
  
  if hw.software.version.x == 0 then 
    return false, string.format("System too old. Too old software version %s.", versionToString(hw.software.version))
  end
  
  return true
  
end

function parseUpgradeFilename(filename)

  local pattern = "^vyacht%-wifi%-(%d+)%.(%d+)%.(%d+)%-upgrade%-(%d+)%.(%d+)%.(%d+).bin$"
  
  local file = {
    board = {version = {x = 0, y = 0, z = 0}},
    software = {version = {x = 0, y = 0, z = 0}},
    product = "",
    isUpgrade = false
  }
  
  b, e, b1, b2, b3, s1, s2, s3 = string.find( filename , pattern )           
  
  if not b then
    return nil
  end
  
  file.board.version = makeVersionFromStrings(b1, b2, b3)
  
  file.software.version = makeVersionFromStrings(s1, s2, s3)
  
  file.product = "vyacht-wifi"
  
  file.isUpgrade = true
  
  return file
    
end

function uploadFile(env)
 
  local lf = nil
  local filename = ""
  local fileshort = ""
  local checksum = ""
  local bytecnt = 0
    
  function filecb(field, data, bl)
  
	local d = data or ""
	
	if not lf then
	  if field and field.name then
  	    fileshort = field.file
  	    filename = "/tmp/" .. fileshort
            lf = io.open(filename, "wb")
            if not lf then
              return false, string.format("Couldn't write file (%s)", filename)
            end
          end
        end
        
        if lf then 
          if checksum:len() < 32 then
            local s = checksum:len()
            local diff = 32 - s
    
            if data:len() < diff then diff = data:len() end
            
            checksum = checksum .. data:sub(1, diff)
            data     = data:sub(diff + 2)
          end
          if data then 
            bytecnt = bytecnt + data:len()
            if data:len() > 0 then
    	      lf:write(data)
    	    end
    	  end
  	end
  	return true
  end
	
  function readcb() 
	local rv, buf
	rv, buf = uhttpd.recv(4096)
	if buf and rv > 0 then
		return buf
	end
	return nil
  end
    
  local _debug = false
  local msg = {
    	env = env,
    	params = {}
  }

  send_header()
  
  local contentLength = math.floor(tonumber(env.CONTENT_LENGTH) / 1024)
  
  local ps = sys.mounts()
  local blocks = -1 
    
  for k, v in ipairs( ps) do
    if v["mountpoint"] == "/tmp" then
      blocks = tonumber(v["blocks"])
    end
  end
  
  if blocks < 0 then
    vWrite("{\"error\": \"No suitable temporary storage found on device.\"}")
    return
  end
  
  if blocks <= contentLength then
    vWrite(string.format("{%q: \"Only %d kByte of space found for a %d kByte file. Try to reboot the device.\"}", 
    	"error", blocks, contentLength))
    return
  end
  
  bytecnt = 0
    
  if env.REQUEST_METHOD == "POST" then
	mime.mimedecode_message_body(msg, readcb, filecb)
        io.close(lf)
  end
  
  os.execute("logger -s -t device -p daemon.info " .. "Decoding uploaded file with " .. bytecnt .. " now: " .. filename)
  
  if not file_exists(filename) then
    vWrite(string.format("{\"error\": \"No installable file found (%s)!\"}", fileshort))
    return
  end

  nstr = ""
  for i = 1, #checksum do
    local c = checksum:sub(i,i)
    if ((c < '0') or (c > '9')) and ((c < 'a') or (c > 'f')) then
      nstr = nstr .. '.'
    else
      nstr = nstr .. c
    end
  end
  checksum = nstr
  
  os.execute("logger -s -t device -p daemon.info " .. "Checking checksum now: " .. filename)
  local filechecksum = sys.exec(string.format("md5sum %q", filename)):match("^([^%s]+)")  
  os.execute("logger -s -t device -p daemon.info " .. "File checksum: " .. filechecksum)
  os.execute("logger -s -t device -p daemon.info " .. "Checksum     : " .. checksum .. " " .. checksum:len() .. "")
 
  if checksum ~= filechecksum then
    vWrite(string.format("{\"error\": \"File checksum %s doesn't match %s\"}", filechecksum, checksum))
    return
  end
    
  local file = parseUpgradeFilename(fileshort)
  if not file then
    vWrite(string.format("{\"error\": \"No a valid file for upgrade (%s)!\"}", fileshort))
    return
  end
  
  local hw = readHardwareOptions()
  
  su, error = isSystemUpgradeable(hw)
  if not su then
    vWrite(string.format("{\"error\": \"System not upgradable: %s\"}", error))
    return
  end
  
  if file.board.version.x ~= hw.board.version.x then
    vWrite(string.format("{\"error\": \"System not upgradable: Board version %s doesn't match file version %s\"}",
      versionToString(hw.board.version), versionToString(file.board.version)))
    return
  end

  -- set new software version
  hw.software = file.software
  writeHardwareOptions(hw)

  -- remove legacy file vymodule
  if file_exists("/etc/config/vymodule") then
    os.remove("/etc/config/vymodule")
  end
  
  sys.exec(string.format("killall dropbear uhttpd; sleep 1; /sbin/sysupgrade %q", filename))

  vWrite(string.format("{%q: %q}", "success", "Now the critical part begins.\n Please remain patient.\n" 
    .. "Going into upgrade procedure and reboot of version "
    .. versionToString(file.software.version) .. " now."))
end

function systemStatus(params) 
  -- return system tools installed
  send_header()
  
  local systemData = {
    io = file_exists("/usr/bin/io"),
    fix_hosts = {
      init = file_exists("/etc/init.d/fix_hosts")
    },
    iomode = {
      init = file_exists("/etc/init.d/iomode"),
      config = file_exists("/etc/config/iomode")
    }
  }
  _write_json(systemData)
  
end

function dhcpHostsFromPrefix(prefix)

  local hosts = _ip.getHosts(prefix) - 1
  local start = 100
  local count = 25
   
  if hosts < 255 then
    start = 1
    count = hosts - 1
  end
  
  return start, start + count
end

function setLoopback() 
  _uci_real:set("network", "loopback", "interface")
  _uci_real:set("network", "loopback", "ifname", "lo")
  _uci_real:set("network", "loopback", "proto", "static")
  _uci_real:set("network", "loopback", "ipaddr", "127.0.0.1")
  _uci_real:set("network", "loopback", "netmask", "255.0.0.0")
end

function setStaticNetwork(netName, device, ipaddr, prefix)

  local netmask
  if prefix ~= nil then
    netmask = _ip.getNetmaskString(prefix)
  else
    netmask = "255.255.255.0"
    prefix = 24
  end
  
  local start, limit = dhcpHostsFromPrefix(prefix) 
  
  _uci_real:set("network", netName, "interface")
  _uci_real:set("network", netName, "ifname", device)
  _uci_real:set("network", netName, "type", "bridge")
  _uci_real:set("network", netName, "proto", "static")
  _uci_real:set("network", netName, "ipaddr", ipaddr)
  _uci_real:set("network", netName, "netmask", netmask)

  -- start is offset from ip
  -- max 150 different IPs to lease
  _uci_real:set("dhcp", netName, "dhcp")
  _uci_real:set("dhcp", netName, "interface", netName)
  _uci_real:set("dhcp", netName, "start", start)
  _uci_real:set("dhcp", netName, "limit", limit)
  _uci_real:set("dhcp", netName, "leasetime", "12h")
end  

function setDhcpNetwork(netName, device)
  _uci_real:set("network", netName, "interface")
  _uci_real:set("network", netName, "ifname", device)
  _uci_real:set("network", netName, "proto", "dhcp")
  
  _uci_real:set("dhcp", netName, "dhcp")
  _uci_real:set("dhcp", netName, "interface", netName)
  _uci_real:set("dhcp", netName, "ignore", "1")
end

function typeDeleteAll(config, type)

  local secs = {}
  _uci_real:foreach(config, type, function(s)
    secs[#secs + 1] = s[".name"]
  end)
  
  for i = 1, #secs do
    _uci_real:delete(config, secs[i])
  end
  
end

function resetSystem(params) 
  -- 
  --  change wireless settings
  --
  local sec_name
  _uci_real:foreach("wireless", "wifi-device", function(s)
    sec_name = s[".name"]
  end)
  _uci_real:set("wireless", sec_name, "disabled", "0")
 
  typeDeleteAll("wireless", "wifi-iface") 
  
  local sec_name = _uci_real:add("wireless", "wifi-iface")
  _uci_real:set("wireless", sec_name, "device", "radio0")
  _uci_real:set("wireless", sec_name, "network", "wifi")
  _uci_real:set("wireless", sec_name, "mode", "ap")
  _uci_real:set("wireless", sec_name, "encryption", "psk2")
  _uci_real:set("wireless", sec_name, "key", "vYachtWifi")
  _uci_real:set("wireless", sec_name, "ssid", "vYachtWifi")
  _uci_real:commit("wireless")

 --
  --  change hostname
  --
  _uci_real:foreach("system", "system", function(s)            
      sec_name = s[".name"]                                            
  end)                                                               
  _uci_real:set("system", sec_name, "hostname", "vYachtWifi")
  _uci_real:commit("system")
  
  --
  --  change network & dhcp
  --
  -- for resetting the network we want: 
  --     lan1, wan, wifi  
  -- or  lan1, wifi
  
  typeDeleteAll("dhcp", "dhcp") 
  typeDeleteAll("network", "interface") 
  
  -- add loopback
  setLoopback() 
  
  local devs = {
    eth00 = {name = LANNAME, installed = 0},
    eth01 = {name = WANNAME, installed = 0},
    wifi  = {name = "radio0", installed = 0}
  }
  
  devs.eth00.installed = deviceInstalled(LANNAME)
  devs.eth01.installed = deviceInstalled(WANNAME)
  devs.wifi.installed = deviceInstalled("radio0")
  
  if devs.eth00.installed == 1 then
    setStaticNetwork("lan1", LANNAME, "192.168.1.1", 24)
    if devs.eth01.installed == 1 then
      setDhcpNetwork("wan", WANNAME)
    end
  else
    if devs.eth01.installed == 1 then
      setStaticNetwork("lan2", WANNAME, "192.168.1.1", 24)
    end
  end
  
  if devs.wifi.installed == 1 then
    setStaticNetwork("wifi", "radio0", "192.168.10.1", 24)
  end
  
  _uci_real:commit("network")
  _uci_real:commit("dhcp")
  
  --
  --  firewall
  --
  typeDeleteAll("firewall", "zone") 
  typeDeleteAll("firewall", "forwarding") 
  
  local sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "wifi") 
 
  sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "lan1") 
  
  sec = _uci_real:add("firewall", "zone")
  writeZoneLocal(sec, "lan2") 
  
  sec = _uci_real:add("firewall", "zone")
  writeZoneWan(sec, "wan") 
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "wifi")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "lan1")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  sec = _uci_real:add("firewall", "forwarding")
  _uci_real:set("firewall", sec, "src", "lan2")
  _uci_real:set("firewall", sec, "dest", "wan")
  
  _uci_real:commit("firewall")

end

function writeZoneLocal(sec_name, zoneName) 
        _uci_real:set("firewall", sec_name, "name", zoneName)
        _uci_real:set("firewall", sec_name, "network", zoneName)
        _uci_real:set("firewall", sec_name, "input", "ACCEPT")
        _uci_real:set("firewall", sec_name, "output", "ACCEPT")
        _uci_real:set("firewall", sec_name, "forward", "REJECT")
end

function writeZoneWan(sec_name, zoneName)
  _uci_real:set("firewall", sec_name, "name", "wan")
  _uci_real:set("firewall", sec_name, "network", "wan")
  _uci_real:set("firewall", sec_name, "input", "ACCEPT")
  _uci_real:set("firewall", sec_name, "output", "ACCEPT")
  _uci_real:set("firewall", sec_name, "forward", "REJECT")
  _uci_real:set("firewall", sec_name, "masq", "1")
  _uci_real:set("firewall", sec_name, "mtu_fix", "1")
end

function changeWan(addr, realDev, lanwan, netName)

	if realDev ~= WANNAME then
        	vWrite(string.format("{\"error\": \"Cannot convert %s to WAN or LAN!\"}", realDev))
        	return
        end
        
	if netName ~= "wan" and netName ~= "lan2" then
        	vWrite(string.format("{\"error\": \"Change WAN: Not a valid network (%s)!\"}", netName))
        	return
	end

	
	local lanNetName = "lan2"
	
	if netName == lanNetName then
	  if lanwan == "wan" then
	    -- now we make this interface new wan interface
	    _uci_real:delete("network", lanNetName)
	    _uci_real:delete("dhcp", lanNetName)
	    setDhcpNetwork("wan", realDev)
	  else
	    -- nothing to do - there is none and we keep it that way
	    -- print("nothing to do")
	  end
	else
	
	  -- we have the device name and it should be eth01
	  
	  if lanwan == "lan" then
            local ip, prefix = checkForAddressChange(addr, realDev)
	    if ip == nil or prefix == nil then
              return
            end
            
            if prefix > 30 then
              vWrite("{\"error\": \"This router requires prefixes between 0 and 30 to allow for a minimum of 4 hosts on the network\"}")
	      return  
            end
            
            -- check that we are not in range of the lan1
	    if IPInNetRange(ip, prefix, "lan1") then
              vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the Ethernet 1\"}", ip))
	      return  
	    end
	    if IPInNetRange(ip, prefix, "wifi") then
              vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the wireless network\"}", ip))
	      return  
	    end
		
	    _uci_real:delete("network", "wan")
	    _uci_real:delete("dhcp", "wan")
	    setStaticNetwork(lanNetName, WANNAME, ip, prefix)
	    
	  else
	    -- nothing to do its lan-dev already
	  end
	end
	
  	_uci_real:commit("network")
  	_uci_real:commit("dhcp")

        if ptest == 1 then
          return
        end  	
	-- requires restart of ifdown/up lan and dnsmasq
	sys.call(string.format("env -i /sbin/ifdown %s >/dev/null", netName))
	sys.call(string.format("env -i /sbin/ifup %s >/dev/null", netName))
	
	sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
	sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
	sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	sys.call("env -i /etc/init.d/gpsd start >/dev/null")
end

function changeEthernet(params)
	local addr
	local device
	local lanwan
	
	for k, v in pairs(params) do
		if k == "ip" then
			if v then
				addr = v
			end
		end
		if k == "device" then
			if v then
				device = v
			end
		end
		if k == "wan" then
			if v then
				lanwan = v
			end
		end
	end
	
	send_header()
        
        -- print("device= " .. device .. ", lanwan= " .. lanwan .. ", ip= " .. ip)
	
	if device ~= "eth00" and device ~= "eth01" then
        	vWrite(string.format("{\"error\": \"Not a valid device (%s)!\"}", device))
        	return
	end
	
	local realDev = LANNAME
	if device == "eth01" then
	  realDev = WANNAME
	end
	
	-- we only need the name of the wifi network for network status
        local devices = {
          eth00 = {name = LANNAME, installed = 0, network = ""}, 
          eth01 = {name = WANNAME, installed = 0, network = ""}, 
          wifi  = {name = "radio0", installed = 0, network = "wifi"}
        } 
        
        devices.eth00.installed = deviceInstalled(devices.eth00.name)
        devices.eth01.installed = deviceInstalled(devices.eth01.name)
        devices.wifi.installed = deviceInstalled(devices.wifi.name)

	if realDev == WANNAME and not devices.eth01.installed then
        	vWrite("{\"error\": \"Ethernet 2 is not installed!\"}")
        	return
	end

	if realDev == LANNAME and not devices.eth00.installed then
        	vWrite("{\"error\": \"Ethernet 1 is not installed!\"}")
        	return
	end

	if lanwan == nil and realDev == WANNAME then
        	vWrite("{\"error\": \"Don't recognize empty command!\"}")
        	return
	end
	
	if lanwan ~= nil and lanwan ~= "lan" and lanwan ~= "wan" then
        	vWrite(string.format("{\"error\": \"Don't recognize command (%s)!\"}", wan))
        	return
	end
	
	if realDev == LANNAME and lanwan == "wan" then
        	vWrite("{\"error\": \"Only Ethernet 2 can be made WAN!\"}")
        	return
	end
	
	local netName = getNetNameByDevice(realDev) 
	if netName ~= "wan" and netName ~= "lan2"  and netName ~= "lan1" then
        	vWrite(string.format("{\"error\": \"Not a valid network (%s)!\"}", netName))
        	return
	end
	
	-- check that WAN will not be enabled if there is no wifi or lan 
	-- preventing lock-out	
	if lanwan == "wan" and realDev == WANNAME and devices.eth00.installed == 0 then 
	
		networkStatus(devices.wifi);

		if devices.wifi.available == 0 then 
		   vWrite("{\"error\": \"You can not switch to WAN with ethernet 1 not installed and Wifi disabled!\"}")
        	   return
		end
	end
	
	if netName == "wan" then
  	  if realDev == LANNAME then
        	vWrite("{\"error\": \"Wrong network state: Ethernet 1 is configured as WAN! Refuse to change.\"}")
        	return
	  end
	  if lanwan == "lan" then
		-- print("going to change to lan = " .. netName)
		changeWan(addr, realDev, "lan", netName)
	  end
	  if lanwan == "wan" then
	    -- nothing error like to report
	    -- later we could change a static IP for WAN
            vWrite("{\"error\": \"Not able to change IP address of WAN - please request this as a feature if you need it.\"}")
	  end
	else
          -- is currently lan
          if lanwan == "wan" and realDev == WANNAME then  
            changeWan(addr, realDev, "wan", netName) 
          else 
            changeEthernetAddress(addr, realDev, netName) 
          end
	end
end

function checkForAddressChange(addr, realDev)

	if addr == nil then
        	vWrite("{\"error\": \"No new ip given!\"}")
        	return nil
	end
	
	local ip, prefix = _ip.IPv4ToIPAndPrefix(addr)
	if ip == nil or prefix == nil then
        	vWrite(string.format("{\"error\": \"%s is not a valid address!\"}", addr))
        	return nil
	end
	
	-- _ip.IPv4ToIPAndPrefix checks prefix but not IP	
	if _ip.IPv4ValidIP(ip) ~= true then
        	vWrite(string.format("{\"error\": \"%s is not a valid ip address!\"}", ip))
        	return nil
	end
	
	if _ip.IPv4ValidPrefix(prefix) ~= true then
        	vWrite(string.format("{\"error\": \"%s is not a valid ip address!\"}", ip))
        	return nil
	end
	
        if prefix > 30 then
           vWrite("{\"error\": \"This router requires prefixes between 0 and 30 to allow for a minimum of 4 hosts on the network\"}")
           return  
        end
        
	local inst = deviceInstalled(realDev)
	if inst == 0 then
        	vWrite(string.format("{\"error\": \"Device %s is not installed\"}", realDev))
        	return nil
	end
	
	return ip, prefix;
end

function IPInNetRange(ip, prefix, netName)

  local d = {network = netName, installed = 1}
  
  networkStatus(d)		
		
  if d.available == 1 then 
    if _ip.IPv4InRange(ip, prefix, d.HostIP, d.prefix) then
      return true
    end  
  end
  
  return false
  
end

-- addr address (ip/prefix or ip)
-- realDev radio0, eth0.1 or eth0.2
-- netName is the network for this device
function changeEthernetAddress(addr, realDev, net_name)

        local ip, prefix = checkForAddressChange(addr, realDev)
        if net_name == nil or ip == nil or prefix == nil then
        	return
        end
	
	if net_name == "wan" then
       		vWrite("{\"error\": \"You cannot set an ip address for WAN!\"}")
       		return
	end
	
	if realDev == LANNAME then
		if net_name ~= "lan1" then 
        		vWrite("{\"error\": \"No network lan1 for this ethernet interface found!\"}")
        		return
		end
		
		-- check that we are not in range of the WAN or lan2
		if IPInNetRange(ip, prefix, "wan") then
        		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the WAN\"}", ip))
        		return
		end
		
		if IPInNetRange(ip, prefix, "lan2") then
        		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the other LAN interface\"}", ip))
        		return
		end
	elseif realDev == WANNAME then
		if net_name ~= "lan2" then 
        		vWrite("{\"error\": \"No network lan2 for this ethernet interface found!\"}")
        		return
		end
		
		if IPInNetRange(ip, prefix, "lan1") then
        		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the other LAN interface\"}", ip))
        		return
		end
	else
        	vWrite(string.format("{\"error\": \"You cannot change %s with this function!\"}", realDev))
        	return
	end
  
	if IPInNetRange(ip, prefix, "wifi") then
       		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the wireless interface\"}", ip))
       		return
	end
		
	setStaticNetwork(net_name, realDev, ip, prefix)
	
	_uci_real:commit("network")
	_uci_real:commit("wireless")
	
	-- requires restart of ifdown/up lan and dnsmasq
	if ptest == 1 then
		return
	end
	
	sys.call(string.format("env -i /sbin/ifdown %s >/dev/null", net_name))
	sys.call(string.format("env -i /sbin/ifup %s >/dev/null", net_name))
	
	sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
	sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
	sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	sys.call("env -i /etc/init.d/gpsd start >/dev/null")
end

function getNetNameByDevice(devName) 

        local net_name
        _uci_real:foreach("network", "interface", function(s)            
          local sec_name = s[".name"]  -- network name                                          
          typ_name = s[".type"]                                            
          if devName == s.ifname then
            net_name = sec_name
          end
        end)
        
        return net_name
end

function isValidWifiKey(key) 
        return key:find('^[%-%.%w_]+$') ~= nil
end

function changeWifiKey(key) 
	local sec_name

	send_header()	
        
	if not key then
       		vWrite("{\"error\": \"No new key given.\"}")
       		return
	end
	
	if #key < 8 then
       		vWrite("{\"error\": \"New wireless key too short. Please use at least 8 characters.\"}")
       		return
	end
	
	if #key > 64 then
       		vWrite("{\"error\": \"New wireless key too long.\"}")
       		return
	end
	
	if not isValidWifiKey(key) then
       		vWrite("{\"error\": \"New wireless key contains illegal characters.\"}")
       		return
	end
	
	_uci_real:foreach("wireless", "wifi-iface",
	function(s)
    		sec_name = s[".name"]
      	end)
      
      	_uci_real:set("wireless", sec_name, "key", key)
		
	_uci_real:commit("wireless")
	
	-- requires restart of wifi, ifdown/up wifi and dnsmasq
	sys.call("env -i /sbin/ifdown wifi >/dev/null")
	sys.call("env -i /sbin/ifup wifi >/dev/null")
	sys.call("env -i /sbin/wifi down >/dev/null")
	sys.call("env -i /sbin/wifi up >/dev/null")
	
        vWrite("{}")
end

function changeWifi(params) 
	local addr
	local key
	local switch
	local restartWifi = 0
	
	for k, v in pairs(params) do
		if k == "ip" then
			if v then
				addr = v
			end
		end
		if k == "key" then
			if v then
				key = v
			end
		end
		if k == "switch" then
			if v then
				switch = v
			end
		end
	end
	
	if key ~= nil then
	  changeWifiKey(key)
	  return
	end

	send_header()
        
        if switch ~= nil then
        	if switch ~= "on" and switch ~= "off" then
	       		vWrite(string.format("{\"error\": \"Unkown wifi switch command %s\"}", switch))
       			return
        	end
        end
        
        if switch == "off" then
        	-- check for at least one other access method (LAN)
        	local devices = getNetDevices()
        	
  		networkStatus(devices.eth00);
		networkStatus(devices.eth01);
        
        	if devices.eth00.available < 1 and devices.eth01.available < 1 then
	       		vWrite("{\"error\": \"You need to have at least one wired " 
                            .. "access available to switch wireless off. No LAN is connected.\"}")
       			return
        	end

		if devices.eth00.available == 0 and devices.eth01.type == "wan" then
	       		vWrite("{\"error\": \"You need to have at least one wired LAN  " 
                            .. "access available to switch wireless off. Only WAN is connected.\"}")
       			return
		end
        	
                local sec_dev_name
		_uci_real:foreach("wireless", "wifi-device", function(s)
					      sec_dev_name = s[".name"]
					      end)

                _uci_real:set("wireless", sec_dev_name, "disabled", "1")     
                    	
		_uci_real:commit("wireless")
		
		sys.call("env -i /sbin/ifdown wifi >/dev/null")
		sys.call("env -i /sbin/wifi down >/dev/null")
		
		vWrite("{}")

		return
        else
        	-- ignore - its done here anyways
        end
        
	local ip, prefix = checkForAddressChange(addr, "radio0")
	if ip == nil or prefix == nil then
		return
	end
	
	if IPInNetRange(ip, prefix, "wan") then
       		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the WAN network\"}", ip))
       		return
	end
	if IPInNetRange(ip, prefix, "lan1") then
       		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the first LAN network\"}", ip))
       		return
	end
	if IPInNetRange(ip, prefix, "lan2") then
       		vWrite(string.format("{\"error\": \"New IP %s is in the IP range of the second LAN network\"}", ip))
       		return
	end
	
	if ip ~= nil then
		setStaticNetwork("wifi", "radio0", ip, prefix)
		restartWifi = 2
	end
	
        local sec_dev_name
        _uci_real:foreach("wireless", "wifi-device", function(s)                                                                                       
	        sec_dev_name = s[".name"]
        end)
        _uci_real:set("wireless", sec_dev_name, "disabled", "0")     
                
	if (restartWifi > 0) then
		_uci_real:commit("network")
		_uci_real:commit("wireless")
	end
	
        if ptest == 1 then
          return
        end  	
	
	if (restartWifi > 0) then
		-- requires restart of wifi, ifdown/up wifi and dnsmasq
		sys.call("env -i /sbin/ifdown wifi >/dev/null")
		sys.call("env -i /sbin/ifup wifi >/dev/null")
		sys.call("env -i /sbin/wifi down >/dev/null")
		sys.call("env -i /sbin/wifi up >/dev/null")
	end
	
	
	if (restartWifi > 1) then
		sys.call("env -i /etc/init.d/fix_hosts start >/dev/null")
		sys.call("env -i /etc/init.d/dnsmasq restart >/dev/null")
		sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
		sys.call("env -i /etc/init.d/gpsd start >/dev/null")
	end
	
       	vWrite("{}")
end

function changeNMEA(params) 
	local speed
	local port
	local type = "nmea0183"
	
	for k, v in pairs(params) do
		if k == "speed" then
			if isNumber(v) then
				speed = tonumber(v)
			end
		end
		if k == "port" then
			if isNumber(v) then
				port = tonumber(v)
			end
		end
		if k == "type" then
			type = v
		end
	end

	send_header()
        
        if (port == nil ) or (port < 0) then
        	vWrite(string.format("{\"internal error\": \"Empty or negative port number received.\"}", port))
        	return
        end
        
	local hw = readHardwareOptions()
	
        if hw == nil then
        	vWrite(string.format("{\"internal error\": \"Can't read hardware information.\"}", port))
        	return
        end
        
	local portno = -1
        for i=1,#hw.interfaces do
          if tonumber(hw.interfaces[i].port) == port then
            portno = i
            break
          end
        end 
        
        if portno < 0 then
          vWrite(string.format("{\"internal error\": \"Unkown port number %d received.\"}", port))
          return
        end

	if hw.interfaces[portno].type == "seatalk" then
          vWrite(string.format("{%q: \"Seatalk module installed. This port cannot be changed.\"}", "error"))
       	  return
	end
	
	if hw.interfaces[portno].type == "nmea0183" then
  	  if type == "seatalk" then
            vWrite(string.format("{%q: \"NMEA0183 module installed. This port cannot be changed to Seatalk. Contact vyacht to ask for how to install Seatalk.\"}", "error"))
       	    return
	  end
	end
	
	if hw.interfaces[portno].type == "nmea2000" then
          vWrite(string.format("{%q: \"NMEA2000 cannot be changed. Please report that you have seen this message.\"}", "error"))
       	  return
	end
	
	if (speed ~= nil) then
	
	  if speed == tonumber(hw.interfaces[portno].speed) then

            vWrite("{}")
            return

	  end
    
     	  if hw.module.type == "nmea2000" or hw.module.type == "vymodule" then
     	   
            local secname = "port" .. port
	        _uci_real:set("gpsd", secname, "speed", speed)      
	        _uci_real:commit("gpsd")
     	    
	        sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	        sys.call("env -i /etc/init.d/gpsd start >/dev/null")
	
       	    vWrite("{}")
   	    return 
    	  end
    		
	  local dev = ""
	  local name = ""
	  if(port == 1) then 
	    dev = "/dev/ttyS0"
	    name= "serial0"
	  else
	    dev = "/dev/ttyS1"
	    name="serial1"
	  end
	  
	  _uci_real:set("iomode", name, "speed", speed)
	  _uci_real:commit("iomode")
	  
          sys.call("env -i /etc/init.d/iomode start >/dev/null")
          vWrite("{}")
	else
	  vWrite(string.format("{\"error\": \"%s is not a valid baud rate!\"}", speed))
	end
end

function changeGps(params) 
	local port
	local feed
	local boradcast
	for k, v in pairs(params) do
		if k == "port" then
			if isNumber(v) then
				port = v
			end
		end
		if k == "feed" then
			feed = v
		end
		if k == "broadcast" then
			broadcast = v
		end
	end

	send_header()

	if port ~= nil then

		_uci_real:set("gpsd", "core", "port", port)
		_uci_real:commit("gpsd")
		sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
		sys.call("env -i /etc/init.d/gpsd start >/dev/null")
        	vWrite("{}")
		return

	elseif feed ~= nil then

          local m = feed:match("udp://(\*):(%d+)")
          if not m and feed ~= "" then                               
        	vWrite("{\"error\": \"Not a valid feed string! Only \'udp://*:<port no>\' currently supported.\"}")
                return
          end

	  -- now get all devices for gpsd
	  local t = _uci_real:get("gpsd", "core", "device")

	  local newt = {}                                  
	  local udp  = ""                                  

	  for k = 1, #t do                                 
	    if(t[k]:match("^udp://.*")) then               
	      udp = t[k]                                   
	    else                            
	      newt[#newt+1] = t[k]          
	    end                             
	  end  

	  if feed ~= "" then
            newt[#newt+1] = feed
          end
	  _uci_real:set("gpsd", "core", "device", newt)
	  _uci_real:commit("gpsd")                     

          sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	  sys.call("env -i /etc/init.d/gpsd start >/dev/null")
          vWrite("{}")

	elseif broadcast ~= nil then

          local ipaddr, port = broadcast:match("(\*):(%d+)")
          if not port and broadcast ~= "" then                               
                -- ipaddr may be empty
        	vWrite("{\"error\": \"Not a valid feed string! Only \'*:<port no>\' currently supported.\"}")
                return
          end

	  local sname = ""

	  _uci_real:foreach("gpsd", "interface",
  	    function(s)
    	      if s['.name'] == "udp1" then
		sname = s['.name']
              end
          end) 
	  if sname == "" then
	    sname = _uci_real:set("gpsd", "interface", "udp1")
	  end

	  -- if there is one already we take it and overwrite
	  _uci_real:set("gpsd", "udp1", "proto", "udp")
	  _uci_real:set("gpsd", "udp1", "port",  port)

          if (ipaddr and not ipaddr == "*") then
	  	_uci_real:set("gpsd", "udp1", "proto", ipaddr)
	  end

	  _uci_real:commit("gpsd")                     

          sys.call("env -i /etc/init.d/gpsd stop >/dev/null")
	  sys.call("env -i /etc/init.d/gpsd start >/dev/null")
          vWrite("{}")

	else
          vWrite("{\"error\": \"Not a valid port number or feed string!\"}")
	end
end

function deviceInstalled(device)
        lst = _uci_real:get("vyacht", "network", "device")
        local installed = 0 
        for i = 1, #lst do
          if lst[i] == device then 
            installed = 1 
          end
        end
        return installed
end

function networkStatus(device) 
  device.available = 0
  if device.installed == 1 then
    local isUp = vubus:call(string.format("network.interface.%s", device.network), "status", { })
    if isUp ~= nil then
      if isUp.up then
        device.status = "Up"
	device.available = 1
      else
        device.status = "Down"
      end
      for k, v in pairs(isUp) do
        if k == "ipv4-address" then
          -- array of pairs
          if #v > 0 then
            device.HostIP = v[1].address
            device.prefix = v[1].mask
          end
        end
      end
    else
      device.status = "Not connected"
    end
  else
    device.status = "Not installed"
  end
end

function getWifiKey(device)
  _uci_real:foreach("wireless", "wifi-iface",
  function(s)
    if s.device == device.name then
      device.key = s.key
    end
  end) 
	
  return wifi_data
end

function getNetDevices()
       
        -- first step: look at network devices and get their network names 
        -- this works only from /etc/config/vyacht or network
        local devices = {
          eth00 = {name = LANNAME, installed = 0, network = ""}, 
          eth01 = {name = WANNAME, installed = 0, network = ""}, 
          wifi  = {name = "radio0", installed = 0, network = ""}
        } 
        
        devices.eth00.installed = deviceInstalled(devices.eth00.name)
        devices.eth01.installed = deviceInstalled(devices.eth01.name)
        devices.wifi.installed = deviceInstalled(devices.wifi.name)
      
        _uci_real:foreach("network", "interface", function(s)            
          local sec_name = s[".name"]  -- network name                                          
          local net_name = sec_name
          typ_name = s[".type"]                                            
          
          local dev = _uci_real:get("network", sec_name, "ifname")
          local ip = _uci_real:get("network", sec_name, "ipaddr")
          local proto = _uci_real:get("network", sec_name, "proto")
          
          if dev ~= "lo" then
            for k, v in pairs(devices) do
              if v.installed == 1 then 
                if dev == v.name then
                  if net_name == "wan" then
                    v.type = "wan"
                  else
                    v.type = "lan"
                  end
                  
                  v.network = net_name
                  if proto ~= "dhcp" then
                    v.HostIP = ip 
                  end
                  v.proto = proto
                end
              else
                v.HostIP = "" 
                v.proto = ""
              end
            end
          end
        end)
        
        return devices
end

function processStatus(process)
  local ps = sys.processes()
  
    for k,v in pairs(ps) do
        local m = string.find(v["COMMAND"], process)
        if m then
          return "Running (" .. v["%CPU"] .. ")"
        end
    end
                        
    return "Disconnected"
end

function getStatus() 

        -- first step: look at network devices and get their network names 
        -- this works only from /etc/config/vyacht or network

        local dev
        local devices = getNetDevices()
        local hw      = readHardwareOptions()
        
	-- GPS
	local port = _uci_real:get("gpsd", "core", "port")
	local has_gpsd = fs.access("/var/run/gpsd.pid")


	local gps_data = {
		Status = "Disconnected",
		Port   = port
	}
	gps_data.Status = processStatus("/usr/sbin/gpsd")
	
        -- 3 devices: wifi, wan, lan1 or wifi, lan1, lan2
        -- max 1 wan
        -- 2 devices: wifi, wan or wifi, lan2
	networkStatus(devices.wifi);
  	networkStatus(devices.eth00);
	networkStatus(devices.eth01);
	
	getWifiKey(devices.wifi)

	if hw.module.type ~= "nmea2000" and hw.module.type ~= "vymodule" then
	  -- NMEA speed

	  hw.interfaces[1].actual = -1
	  hw.interfaces[2].actual = -1

          local dev  = "/dev/ttyS0"
          local actual  = sys.exec(string.format("stty -F %s speed", dev))
          if actual then
            actual = actual:gsub("^%s*(.-)%s*$", "%1")
            -- remember 0 is 1, lua is weird
            for i = 1, #hw.interfaces do
              if tonumber(hw.interfaces[i].port) == 1 then
              	hw.interfaces[i].actual = actual
              end
            end
          end

          dev  = "/dev/ttyS1"
          actual  = sys.exec(string.format("stty -F %s speed", dev))
          if actual then
            actual = actual:gsub("^%s*(.-)%s*$", "%1")
            for i = 1, #hw.interfaces do
              if tonumber(hw.interfaces[i].port) == 2 then
           	  hw.interfaces[i].actual = actual
              end
            end
          end
        else
            -- if there is any NMEA or Seatalk interfaces for nmea2000 or vymodule
            -- then we currently set actual speed == stored speed
            -- as we don't know actual speed
            -- port ~= 0 is those interfaces which are not the actual nmea2000
            for i = 1, #hw.interfaces do
              if tonumber(hw.interfaces[i].port) ~= 0 then
   	        hw.interfaces[i].actual = hw.interfaces[i].speed
              end
            end
	end

	local t = _uci_real:get("gpsd", "core", "device")

        local feed = ""        
	for k = 1, #t do                                 
	  if(t[k]:match("^udp://.*")) then               
	    feed = t[k]                                   
	  end                             
	end  

	send_header()

        local distversion = version.distversion

	local bc_ipaddr   = _uci_real:get("gpsd", "udp1", "ipaddr")
	local bc_port   = _uci_real:get("gpsd", "udp1", "port")

	if not bc_idpaddr then
		bc_ipaddr = "*"
	end
	broadcast = bc_ipaddr .. ":" .. bc_port

        -- kernel version needs some trimming
        local kernel = sys.exec("uname -r")
        kernel = kernel:find'^%s*$' and '' or kernel:match'^%s*(.*%S)'

	local data_to = {
		Hostname      = sys.hostname(),
		OS            = distversion,
		Firmware      = versionToString(hw.software.version),
		Time          = os.date(),
		Uptime        = sys.uptime(),
		KernelVersion = kernel,
		Module        = hw.module,
		GpsStatus     = gps_data,
		NMEAStatus    = hw.interfaces,
                GpsFeed       = feed,
                UdpBroadcast  = broadcast,
		NetDevices    = devices,
	}	
       
        _write_json(data_to)
end

-- _uci_real  = cursor or _uci_real or uci.cursor()
-- getStatus()

--local pkgname = "io"
--local package = sys.exec("opkg list-installed | grep " .. pkgname)            
--for k in string.gmatch(package, "(.-)(%s)-(%s)(.-)\n") do
  -- wpad-mini - 20120910-1
--  print("line: " .. k)
--end 

