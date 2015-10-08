module(..., package.seeall)

function readFile(filename)

  conf = {}
 
  fp = io.open( filename, "r" )
  
  if not fp then
    return nil
  end
  
  for line in fp:lines() do
      line = line:match( "%s*(.+)" )
      if line and line:sub( 1, 1 ) ~= "#" and line:sub( 1, 1 ) ~= ";" then
        option = line:match( "%S+" ):lower()
        value  = line:match( "%S*%s*(.*)" )
           		 
        if not value then
          conf[option] = true
        else
          if not value:find( "," ) then
            conf[option] = value
          else
            value = value .. ","
            conf[option] = {}

            for entry in value:gmatch( "%s*(.-)," ) do
              conf[option][#conf[option]+1] = entry
            end
          end
        end
    			    	 
      end
  end
 
  fp:close()
  
  return conf
  
end

function writeFile(filename, conf)
  local file = io.open(filename, "w")
  
  if not file then
    return
  end

  for k, v in pairs(conf) do
    if type(v) == "table" then
      file:write(k)
      local n = 0
      for k1, v1 in pairs(conf[k]) do
        if n > 0 then
          file:write(",")
        end 
        file:write(" " .. v1)
        n = n + 1
      end
      file:write("\n")
    else
      file:write(k .. " " .. v .. "\n")
    end
  end
  
  file:close()
  
end

