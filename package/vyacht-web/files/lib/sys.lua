local io     = require "io"                                                         
local os     = require "os"                                                         
local nixio  = require "nixio"

--- stolen from luci

local type, table, tonumber, print
	= type, table, tonumber, print
         
module "vyacht.sys"                                                                        

--- Execute a given shell command and return the error code                                       
-- @class               function                                                         
-- @name                call                                                             
-- @param               ...             Command to call                                           
-- @return              Error code of the command                                        
function call(...)                                                                       
        return os.execute(...) / 256                                                     
end                                                                                      

--- Execute given commandline and gather stdout.                       
-- @param command       String containing command to execute
-- @return                      String containing the command's stdout   
function exec(command)
	local pp   = io.popen(command)
	local data = pp:read("*a")      
	pp:close()
	return data                           
end                                                       



--- Return a line-buffered iterator over the output of given command.
-- @param command       String containing the command to execute
-- @return                      Iterator
function execi(command)                                                                               
	local pp = io.popen(command)      

	return pp and function()                                 
		local line = pp:read()

		if not line then
			pp:close()             
		end                                                             

		return line                                                    
	end                                                                   
end                                  

--- Get or set the current hostname.
-- @param               String containing a new hostname to set (optional)
-- @return              String containing the system hostname
function hostname(newname)                                                       
	if type(newname) == "string" and #newname > 0 then                       
		fs.writefile( "/proc/sys/kernel/hostname", newname )
		return newname
	else                              
		return nixio.uname().nodename
	end
end                                                        

--- Returns the current system uptime stats.
-- @return      String containing total uptime in seconds
function uptime()
        return nixio.sysinfo().uptime                                            
end                                                                              
       

--- Retrieve information about currently mounted file systems.
-- @return      Table containing mount information
function mounts()
        local data = {}
        local k = {"fs", "blocks", "used", "available", "percent", "mountpoint"}
        local ps = execi("df")

        if not ps then
                return
        else
                ps()
        end

        for line in ps do
                local row = {}

                local j = 1
                for value in line:gmatch("[^%s]+") do
                        row[k[j]] = value
                        j = j + 1
                end

                if row[k[1]] then

                        -- this is a rather ugly workaround to cope with wrapped lines in
                        -- the df output:
                        --
                        --      /dev/scsi/host0/bus0/target0/lun0/part3
                        --                   114382024  93566472  15005244  86% /mnt/usb
                        --

                        if not row[k[2]] then
                                j = 2
                                line = ps()
                                for value in line:gmatch("[^%s]+") do
                                        row[k[j]] = value
                                        j = j + 1
                                end
                        end

                        table.insert(data, row)
                end
        end

        return data
end

 --- Retrieve information about currently running processes.
-- @return      Table containing process information
function processes()
        local data = {}
        local k
        local ps = execi("/bin/busybox top -bn1")

        if not ps then
                return
        end

        for line in ps do
                local pid, ppid, user, stat, vsz, mem, cpu, cmd = line:match(
                        "^ *(%d+) +(%d+) +(%S.-%S) +([RSDZTW][W ][<N ]) +(%d+) +(%d+%%) +(%d+%%) +(.+)"
                )

                local idx = tonumber(pid)
                if idx then
                        data[idx] = {
                                ['PID']     = pid,
                                ['PPID']    = ppid,
                                ['USER']    = user,
                                ['STAT']    = stat,
                                ['VSZ']     = vsz,
                                ['%MEM']    = mem,
                                ['%CPU']    = cpu,
                                ['COMMAND'] = cmd
                        }
                end
        end

        return data
end


