--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_storage.lua
PURPOSE: Handle save/load functions and version 
		 checking
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
STORAGE = { }
VCFs = { }
VCFs.set = false

local save_prefix = 'lvc:f_'..SETTINGS.community_id..'_'
local repo_version = nil
local custom_tone_names = false
local VCFs_backup = nil
local profiles = { }
		
--	forward local fn declaration
local IsNewerVersion
		
------------------------------------------------
--Deletes all saved KVPs for that vehicle profile
--	This should never be removed. It is the only easy way for end users to delete LVC data.
RegisterCommand('lvcfactoryreset', function(source, args)
	local choice = HUD:FrontEndAlert('Warning', 'Are you sure you want to delete all saved LVC data and Factory Reset?', '~g~No: Escape \t ~r~Yes: Enter')
	if choice then
		STORAGE:FactoryReset()
	end
end)

--Prints all KVP keys and values to console
--if GetResourceMetadata(GetCurrentResourceName(), 'debug_mode', 0) == 'true' then
	RegisterCommand('lvcdumpkvp', function(source, args)
		UTIL:Print('^4LVC ^5STORAGE: ^7Dumping KVPs...')
		local handle = StartFindKvp(save_prefix);
		local key = FindKvp(handle)
		while key ~= nil do
			if GetResourceKvpString(key) ~= nil then
				UTIL:Print('^4LVC ^5STORAGE Found: ^7"'..key..'" "'..GetResourceKvpString(key)..'", STRING', true)
			elseif GetResourceKvpInt(key) ~= nil then
				UTIL:Print('^4LVC ^5STORAGE Found: ^7"'..key..'" "'..GetResourceKvpInt(key)..'", INT', true)
			elseif GetResourceKvpFloat(key) ~= nil then
				UTIL:Print('^4LVC ^5STORAGE Found: ^7"'..key..'" "'..GetResourceKvpFloat(key)..'", FLOAT', true)
			end
			key = FindKvp(handle)
			Wait(0)
		end
		UTIL:Print('^4LVC ^5STORAGE: ^7Finished Dumping KVPs...')
	end)
--end
------------------------------------------------
-- Resource Start Initialization
CreateThread(function()
	TriggerServerEvent('lvc:GetRepoVersion_s')
	TriggerServerEvent('lvc:GetVCFs_s')
	STORAGE:FindSavedProfiles()
end)

--[[Function for Deleting KVPs]]
function STORAGE:DeleteKVPs(prefix)
	local handle = StartFindKvp(prefix);
	local key = FindKvp(handle)
	while key ~= nil do
		DeleteResourceKvp(key)
		UTIL:Print('^3LVC Info: Deleting Key \'' .. key .. '\'', true)
		key = FindKvp(handle)
		Wait(0)
	end
end

--[[Getter for current version used in RageUI.]]
function STORAGE:GetCurrentVersion()
	local curr_version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0)
	if curr_version ~= nil then
		return curr_version
	else
		return 'unknown'
	end
end

--[[Execute factory reset.]]
function STORAGE:FactoryReset()
	STORAGE:DeleteKVPs(save_prefix)
	STORAGE:ResetSettings()
	UTIL:Print('Success: cleared all save data.', true)
	HUD:ShowNotification('~g~Success~s~: You have deleted all save data and reset LVC.', true)
end

--[[Getter for repo version used in RageUI.]]
function STORAGE:GetRepoVersion()
	return repo_version
end

--[[Getter for out-of-date notification for RageUI.]]
function STORAGE:GetIsNewerVersion()
	return IsNewerVersion(repo_version, STORAGE:GetCurrentVersion())
end

--[[Saves HUD settings, separated from SaveSettings]]
function STORAGE:SaveHUDSettings()
	local hud_settings = {}
	if MENU.menu_hud_settings then
		if MENU.toggle_hud then
			hud_settings['hud_enabled'] = HUD:GetHudState()
		end
		if MENU.custom_backlight_mode then
			hud_settings['hud_backlight_mode'] = HUD:GetHudBacklightMode()
		end
		hud_settings['hud_pos'] = HUD:GetHudPosition()
		hud_settings['hud_scale'] = HUD:GetHudScale()
	end
	SetResourceKvp(save_prefix .. 'hud_data',  json.encode(hud_settings))
end


--[[Saves all KVP values.]]
function STORAGE:SaveSettings()
	UTIL:Print('^4LVC ^5STORAGE: ^7Saving Settings...')
	SetResourceKvp(save_prefix..'save_version', STORAGE:GetCurrentVersion())

	--HUD Settings
	STORAGE:SaveHUDSettings()	
	--[[TODO: compare backed up VCFs table with current options to ignore saving unedited options]]
	
	--VCF Specific Settings
	if UTIL:GetCurrentVCFName() ~= nil then
		local vcf_name = string.gsub(UTIL:GetCurrentVCFName(), ' ', '_')
		if vcf_name ~= nil then

			--Vehicle to VCF_ID
			if UTIL:GetVehicleProfileName() ~= nil then
				local profile_name = string.gsub(UTIL:GetVehicleProfileName(), ' ', '_')
				if profile_name ~= nil then
					SetResourceKvpInt(save_prefix .. 'profile_'.. profile_name .. '_vcf_id', VCF_index)
					UTIL:Print(string.format('^4LVC ^5STORAGE:  ^7saving ^5%s^7 using VCF_ID #^5%s^7 - ^5%s', profile_name, VCF_index, vcf_name))
				else
					HUD:ShowNotification('~b~LVC: ~r~SAVE ERROR~s~: profile_name after gsub is nil.', true)
				end
			else
				HUD:ShowNotification('~b~LVC: ~r~SAVE ERROR~s~: UTIL:GetCurrentVCFName() returned nil.', true)
			end

			--[[Tone Names]]
			if custom_tone_names then
				local siren_tone_names = { }
				for i, siren_pkg in pairs(SIRENS) do
					table.insert(siren_tone_names, siren_pkg.Name)
				end		
				
				local horn_tone_names = { }
				for i, horn_pkg in pairs(HORNS) do
					table.insert(horn_tone_names, horn_pkg.Name)
				end
				local tone_names = {horns = horn_tone_names, sirens = siren_tone_names }
				SetResourceKvp(save_prefix .. 'vcf_'.. vcf_name .. '_tone_names', json.encode(tone_names))
				UTIL:Print('^4LVC ^5STORAGE:  ^7saved custom tone names.')		
			end
			
			--[[tone_options]]
			if MENU.menu_main_siren_settings and MENU.custom_tone_options then
				local tone_options = { }
				for i, siren_pkg in pairs(SIRENS) do
					table.insert(tone_options, siren_pkg.Option)
				end
				SetResourceKvp(save_prefix .. 'vcf_'.. vcf_name .. '_tone_options', json.encode(tone_options))
				UTIL:Print('^4LVC ^5STORAGE:  ^7saved custom tone options.')		
			end

			--[[LVC, AUDIO table]]
			local vcf_options = { 
				peer_override 				= MCTRL:GetOverridePeerState(),
				siren_mode	 				= MCTRL:GetSirenMode(),
				rumbler_duration	 		= MCTRL:GetRumblerDurationIndex(),
				rumbler_enabled 			= LVC.rumbler_enabled,
				airhorn_intrp 				= LVC.airhorn_intrp,
				reset_standby 				= LVC.reset_standby,
				primary_manual 				= LVC.primary_manual,
				secondary_manual 			= LVC.secondary_manual,
				auxiliary 					= LVC.auxiliary,
				park_kill					= LVC.park_kill,
				radio 						= AUDIO.radio,
				scheme_index 				= AUDIO.scheme_index,
				airhorn_sfx 				= AUDIO.airhorn_sfx,
				manual_sfx 					= AUDIO.manual_sfx,
				activity_reminder_index 	= AUDIO:GetActivityReminderIndex(),
				on_volume 					= AUDIO.on_volume,
				off_volume 					= AUDIO.off_volume,
				upgrade_volume 				= AUDIO.upgrade_volume,
				downgrade_volume 			= AUDIO.downgrade_volume,
				activity_reminder_volume 	= AUDIO.activity_reminder_volume,
				hazards_volume 				= AUDIO.hazards_volume,
				lock_volume 				= AUDIO.lock_volume,
				lock_reminder_volume 		= AUDIO.lock_reminder_volume,
			}
			SetResourceKvp(save_prefix .. 'vcf_'.. vcf_name .. '!', json.encode(vcf_options))
			UTIL:Print('^4LVC ^5STORAGE:  ^7saved VCF options.')		
		else
			HUD:ShowNotification('~b~LVC: ~r~SAVE ERROR~s~: vcf_name after gsub is nil.', true)
		end
	else
		HUD:ShowNotification('~b~LVC: ~r~SAVE ERROR~s~: UTIL:GetCurrentVCFName() returned nil.', true)
	end
	UTIL:Print('^4LVC ^5STORAGE: ^7Finished Saving Settings...')
end

------------------------------------------------
--[[Loads all KVP values.]]
function STORAGE:LoadSettings(skip_vcf_id)	
	local skip_vcf_id = skip_vcf_id or false
	UTIL:Print('^4LVC ^5STORAGE: ^7Loading Settings...', true)
	local comp_version = GetResourceMetadata(GetCurrentResourceName(), 'compatible', 0)
	local save_version = GetResourceKvpString(save_prefix .. 'save_version')
	local incompatible = IsNewerVersion(comp_version, save_version) == 'older'

	--Is save present if so what version
	if incompatible then
		AddTextEntry('lvc_mismatch_version','~y~~h~Warning:~h~ ~s~Luxart Vehicle Control Save Version Mismatch.\n~b~Compatible Version: ' .. comp_version .. '\n~o~Save Version: ' .. save_version .. '~s~\nYou may experience issues, to prevent this message from appearing verify settings and resave.')
		SetNotificationTextEntry('lvc_mismatch_version')
		DrawNotification(false, true)
	end
	
	--[[HUD LOADING]]
	local hud_save_data = GetResourceKvpString(save_prefix..'hud_data')
	if hud_save_data ~= nil then
		hud_save_data = json.decode(hud_save_data)
		--Permission check
		if MENU.menu_hud_settings then
			if MENU.toggle_hud and hud_save_data['hud_enabled'] ~= nil then
				HUD:SetHudState(hud_save_data['hud_enabled'])
			end
			if MENU.custom_backlight_mode and hud_save_data['hud_backlight_mode'] ~= nil then
				HUD:SetHudBacklightMode(hud_save_data['hud_backlight_mode'])
			end
			HUD:SetHudScale(hud_save_data['hud_scale'])
			HUD:SetHudPosition(hud_save_data['hud_pos'])
		end
		UTIL:Print('^4LVC ^5STORAGE:  ^7loaded HUD data.')		
	end
	
	if save_version ~= nil then
		if UTIL:GetVehicleProfileName() ~= nil then
			local profile_name = string.gsub(UTIL:GetVehicleProfileName(), ' ', '_')
			
			if profile_name ~= nil then
				local vcf_id = GetResourceKvpInt(save_prefix .. 'profile_'.. profile_name .. '_vcf_id')
				local vcf_name = UTIL:GetCurrentVCFName()				
				UTIL:Print(string.format('^4LVC ^5STORAGE:  ^7loading VCF ^5%s^7', vcf_name), true)
				--[[VCF found and approved continue loading]]
				local proposed_VCF_index = UTIL:IndexOf(UTIL:GetApprovedVCFIds(), vcf_id)
				if proposed_VCF_index ~= nil then
					if not skip_vcf_id then
						VCF_ID = vcf_id
						VCF_index = proposed_VCF_index
						vcf_name = UTIL:GetCurrentVCFName()
						UTIL:Print(string.format('^4LVC ^5STORAGE:  ^7VCF changed to ^5%s^7', vcf_name), true)
						UTIL:Print(string.format('^4LVC ^5STORAGE:  ^7loading VCF ^5%s^7', vcf_name), true)
						UTIL:UpdateCurrentVCFData(veh, true)
					end
					
					--[[tone names]]
					local tone_names = GetResourceKvpString(save_prefix .. 'vcf_'.. vcf_name .. '_tone_names')
					if tone_names ~= nil then
						tone_names = json.decode(tone_names)
						--Iterate through sirens subtable 
						for i, name in pairs(tone_names.sirens) do
							if VCFs[VCF_ID].SIRENS[i] ~= nil then
								VCFs[VCF_ID].SIRENS[i].Name = name
								SIRENS[i].Name = name
							end
						end						
						--Iterate through horns subtable 
						for i, name in pairs(tone_names.horns) do
							if VCFs[VCF_ID].HORNS[i] ~= nil then
								VCFs[VCF_ID].HORNS[i].Name = name
								HORNS[i].Name = name
							end
						end
						UTIL:Print('^4LVC ^5STORAGE:  ^7loaded custom tone names.', true)
					end
				else
					UTIL:Print('^4LVC ^5STORAGE: ^3Saved vcf_id not found in approved vcfids, assignements have likely changed.', true)
				end
					
				--[[LVC, AUDIO, table]]
				local vcf_options = GetResourceKvpString(save_prefix .. 'vcf_'.. vcf_name .. '!')
				if vcf_options ~= nil then
					vcf_options = json.decode(vcf_options)
					if MENU.toggle_peer_override then
						MCTRL:SetOverridePeerState(vcf_options.peer_override)
					end		
					if MENU.toggle_local_override then
						MCTRL:SetSirenMode(vcf_options.siren_mode)
					end		
					if MENU.menu_rumbler_options then
						LVC.rumbler_enabled = vcf_options.rumbler_enabled
					end
					if MENU.custom_rumbler_duration then
						MCTRL:SetRumblerDurationIndex(vcf_options.rumbler_duration)
					end
					if MENU.toggle_airhorn_intrp then
						LVC.airhorn_intrp = vcf_options.airhorn_intrp
					end		
					if MENU.toggle_reset_standby then
						LVC.reset_standby = vcf_options.reset_standby
					end		
					if MENU.custom_manual then
						LVC.primary_manual = vcf_options.primary_manual
						LVC.secondary_manual = vcf_options.secondary_manual
					end		
					if MENU.custom_auxiliary then
						LVC.auxiliary = vcf_options.auxiliary
					end		
					if MENU.toggle_park_kill then
						LVC.park_kill = vcf_options.park_kill
					end	
					if MENU.menu_audio_settings then
						if MENU.toggle_radio then
							AUDIO.radio = vcf_options.radio
						end
						if MENU.custom_scheme then
							AUDIO.scheme_index = vcf_options.scheme_index
						end			
						if MENU.toggle_clicks then
							AUDIO.airhorn_sfx = vcf_options.airhorn_sfx
							AUDIO.manual_sfx = vcf_options.manual_sfx
						end
						if MENU.custom_activity_reminder then
							AUDIO:SetActivityReminderIndex(vcf_options.activity_reminder_index)
						end
						AUDIO.on_volume 				= vcf_options.on_volume
						AUDIO.off_volume 				= vcf_options.off_volume
						AUDIO.upgrade_volume 			= vcf_options.upgrade_volume
						AUDIO.downgrade_volume 			= vcf_options.downgrade_volume
						AUDIO.activity_reminder_volume 	= vcf_options.activity_reminder_volume
						AUDIO.hazards_volume 			= vcf_options.hazards_volume
						AUDIO.lock_volume 				= vcf_options.lock_volume
						AUDIO.lock_reminder_volume 		= vcf_options.lock_reminder_volume
					end
				end
			else
				UTIL:Print('^4LVC ^5STORAGE: ^1vehicle profile name nil after gsub.', true)
			end
		else
			UTIL:Print('^4LVC ^5STORAGE: ^1vehicle profile name nil.', true)
		end
	else
		UTIL:Print('^4LVC ^5STORAGE: ^3No profile save present.', true)
	end
	UTIL:Print('^4LVC ^5STORAGE: ^7Finished Loading Settings...', true)
end

------------------------------------------------
--[[Resets all KVP/menu values to their default.]]
function STORAGE:ResetSettings()
	UTIL:Print('^4LVC ^5STORAGE: ^7Resetting Settings...')

	--Storage State
	custom_tone_names 		= false
	profiles = { }
	--STORAGE:FindSavedProfiles()

	local VCFs_backup_tbl = json.decode(VCFs_backup)
	VCFs[VCF_ID] = VCFs_backup_tbl[("%s").format(VCF_ID)]
	MCTRL:SetSirenMode(1)
	MCTRL:SetOverridePeerState(false)
	UTIL:UpdateCurrentVCFData(veh, true)

	UTIL:Print('^4LVC ^5STORAGE: ^7Finished Resetting Settings...')
end

------------------------------------------------
--[[Find all profile names of all saved KVP.]]
function STORAGE:FindSavedProfiles()
	local handle = StartFindKvp(save_prefix..'profile_');
	local key = FindKvp(handle)
	while key ~= nil do
		if string.match(key, '(.*)!$') then
			local saved_profile_name = string.match(key, save_prefix..'profile_(.*)!$')
			
			--Duplicate checking
			local found = false
			for _, profile_name in ipairs(profiles) do
				if profile_name == saved_profile_name then
					found = true
				end
			end
			
			if not found then
				table.insert(profiles, saved_profile_name)
			end
		end
		key = FindKvp(handle)
		Wait(0)
	end
end

function STORAGE:GetSavedProfiles()
	return profiles
end
------------------------------------------------
--[[Setter for JSON string backup of SIRENS table in case of reset since we modify SIREN table directly.]]
function STORAGE:SetBackupTable()
	VCFs_backup = json.encode(VCFs)
end

--[[Setter for SIRENS table using backup string of table.]]
function STORAGE:RestoreBackupTable()
	SIRENS = json.decode(SIRENS_backup_string)
end

--[[Setter for bool that is used in saving to determine if tone strings have been modified.]]
function STORAGE:SetCustomToneStrings(toggle)
	custom_tone_names = toggle
end

------------------------------------------------
--HELPER FUNCTIONS for main siren settings saving:end
--Compare Version Strings: Is version newer than test_version
IsNewerVersion = function(version, test_version)
	if version == nil or test_version == nil then
		return 'unknown'
	end

	if type(version) == 'string' then
		version = semver(version)
	end
	if type(test_version) == 'string' then
		test_version = semver(test_version)
	end

	if version > test_version then
		return 'older'
	elseif version < test_version then
		return 'newer'
	elseif version == test_version then
		return 'equal'
	end
end

---------------------------------------------------------------------
--[[Callback for Server -> Client version update.]]
RegisterNetEvent('lvc:SendRepoVersion_c')
AddEventHandler('lvc:SendRepoVersion_c', function(version)
	repo_version = version
end)

RegisterNetEvent('lvc:SendVCFs_c')
AddEventHandler('lvc:SendVCFs_c', function(VCFs_table)
	VCFs = VCFs_table
	VCFs.set = true
	STORAGE:SetBackupTable()
	-- Preload as many banks as we can up to 7, reduce wait time on initial siren activation.
	for _, VCF in pairs(VCFs) do
		if type(VCF) == 'table' then
			for _, tone in pairs(VCF.HORNS) do
				ReqAudioBank(tone.Bank)
				ReqAudioBank(tone.RumblerBank)
			end		
			for _, tone in pairs(VCF.SIRENS) do
				ReqAudioBank(tone.Bank)
				ReqAudioBank(tone.RumblerBank)
			end
		end
	end
end)