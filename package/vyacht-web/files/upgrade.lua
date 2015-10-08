
local uci      = require "uci"
local _go      = require "get-opt-alt"
local config   = require "vyacht.config"


vtest = 1
local vy      = require "vyacht"

_uci_real  = cursor or _uci_real or uci.cursor()                   

local opts = _go.getopt(arg, options)
local eths = -1

local hw = readHardwareOptions()

u, error = isSystemUpgradeable(hw)

if not u then 
  print(error)
end

local fileshort = "vyacht-wifi-7.3.0-upgrade-1.0.0.bin"
local pattern = "^vyacht%-wifi%-(%d+)%.(%d+)%.(%d+)%-upgrade%-(%d+)%.(%d+)%.(%d+).bin$"

print(string.find(fileshort, pattern))

local file = parseUpgradeFilename(fileshort)
if not file then                                                                                                            
 print(string.format("{\"error\": \"No a valid file for upgrade (%s)!\"}", fileshort))                                    
end

local conf = config.readFile("/tmp/test.conf")

if not conf then
  print( "no config file found" )
end

config.writeFile("/tmp/test.conf", conf)
