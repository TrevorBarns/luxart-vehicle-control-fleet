--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: server.lua
PURPOSE: Handle version checking, syncing vehicle 
states.
---------------------------------------------------
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
---------------------------------------------------
]]
-----------VEHICLE STATE REPEATER EVENTS-----------
RegisterServerEvent('lvc:TogDfltSrnMuted_s')
AddEventHandler('lvc:TogDfltSrnMuted_s', function(toggle)
	TriggerClientEvent('lvc:TogDfltSrnMuted_c', -1, source, toggle)
end)

RegisterServerEvent('lvc:SetLxSirenState_s')
AddEventHandler('lvc:SetLxSirenState_s', function(newstate, vcfid, mode)
	TriggerClientEvent('lvc:SetLxSirenState_c', -1, source, newstate, vcfid, mode)
end)

RegisterServerEvent('lvc:SetAuxilaryState_s')
AddEventHandler('lvc:SetAuxilaryState_s', function(newstate, vcfid, mode)
	TriggerClientEvent('lvc:SetAuxilaryState_c', -1, source, newstate, vcfid, mode)
end)

RegisterServerEvent('lvc:SetAirManuState_s')
AddEventHandler('lvc:SetAirManuState_s', function(newstate, vcfid, horn, mode)
	TriggerClientEvent('lvc:SetAirManuState_c', -1, source, newstate, vcfid, horn, mode)
end)

RegisterServerEvent('lvc:TogIndicState_s')
AddEventHandler('lvc:TogIndicState_s', function(newstate)
	TriggerClientEvent('lvc:TogIndicState_c', -1, source, newstate)
end)


---------------------------------------------------
-----------------RESROUCE STARTUP------------------
--------VERSION CHECKING & SERVER PRINTING---------
---------------------------------------------------

local curr_version = semver(GetResourceMetadata(GetCurrentResourceName(), 'version', 0))
local beta_checking = GetResourceMetadata(GetCurrentResourceName(), 'beta_checking', 0) == 'true'
local experimental = GetResourceMetadata(GetCurrentResourceName(), 'experimental', 0) == 'true' 
local debug_mode = GetResourceMetadata(GetCurrentResourceName(), 'debug_mode_server', 0) == 'true' 
local repo_version = ''
local repo_beta_version = ''

local plugin_count = 0
local plugins_cv = { }		-- table of active plugins current versions plugins_cv = { ['<pluginname>'] = <version> }
local plugins_rv = { }		-- table of active plugins repository versions

local function SortAlphabetically(a, b)
	if a.name > b.name then
		return false
	else
		return true
	end
end

--FLEET VARS
local XML = { }
local VCFs = { }

RegisterServerEvent('lvc:plugins_storePluginVersion')
AddEventHandler('lvc:plugins_storePluginVersion', function(name, version)
	plugin_count = plugin_count + 1
	table.insert(plugins_cv, { name = name, version = version } )
	table.insert(plugins_rv, { name = name, version = nil } )
end)

RegisterServerEvent('lvc:GetVCFs_s')
AddEventHandler('lvc:GetVCFs_s', function()
	TriggerClientEvent('lvc:SendVCFs_c', source, VCFs)
end)

RegisterServerEvent('lvc:GetRepoVersion_s')
AddEventHandler('lvc:GetRepoVersion_s', function()
	TriggerClientEvent('lvc:SendRepoVersion_c', source, repo_version)
end)


CreateThread( function()
-- Get LVC repo version from github
	PerformHttpRequest('https://raw.githubusercontent.com/TrevorBarns/luxart-vehicle-control-fleet/stable/version', function(err, responseText, headers)
		if responseText ~= nil and responseText ~= '' then
			repo_version = semver(responseText:gsub('\n', ''))
		end
	end)
-- Get LVC beta version from github
	PerformHttpRequest('https://raw.githubusercontent.com/TrevorBarns/luxart-vehicle-control-fleet/development/beta_version', function(err, responseText, headers)
		if responseText ~= nil and responseText ~= '' then
			repo_beta_version = semver(responseText:gsub('\n', ''))
		end
	end)

	Wait(1000)
  -- Get currently installed plugin versions (plugins -> 'lvc:plugins_storePluginVersion')
	TriggerEvent('lvc:plugins_getVersions')

  -- Get repo version for installed plugins
	for i, plugin in ipairs(plugins_cv) do
		PerformHttpRequest('https://raw.githubusercontent.com/TrevorBarns/luxart-vehicle-control-extras/master/Plugins/'..plugin.name..'/version', function(err, responseText, headers)
			if responseText ~= nil and responseText ~= '' then
				plugins_rv[i].version = responseText:gsub('\n', '')
			else
				plugins_rv[i].version = 'UNKWN'
			end
		end)
	end
	Wait(1000)
	table.sort(plugins_cv, SortAlphabetically)
	table.sort(plugins_rv, SortAlphabetically)
	print('\n\t^7 ______________________________________________________________')
	print('\t|\t^8         __                       ^9___                  ^7|')
	print('\t|\t^8        / /      ^7 /\\   /\\        ^9/ __\\                 ^7|')
	print('\t|\t^8       / /        ^7\\ \\ / /       ^9/ /                    ^7|')
	print('\t|\t^8      / /___       ^7\\ V /       ^9/ /___                  ^7|')
	print('\t|\t^8      \\____/uxart   ^7\\_/ehicle  ^9\\____/ontrol            ^7|')
	print('\t|\t^4                  FLEET EDITION                        ^7|')
	print(('\t|\t               COMMUNITY ID: %-26s|'):format(SETTINGS.community_id))
	print(('\t|\t              INSTALLED: %-30s|'):format(curr_version))
	if not beta_checking then
		print(('\t|\t                 LATEST: %-30s|'):format(repo_version))
	else
		if curr_version < repo_beta_version then
			print(('\t|\t            ^3LATEST BETA: %-30s^7|'):format(repo_beta_version))
		end
		print(('\t|\t          LATEST STABLE: %-30s|'):format(repo_version))
	end
	if GetResourceState('lux_vehcontrol') ~= 'started' and GetResourceState('lux_vehcontrol') ~= 'starting' and GetResourceState('lvc') ~= 'started' and GetResourceState('lvc') ~= 'starting' then
		if GetCurrentResourceName() == 'lvc_fleet' then
			if SETTINGS.community_id ~= nil and SETTINGS.community_id ~= '' then
				--	STABLE UPDATE DETECTED
				if curr_version < repo_version then
					print('\t^7|______________________________________________________________|')
					print('\t|\t            ^8STABLE UPDATE AVAILABLE                    ^7|')
					print('\t|^8                         DOWNLOAD AT:                         ^7|')
					print('\t|^2 github.com/TrevorBarns/luxart-vehicle-control-fleet/releases ^7|')
				elseif beta_checking and curr_version < repo_beta_version then
					print('\t^7|______________________________________________________________|')
					print('\t|\t             ^4BETA UPDATE AVAILABLE                     ^7|')
					print('\t|^4                         DOWNLOAD AT:                         ^7|')
					print('\t|^2 github.com/TrevorBarns/luxart-vehicle-control-fleet/releases ^7|')
				--	EXPERMENTAL VERSION
				elseif curr_version > repo_version or curr_version == repo_beta_version then
					print('\t^7|______________________________________________________________|')
					print('\t|\t                  ^3BETA VERSION                         ^7|')
					-- IS THE USER AWARE THEY DOWNLOADED EXPERMENTAL CHECK CONVARS
					if not experimental then
						print('\t|^3 THIS VERSION IS IN DEVELOPMENT AND IS NOT RECOMMENDED BUGS   ^7|')
						print('\t|^3 MAY EXIST. IF THIS WAS A MISTAKE DOWNLOAD THE LATEST STABLE  ^7|')
						print('\t|^3 RELEASE AT:                                                  ^7|')
						print('\t|^2 github.com/TrevorBarns/luxart-vehicle-control-fleet/releases ^7|')
						print('\t|^3 TO MUTE THIS: SET CONVAR \'experimental\' to \'true\'            ^7|')
					end
				end

				--	IF PLUGINS ARE INSTALLED
				if plugin_count > 0 then
					print('\t^7|______________________________________________________________|')
					print('\t^7|INSTALLED PLUGINS                     | INSTALLED |  LATEST   |')
					local plugin_string, current_version, repo_version
					for i, plugin in ipairs(plugins_cv) do
						current_version = plugin.version
						repo_version = plugins_rv[i].version
						
						if repo_version ~= nil and repo_version ~= 'UNKWN' and current_version < repo_version  then
							plugin_string = ('\t|^8  %-36s^7|^8   %s   ^7|^8   %s   ^7|^8 UPDATE REQUIRED    ^7'):format(plugin.name, current_version, repo_version)
						elseif repo_version ~= nil and current_version > repo_version or repo_version == 'UNKWN' then
							plugin_string = ('\t|^3  %-36s^7|^3   %s   ^7|^3   %s   ^7|^3 EXPERIMENTAL VERSION ^7'):format(plugin.name, current_version, repo_version)
						else
							plugin_string = ('\t|  %-36s|   %s   |   %s   |'):format(plugin.name, current_version, repo_version)
						end
						print(plugin_string)
					end
				end
			else	-- NO COMMUNITY ID SET
				print('\t^7|______________________________________________________________|')
				print('\t|\t^8                CONFIGURATION ERROR                    ^7|')
				print('\t|^8 COMMUNITY ID MISSING, THIS IS REQUIRED TO PREVENT CONFICTS   ^7|')
				print('\t|^8 FOR PLAYERS WHO PLAY ON MULTIPLE SERVERS WITH LVC. ^3PLEASE    ^7|')
				print('\t|^3 SET THIS IN SETTINGS.LUA.                                    ^7|')
			end
		else	-- INCORRECT RESOURCE NAME
				print('\t^7|______________________________________________________________|')
				print('\t|\t^8                CONFIGURATION ERROR                    ^7|')
				print('\t|^8 INVALID RESOURCE NAME. PLEASE VERIFY RESOURCE FOLDER NAME    ^7|')
				print('\t|^8 READS \'^3lvc_fleet^8\' (CASE-SENSITIVE). THIS IS REQUIRED FOR     ^7|')
				print('\t|^8 PROPER SAVE / LOAD FUNCTIONALITY. ^3PLEASE RENAME, REFRESH,    ^7|')
				print('\t|^3 AND RESTART.                                                 ^7|')
		end
	else	-- RESOURCE CONFLICT
			print('\t^7|______________________________________________________________|')
			print('\t|\t^8           RESOURCE CONFLICT DETECTED                  ^7|')
			print('\t|^8 DETECTED "lux_vehcontrol" OR "lvc" RUNNING THIS CONFLICTS    ^7|')
			print('\t|^8 WITH LVC:FLEET. ^3PLEASE ENSURE BOTH OF THESE ARE NOT RUNNING  ^7|')
			print('\t|^3 AND RESTART LVC:FLEET.                                       ^7|')
	end
	print('\t^7|______________________________________________________________|')
	print('\t^7|      Documentation & Instructions: ^5luxartengineering.com     ^7|')
	print('\t^7|       Updates, Support, Feedback: ^5discord.gg/PXQ4T8wB9       ^7|')
	print('\t^7|______________________________________________________________|\n\n')
end)


-----------------LVC FLEET THREADS-----------------
--Loads, Parses, and Rekeys VCF Files storing in VCFs[vcf_id(index)]
CreateThread(function()
	for id, filename in ipairs(SETTINGS.VCF_Files) do	--table of VCF filenames in SETTINGS.lua
		local data = LoadResourceFile(GetCurrentResourceName(), 'VCF/'..filename)
		if data then
			DebugPrint('------------------------------------------------------')			
			DebugPrint(('-----------------LOADING %s-----------------'):format(filename))			
			local VCF_RAW = parseFile(data)		--XML -> LUA
			local VCF = XML:RekeyTable(VCF_RAW, filename)	--integer key -> string key
			VCFs[id] = XML:LoadXMLData(VCF)		--reorganize & casting of var type
			DebugPrint(('loaded VCF file %s'):format(filename), true)
		end
	end
end)
---------------------------------------------------
--Removes tables indexed by integer and replaces with string key
function XML:RekeyTable(tbl, filename)
	local newTable = { }
	local faction = tbl[1].vcfroot['Faction']
	local author = tbl[1].vcfroot['Author']
	for i,v in pairs(tbl[1].vcfroot) do
		local newkey = v.tag
		if newkey ~= nil then
			newTable[newkey] = v[newkey]
			tbl[1].vcfroot[i] = nil
		end
	end
	newTable.faction = faction
	newTable.author = author
	return newTable
end
---------------------------------------------------
--var conversion function
function XML:StringToBool(str)
	local str = string.lower(str)
	if str == 'true' then	
		return true
	else
		return false
	end
end
---------------------------------------------------
--reorganizing xmltable into subtables and variable casting
function XML:LoadXMLData(xmlTable)
	local AUDIO, HUD, LVC, MENU, HORNS, SIRENS =  { }, { }, { }, { }, { }, { }
	LVC.faction = xmlTable.faction
	LVC.author = xmlTable.author

	for class, object in pairs(xmlTable) do
		if class == 'AUDIO' then
			for _, v in pairs(object) do
				local key = v.tag
				if v[key].Enabled ~= nil then
					AUDIO[string.lower(key)] = XML:StringToBool(v[key].Enabled)
					DebugPrint(('AUDIO.%s = %s'):format(string.lower(key), v[key].Enabled))			
				elseif v[key].Val ~= nil then
					AUDIO[string.lower(key)] = tonumber(v[key].Val)
					DebugPrint(('AUDIO.%s = %s'):format(string.lower(key), AUDIO[string.lower(key)]))				
				elseif key == 'SCHEMES' and v['SCHEMES'] ~= nil then
					AUDIO.schemes = { }
					for i, v in pairs(v['SCHEMES']) do
						AUDIO.schemes[#AUDIO.schemes+1] = v['SCHEME'].String
						DebugPrint(('AUDIO.%s[%s] = %s'):format('schemes', #AUDIO.schemes, json.encode(AUDIO.schemes[#AUDIO.schemes])))
					end		
				end
			end
		elseif class == 'HUD' then
			for key,v in pairs(object) do
				if key == 'Backlight_Mode' then
					HUD[string.lower(key)] = tonumber(v)
					DebugPrint(('HUD.%s = %s'):format(string.lower(key), v))
				else
					HUD[string.lower(key)] = XML:StringToBool(v)
					DebugPrint(('HUD.%s = %s'):format(string.lower(key), v))
				end
			end
		elseif class == 'SIREN_CONFIG' then
			for _,v in pairs(object) do
				local key = v.tag
				if v[key].ToneID ~= nil then
					LVC[string.lower(key)] = tonumber(v[key].ToneID)
					DebugPrint(('LVC.%s = %s'):format(string.lower(key), v[key].ToneID))
				elseif v[key].Enabled ~= nil then
					LVC[string.lower(key)]  = XML:StringToBool(v[key].Enabled)
					DebugPrint(('LVC.%s = %s'):format(string.lower(key), v[key].Enabled))
				elseif v[key].Val ~= nil then
					LVC[string.lower(key)]  = tonumber(v[key].Val)
					DebugPrint(('LVC.%s = %s'):format(string.lower(key), v[key].Val))
				end
			end		
		elseif class == 'TONES' then
			for i, v in pairs(object[1]['HORNS']) do
				HORNS[#HORNS+1] = v['HORN']
				if HORNS[#HORNS].Ref == '0' then
					HORNS[#HORNS].Ref = tonumber(HORNS[#HORNS].Ref)
				end
				if HORNS[#HORNS].Option ~= nil then
					HORNS[#HORNS].Option = tonumber(HORNS[#HORNS].Option)
				end
				DebugPrint(('HORNS[%s] = %s'):format(#HORNS, json.encode(HORNS[#HORNS])))
			end			
			for i, v in pairs(object[2]['SIRENS']) do
				SIRENS[#SIRENS+1] = v['SIREN']
				if SIRENS[#SIRENS].Ref == '0' then
					SIRENS[#SIRENS].Ref = tonumber(SIRENS[#SIRENS].Ref)
				end			
				if SIRENS[#SIRENS].Option ~= nil then
					SIRENS[#SIRENS].Option = tonumber(SIRENS[#SIRENS].Option)
				end
				DebugPrint(('SIRENS[%s] = %s'):format(#SIRENS, json.encode(SIRENS[#SIRENS])))
			end
		elseif class == 'MENU' then
			for _,v in pairs(object) do
				local key = v.tag
				if v[key].Enabled ~= nil then
					MENU[string.lower(key)] = XML:StringToBool(v[key].Enabled)
					DebugPrint(('MENU.%s = %s'):format(string.lower(key), v[key].Enabled))
				end
			end
		end
	end
	return { AUDIO=AUDIO, HUD=HUD, LVC=LVC, MENU=MENU, HORNS=HORNS, SIRENS=SIRENS } 
end
---------------------------------------------------
function DebugPrint(text, override)
	if debug_mode or override then
		print(('^4LVC Fleet: ^7%s'):format(text))
	end
end
