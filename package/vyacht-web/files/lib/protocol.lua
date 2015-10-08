--[[

HTTP protocol implementation for LuCI
(c) 2008 Freifunk Leipzig / Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

$Id: protocol.lua 9195 2012-08-29 13:06:58Z jow $

]]--

--- LuCI http protocol class.
-- This class contains several functions useful for http message- and content
-- decoding and to retrive form data from raw http messages.
module("vyacht.protocol", package.seeall)

HTTP_MAX_CONTENT      = 1024*8		-- 8 kB maximum content size

--- Decode an urlencoded string - optionally without decoding
-- the "+" sign to " " - and return the decoded string.
-- @param str		Input string in x-www-urlencoded format
-- @param no_plus	Don't decode "+" signs to spaces
-- @return			The decoded string
-- @see				urlencode
function urldecode( str, no_plus )

	local function __chrdec( hex )
		return string.char( tonumber( hex, 16 ) )
	end

	if type(str) == "string" then
		if not no_plus then
			str = str:gsub( "+", " " )
		end

		str = str:gsub( "%%([a-fA-F0-9][a-fA-F0-9])", __chrdec )
	end

	return str
end

--- Extract and split urlencoded data pairs, separated bei either "&" or ";"
-- from given url or string. Returns a table with urldecoded values.
-- Simple parameters are stored as string values associated with the parameter
-- name within the table. Parameters with multiple values are stored as array
-- containing the corresponding values.
-- @param url	The url or string which contains x-www-urlencoded form data
-- @param tbl	Use the given table for storing values (optional)
-- @return		Table containing the urldecoded parameters
-- @see			urlencode_params
function urldecode_params( url, tbl )

	local params = tbl or { }

	if url:find("?") then
		url = url:gsub( "^.+%?([^?]+)", "%1" )
	end

	for pair in url:gmatch( "[^&;]+" ) do

		-- find key and value
		local key = urldecode( pair:match("^([^=]+)")     )
		local val = urldecode( pair:match("^[^=]+=(.+)$") )

		-- store
		if type(key) == "string" and key:len() > 0 then
			if type(val) ~= "string" then val = "" end

			if not params[key] then
				params[key] = val
			elseif type(params[key]) ~= "table" then
				params[key] = { params[key], val }
			else
				table.insert( params[key], val )
			end
		end
	end

	return params
end
