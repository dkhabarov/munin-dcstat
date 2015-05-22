#!/usr/bin/env lua5.1

--[[

	***************************************************************************
	dcstat_.lua - Plugin for Munin to show statistics of NeoModus Direct Connect (NMDC) hubs.

	Copyright © 2013 Denis Khabarov aka 'Saymon21'
	E-Mail: saymon at hub21 dot ru (saymon@hub21.ru)

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License version 3
	as published by the Free Software Foundation.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
	***************************************************************************
	Depends: NMDC Hubs Pinger by alex82: http://mydc.ru/topic4787.html
	***************************************************************************


	HOWTO INSTALL (In Debian/Ubuntu):

	sudo apt-get -y install lua5.1 liblua5.1-socket2
	sudo cp dcstat_.lua /usr/share/munin/plugins/dcstat_.lua
	sudo chmod +x /usr/share/munin/plugins/dcstat_.lua

	echo '[dcstat_*]
		env.HUB_ADDR dc.hub21.ru 
		env.HUB_PORT 411
		env.PINGER_NAME munindcstat
		env.PINGER_PASSWD 123
		env.PINGER_SHARESIZE 10GB' |sudo tee -a /etc/munin/plugin-conf.d/munin-node


	sudo ln -s /usr/share/munin/plugins/dcstat_.lua /etc/munin/plugins/dcstat_users
	sudo ln -s /usr/share/munin/plugins/dcstat_.lua /etc/munin/plugins/dcstat_share

	sudo /etc/init.d/munin-node restart
	***************************************************************************
]]

local res,err=pcall(dofile,'/usr/share/lua/5.1/nmdc_pinger.lua')
if not res then
	print(('Unable to load pinger. Error: %s'):format(err))
	print('For download pinger.lua visit to \'http://mydc.ru/topic4787.html\'')
	os.exit(1)
end

function get_hub_addr()
	local addr = os.getenv('HUB_ADDR')
	if type(addr) == 'string' then
		return addr
	else
		return 'localhost'
	end
end

function get_hub_port()
	local port = os.getenv('HUB_PORT') 
	if port and port:match('^%d+$') then
		return port
	else 
		return 411
	end
end

function get_pinger_nick()
	local nick = os.getenv('PINGER_NAME')
	if type(nick) == 'string' then
		return nick
	else
	 	return 'muninnmdc'
	 end
end

function get_pinger_password()
	local pass = os.getenv('PINGER_PASSWD')
	if type(pass) == 'string' then
		return pass
	end
end

function get_pinger_sharesize()
	local size = os.getenv('PINGER_SHARESIZE')
	if type(size) == 'string' then
		return convert_normal_size_to_bytes(size)
	end
end

function get_statistic_param()
	local name = ''
	local params = {['users']=true, ['share']=true}
	if arg and arg[0] then
		name = arg[0]:match('/dcstat_(%S+)$')
		if name and params[name] then
			return name
		else
			print(('Unknown mode %s.'):format((name or '?')))
			os.exit(1)
		end
	end
end

function convert_normal_size_to_bytes (value)
	if value and value ~= "" then
		value = value:lower()
		local t = { ["b"] = 1, ["kb"] = 1024, ["mb"] = 1024^2, ["gb"] = 1024^3, ["tb"] =1024^4, ["pb"] =1024^5}
		local _,_,num = value:find("^(%d+%.*%d*)")
		local _,_,tail = value:find("^%d+%.*%d*%s*(%a+)$")
		if not num then 
			return false 
		end
		num = tonumber(num)
		if not tail then 
			return num 
		end

		local multiplier = 1
		if num and tail and t[tail] then
			multiplier = t[tail]
		elseif not num or (tail and not t[tail]) then
			return false
		end
			return (tonumber(num) * multiplier)
	else
		return false
	end
end


function config()
	print('graph_category dchub')
	print(('graph_info This graph shows statistics of dc++ %s:%d hub'):format(get_hub_addr(),get_hub_port()))
	if get_statistic_param() == 'users' then
		print('graph_args --base 1000 -l 0')
		print('graph_scale no')
		print('graph_title Connected users')
		print('users.type GAUGE')
		print('users.info count')
		print('users.label users')
	end
	if get_statistic_param() == 'share' then
		print('graph_args --base 1024 -l 0')
		print('graph_scale yes')
		print('graph_title Total share')
		print('share.type GAUGE')
		print('share.info size')
		print('share.label size')
	end
end


function main()
	if arg and arg[1] == 'config' then
		config()
	else
		local hub = Ping(get_hub_addr(), get_hub_port(), get_pinger_nick(), get_pinger_password(), get_pinger_sharesize())
		if hub.Online then	
			if get_statistic_param() == 'users' then
				print(('users.value %s'):format((hub.Users or 0)))
			elseif get_statistic_param() == 'share' then
				print(('share.value %s'):format((hub.Share*1024 or 0)))
			end
		else 
			print('users.value 0')
			print('share.value 0')
		end
	end
end


if arg and type(arg) == 'table' then
	main()
end
