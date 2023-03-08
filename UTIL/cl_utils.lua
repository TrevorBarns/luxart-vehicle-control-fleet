--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_utils.lua
PURPOSE: Utilities for siren assignments and tables
		 and other common functions.
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
UTIL = { }

HORNS = { }
SIRENS = { }
MENU = { }
VCF_ID = nil

local SETTINGS = SETTINGS
local approved_VCF_IDs = { }
local approved_VCF_names = { }
VCF_index = nil

local tone_options = { }
local profile = nil


---------------------------------------------------------------------
--[[Return sub-table for sirens or plugin settings tables, given veh, and name of whatever setting.]]
function UTIL:GetProfileFromTable(print_name, tbl, veh, ignore_missing_default)
	local ignore_missing_default = ignore_missing_default or false
	-- Ignore case of gameName
	local veh_name = string.upper(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
	local lead_and_trail_wildcard = veh_name:gsub('%d+', '#')
	local lead = veh_name:match('%d*%a+')
	local trail = veh_name:gsub(lead, ''):gsub('%d+', '#')
	local trail_only_wildcard = string.format('%s%s', lead, trail)
	
	local profile_table, profile
	if tbl ~= nil then
		if tbl[veh_name] ~= nil then							--Does profile exist as outlined in vehicle.meta
			profile_table = tbl[veh_name]
			profile = veh_name
			self:Print(('^4LVC(%s) ^5%s: ^7profile %s found for %s.'):format(STORAGE:GetCurrentVersion(), print_name, profile, veh_name))
		elseif tbl[trail_only_wildcard] ~= nil then				--Does profile exist using # as wildcard for any trailing digits.
			profile_table = tbl[trail_only_wildcard]
			profile = trail_only_wildcard
			self:Print(('^4LVC(%s) ^5%s: ^7profile %s found for %s.'):format(STORAGE:GetCurrentVersion(), print_name, profile, veh_name))
		elseif tbl[lead_and_trail_wildcard] ~= nil then			--Does profile exist using # as wildcard for any digits.
			profile_table = tbl[lead_and_trail_wildcard]
			profile = lead_and_trail_wildcard
			self:Print(('^4LVC(%s) ^5%s: ^7profile %s found for %s.'):format(STORAGE:GetCurrentVersion(), print_name, profile, veh_name))			
		else
			if tbl['DEFAULT'] ~= nil then
				profile_table = tbl['DEFAULT']
				profile = 'DEFAULT'
				self:Print(('^4LVC(%s) ^5%s: ^7using default profile for %s.'):format(STORAGE:GetCurrentVersion(), print_name, veh_name))
				if print_name == 'SIRENS' then
					HUD:ShowNotification(('~b~LVC~s~: Using ~b~DEFAULT~s~ profile for \'~o~ %s ~s~\'.'):format(veh_name))
				end
 			else
				profile_table = { }
				profile = false
				if not ignore_missing_default then
					self:Print(('^3LVC(%s) WARNING: "DEFAULT" table missing from %s table. Using empty table for %s. (https://tinyurl.com/missing-default)'):format(STORAGE:GetCurrentVersion(), print_name, veh_name), true)
				end
			end
		end
	else
		profile_table = { }
		profile = false
		HUD:ShowNotification(('~b~~h~LVC~h~ ~r~ERROR: %s attempted to get profile from nil table. See console.'):format(print_name), true)
		self:Print(('^1LVC(%s) ERROR: %s attempted to get profile from nil table. This is typically caused by an invalid character or missing { } brace in SIRENS.lua. (https://tinyurl.com/nil-table)'):format(STORAGE:GetCurrentVersion(), print_name), true)
	end
	
	return profile_table, profile
end

---------------------------------------------------------------------
--[[Shorten oversized <gameName> strings in SIREN_ASSIGNMENTS (SIRENS.LUA).
    GTA only allows 11 characters. So to reduce confusion we'll shorten it if the user does not. Also upper gameName for ignoring case.]]
function UTIL:FixOversizeKeys(TABLE)
	for i, tbl in pairs(TABLE) do
		if string.len(i) > 11 then
			local shortened_gameName = string.upper(string.sub(i,1,11))
			TABLE[shortened_gameName] = TABLE[i]
			TABLE[i] = nil
		end
	end
end

---------------------------------------------------------------------
--[[Get approved VCF IDs, sets initial VCF, copys VCF data to existing tables AUDIO, HUD, LVC]]
function UTIL:UpdateCurrentVCFData(veh, reset)
	local reset = reset or false
	while VCFs.set ==  false or MCTRL == nil do
		Wait(50)
	end

	-- Temp save override settings for restoration
	local temp_peer_override = MCTRL:GetOverridePeerState()
	local temp_siren_mode = MCTRL:GetSirenMode()

	approved_VCF_IDs, profile = self:GetProfileFromTable('PROFILE', SETTINGS.VCF_Assignments, veh)

	VCF_ID = approved_VCF_IDs[VCF_index]
	local profile_data = VCFs[VCF_ID]
	
	if profile_data == nil then
		UTIL:Print("^3UTIL: profile_data was nil, loading failed.", true)
		return
	end

	-- Import settings to global tables
	for key,value in pairs(profile_data.AUDIO) do
		AUDIO[key] = value
	end
	
	for key,value in pairs(profile_data.HUD) do
		HUD[key] = value
	end
	
	for key,value in pairs(profile_data.LVC) do
		LVC[key] = value
	end
	
	MENU = profile_data.MENU
	HORNS = profile_data.HORNS
	SIRENS = profile_data.SIRENS

	-- HUD Options
	HUD:SetHudState(HUD.enabled)
	--Rumbler Settings
	MCTRL:SetRumblerDurationIndex(LVC.rumbler_duration_index)
	LVC.rumbler_enabled = LVC.rumbler
	
	--Build options table
	self:BuildToneOptions()
	
	-- Restore previous override settings, unless resetting from Storage
	if not reset then
		MCTRL:SetOverridePeerState(temp_peer_override)
		MCTRL:SetSirenMode(temp_siren_mode)
	else
		MCTRL:SetOverridePeerState(LVC.peer_override)
		MCTRL:SetSirenMode(LVC.local_override)
	end
	
	-- Create VCF names tables
	approved_VCF_names = {}
	for i,v in ipairs(approved_VCF_IDs) do
		approved_VCF_names[#approved_VCF_names+1] = { Name = string.sub(SETTINGS.VCF_Files[v], 1, -5), Value = i}
	end

end

---------------------------------------------------------------------
--[[Returns List of approved VCF Ids from SETTINGS]]
function UTIL:GetApprovedVCFIds()
	return approved_VCF_IDs
end

--[[Returns List of approved VCF file names]]
function UTIL:GetApprovedVCFNames()
	return approved_VCF_names
end

--[[Returns name of the currently active VCF]]
function UTIL:GetCurrentVCFName()
	return approved_VCF_names[VCF_index].Name
end

--[[Returns all approved VCF data]]
function UTIL:GetApprovedVCFs()
	local VCF_data = { }
	for _, VCF_ID in pairs(self:GetApprovedVCFIds()) do
		table.insert(VCF_data, VCFs[VCF_ID])
	end
	return VCF_data
end

---------------------------------------------------------------------
--[[Builds a table that we store tone_options in (disabled, button & cycle, cycle only, button only).
    Users can set default option of siren by using optional index .Option in SIREN_ASSIGNMENTS table in SIRENS.LUA]]
function UTIL:BuildToneOptions()
	local temp_array = { }
	local option
	for tone, siren_table in pairs(SIRENS) do
		option = siren_table.Option or 1
		temp_array[tone] = option
	end
	tone_options = temp_array
end

--Setter for single tone_option
function UTIL:SetToneOption(tone_id, option)
	tone_options[tone_id] = option
end

--Getter for single tone_option
function UTIL:GetToneOption(tone_id)
	return tone_options[tone_id]
end

--Getter for tone_options table (used for saving)
function UTIL:GetToneOptionsTable()
	return tone_options
end

---------------------------------------------------------------------
--[[Gets next tone based off vehicle profile and current tone.]]
function UTIL:GetNextSirenTone(current_tone, veh, main_tone)
	local main_tone = main_tone or false
	local result 

	if current_tone < #SIRENS then
		result = current_tone+1
	else
		result = 1
	end

	if main_tone then
		--Check if the tone is set to 'disable' or 'button-only' if so, find next tone
		if tone_options[result] > 2 then
			result = UTIL:GetNextSirenTone(result, veh, main_tone)
		end
	end

	return result
end

---------------------------------------------------------------------
--[[Ensure not all sirens are disabled / button only]]
function UTIL:IsOkayToDisable(tone, new_option)
	local count = 0
	
	--Create a tone_table to reflect the new changes and verify it still passes
	local temp_option_table = { }
	for tone, option in pairs(tone_options) do
		temp_option_table[tone] = option
	end
	temp_option_table[tone] = new_option
	
	for tone, option in pairs(temp_option_table) do
		if option < 3 then
			count = count + 1
		end
	end
	if count > 0 then
		return true
	end
	return false
end

------------------------------------------------
--[[Handle changing of tone_table custom names]]
function UTIL:ChangeToneString(tone_id, new_name, horn)
	horn = horn or false
	STORAGE:SetCustomToneStrings(true)
	
	if horn then
		HORNS[tone_id].Name = new_name
	else
		SIRENS[tone_id].Name = new_name
	end
end


---------------------------------------------------------------------
--[[Returns String <gameName> used for saving, loading, and debugging]]
function UTIL:GetVehicleProfileName()
	return profile
end

---------------------------------------------------------------------
--[[Prints to FiveM console, prints more when debug flag is enabled or overridden for important information]]
function UTIL:Print(string, override)
	override = override or false
	if debug_mode or override then
		print(string)
	end
end

---------------------------------------------------------------------
--[[Finds index of element in table given table and element.]]
function UTIL:IndexOf(tbl, tgt)
	for i, v in pairs(tbl) do
		if v == tgt then
			return i
		end
	end
	return nil
end

---------------------------------------------------------------------
--[[This function looks like #!*& for user convenience (and my lack of skill or abundance of laziness),
	it is called when needing to change an extra, it allows users to do things like ['<model>'] = { Brake = 1 } while
	also allowing advanced users to write configs like this ['<model>'] = { Brake = { add = { 3, 4 }, remove = { 5, 6 }, repair = true } }
	which can add and remove multiple different extras at once and adds flag to repair the vehicle
	for extras that are too large and require the vehicle to be reloaded. Once it figures out the
	users config layout it calls itself again (recursive) with the id we actually need toggled right now.]]
function UTIL:TogVehicleExtras(veh, extra_id, state, repair)
	local repair = repair or false
	if type(extra_id) == 'table' then
		-- Toggle Same Extras Mode
		if extra_id.toggle ~= nil then
			-- Toggle Multiple Extras
			if type(extra_id.toggle) == 'table' then
				for i, singe_extra_id in ipairs(extra_id.toggle) do
					self:TogVehicleExtras(veh, singe_extra_id, state, extra_id.repair)
				end
			-- Toggle a Single Extra (no table)
			else
				self:TogVehicleExtras(veh, extra_id.toggle, state, extra_id.repair)
			end
		-- Toggle Different Extras Mode
		elseif extra_id.add ~= nil and extra_id.remove ~= nil then
			if type(extra_id.add) == 'table' then
				for i, singe_extra_id in ipairs(extra_id.add) do
					self:TogVehicleExtras(veh, singe_extra_id, state, extra_id.repair)
				end
			else
				self:TogVehicleExtras(veh, extra_id.add, state, extra_id.repair)
			end
			if type(extra_id.remove) == 'table' then
				for i, singe_extra_id in ipairs(extra_id.remove) do
					self:TogVehicleExtras(veh, singe_extra_id, not state, extra_id.repair)
				end
			else
				self:TogVehicleExtras(veh, extra_id.remove, not state, extra_id.repair)
			end
		end
	else
		if state then
			if not IsVehicleExtraTurnedOn(veh, extra_id) then
				local doors =  { }
				if repair then
					for i = 0,6 do
						doors[i] = GetVehicleDoorAngleRatio(veh, i)
					end
				end
				SetVehicleAutoRepairDisabled(veh, not repair)
				SetVehicleExtra(veh, extra_id, false)
				self:Print(('^4LVC: ^7Toggling %s on'):format(extra_id), false)
				SetVehicleAutoRepairDisabled(veh, false)
				if repair then
					for i = 0,6 do
						if doors[i] > 0.0 then
							SetVehicleDoorOpen(veh, i, true, false)
						end
					end
				end
			end
		else
			if IsVehicleExtraTurnedOn(veh, extra_id) then
				SetVehicleExtra(veh, extra_id, true)
				self:Print(('^4LVC: ^7Toggling extra %s off'):format(extra_id), false)
			end
		end
	end
	SetVehicleAutoRepairDisabled(veh, false)
end

---------------------------------------------------------------------
--[[Verify LVC is configured and no known conflicting siren controllers are running]]
function UTIL:IsValidEnviroment()
	local lux_vehcontrol_state = GetResourceState('lux_vehcontrol') == 'started' 
	local lvc_state = GetResourceState('lvc') == 'started' 
	local qb_extras_state = GetResourceState('qb-extras') == 'started' 

	if GetCurrentResourceName() ~= 'lvc_fleet' then
		Wait(1000)
		HUD:ShowNotification('~b~~h~LVC~h~ ~r~~h~CONFIG ERROR~h~~s~: INVALID RESOURCE NAME. SEE LOGS. CONTRACT SERVER DEVELOPER.', true)
		self:Print('^1CONFIG ERROR: INVALID RESOURCE NAME. PLEASE VERIFY RESOURCE FOLDER NAME READS "^3lvc_fleet^1" (CASE-SENSITIVE). THIS IS REQUIRED FOR PROPER SAVE / LOAD FUNCTIONALITY. PLEASE RENAME, REFRESH, AND ENSURE.', true)
		return false
	end
	if SETTINGS.community_id == nil or SETTINGS.community_id == '' then
		Wait(1000)
		HUD:ShowNotification('~b~~h~LVC~h~ ~r~~h~CONFIG ERROR~h~~s~: COMMUNITY ID MISSING. SEE LOGS. CONTACT SERVER DEVELOPER.', true)
		self:Print('^1CONFIG ERROR: COMMUNITY ID NOT SET, THIS IS REQUIRED TO PREVENT CONFLICTS FOR PLAYERS WHO PLAY ON MULTIPLE SERVERS WITH LVC. PLEASE SET THIS IN SETTINGS.LUA.', true)
		return false
	end
	if lux_vehcontrol_state or lvc_state or qb_extras_state then
		Wait(1000)
		HUD:ShowNotification('~b~~h~LVC~h~ ~r~~h~CONFLICT ERROR~h~~s~: RESOURCE CONFLICT. SEE CONSOLE.', true)
		self:Print('^1LVC ERROR: DETECTED CONFLICTING RESOURCE, PLEASE VERIFY THAT "^3lux_vehcontrol^1", "^3lvc^1", OR "^3qb-extras^1" ARE NOT RUNNING.', true)
		return false
	end
	return true
end