
local uci      = require "uci"
local _go      = require "vyacht.get-opt-alt"


vtest = 1
local vy      = require "vyacht"

_uci_real  = cursor or _uci_real or uci.cursor()                   

-- option lua_prefix       /lua              
-- option lua_handler      /www/vyacht.lua
        
_uci_real:set("uhttpd", "main", "lua_prefix", "/lua")
_uci_real:set("uhttpd", "main", "lua_handler", "/www/vyacht.lua")
                                      
_uci_real:commit("uhttpd")

os.execute("/etc/init.d/uhttpd restart");

-- vi /etc/inittab
local file = io.open("/etc/inittab", "w")
if file ~= nil then
   file:write("::sysinit:/etc/init.d/rcS S boot\n")
   file:write("::shutdown:/etc/init.d/rcS K shutdown\n")
   file:flush()
   io.close(file) 
end

-- vi /etc/config/vyacht
local opts = _go.getopt(arg, options)
local eths = -1
local seatalk = 0
local n2k = 0
local nmea0183 = 0

if opts["eth"] == nil then
  print("no number of ethernet devices given")
  return
else 
  eths = tonumber(opts["eth"])
  print("number of ethernet devices given: " .. eths )
end

if eths < 0 or eths > 2 then
  print("wrong number of ethernet devices given")
  return
end

if opts["seatalk"] then
  seatalk = 1
end
if opts["n2k"] then
  n2k = 1
end
if opts["nmea0183"] then
  nmea0183 = 1
end

local hw = readHardwareOptions()

if not hw then
  print("no hardware description found")
  return
end

if hw.software.version.x == 0 then
  print("too old software version found")
  return
end
  

if eths == 1 then
  hw.network.devices = {"radio0", "eth0"}
elseif eths == 2 then
  hw.network.devices = {"radio0", "eth0", "eth1"}
else 
  hw.network.devices = {"radio0"}
end

hw.module.type = "nmea0183"

if n2k == 1 then

  hw.module.type = "nmea2000"
  hw.module.interface = "serial"
  
  _uci_real:set("gpsd", "core", "device", {"vyspi:///dev/ttyATH0"})
  _uci_real:commit("gpsd")
  
  -- write vymodule file
  -- local file = io.open("/etc/config/vymodule", "w")
  -- file:write("")
  -- file:flush()
  -- io.close(file)
  
  if seatalk == 1 then                                    
    local it1 = {port = 2, speed = 4800, type = "seatalk", enabled = 1 } 
    table.insert(hw.interfaces, it1)                                     
    local it2 = {port = 1, speed = 4800, type = "nmea0183", enabled = 1 }
    table.insert(hw.interfaces, it2)                                     
  elseif nmea0183 then                                   
    local it1 = {port = 1, speed = 4800, type = "nmea0183", enabled = 1 }
    table.insert(hw.interfaces, it1)                                     
    local it2 = {port = 2, speed = 4800, type = "nmea0183", enabled = 1 }
    table.insert(hw.interfaces, it2)
  end         
                                                                  
elseif seatalk == 1 then           
  hw.module.type = "seatalk"
  _uci_real:set("gpsd", "core", "device", {"/dev/ttyS0", "st:///dev/ttyS1"})
  _uci_real:commit("gpsd")                                       
                                                   
else
  _uci_real:set("gpsd", "core", "device", {"/dev/ttyS0", "/dev/ttyS1"})
  _uci_real:commit("gpsd")
end

writeHardwareOptions(hw)

resetSystem()

