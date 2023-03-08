--[[
-------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_lvc.lua
PURPOSE: Core Functionality and User Input
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
--GLOBAL VARIABLES used in cl_ragemenu, UTILs, and plug-ins.
--	GENERAL VARIABLES
LVC = { }
key_lock = false
playerped = nil
last_veh = nil
veh = nil
trailer = nil
player_is_emerg_driver = false
debug_mode = false

state_indic = {}
state_lxsiren = {}
state_auxiliary = {}
state_airmanu = {}
state_mode = {}

actv_manu = false
actv_horn = false

actv_lxsrnmute_temp = false

--LOCAL VARIABLES
--	Cached
local ipairs = ipairs
local pairs = pairs
local table = table
local string = string

local main_thread_running = true
local count_broadcast_timer = 0
local delay_broadcast_timer = 500

local count_sndclean_timer = 0
local delay_sndclean_timer = 400

local actv_ind_timer = false
local count_ind_timer = 0
local delay_ind_timer = 180

local srntone_temp = 0
local dsrn_mute = true

local ind_state_o = 0
local ind_state_l = 1
local ind_state_r = 2
local ind_state_h = 3

local snd_lxsiren = {}
local snd_auxilary = {}
local snd_airmanu = {}

local loaded_banks = {}

--	Local fn forward declaration
local RegisterKeyMaps, MakeOrdinal

----------------THREADED FUNCTIONS----------------
--[[ Configuration checking: conflicting resource, conflicting resource, community ID. 
	 player_is_emerg_driver: loop updating vehicle, trailer, checking seat and disabling controls.]]
CreateThread(function()
	if not UTIL:IsValidEnviroment() then
		return
	end
	
	Wait(500)
	while true do
		playerped = PlayerPedId()
		--IS IN VEHICLE
		player_is_emerg_driver = false
		if IsPedInAnyVehicle(playerped, false) then
			veh = GetVehiclePedIsUsing(playerped)
			_, trailer = GetVehicleTrailerVehicle(veh)
			--IS DRIVER
			if GetPedInVehicleSeat(veh, -1) == playerped then
				--IS EMERGENCY VEHICLE
				if GetVehicleClass(veh) == 18 then
					player_is_emerg_driver = true
					DisableControlAction(0, 80, true) -- INPUT_VEH_CIN_CAM
					DisableControlAction(0, 86, true) -- INPUT_VEH_HORN
					DisableControlAction(0, 172, true) -- INPUT_CELLPHONE_UP
				end
			end
		end
		Wait(0)
	end
end)

------ON VEHICLE EXIT EVENT TRIGGER------
CreateThread(function()
	while true do
		if player_is_emerg_driver then
			while playerped ~= nil and veh ~= nil do
				if GetIsTaskActive(playerped, 2) then
					TriggerEvent('lvc:onVehicleExit')
					Wait(1000)
				end
				Wait(0)
			end
		end
		Wait(1000)
	end
end)

------VEHICLE CHANGE DETECTION AND TRIGGER------
CreateThread(function()
	while true do
		if last_veh == nil and IsPedInAnyVehicle(playerped, false) then
			TriggerEvent('lvc:onVehicleChange')
		else
			if last_veh ~= veh then
				TriggerEvent('lvc:onVehicleChange')
			end
		end
		Wait(1000)
	end
end)

------------REGISTERED VEHICLE EVENTS------------
--Kill siren on Exit
RegisterNetEvent('lvc:onVehicleExit')
AddEventHandler('lvc:onVehicleExit', function()
	if LVC.park_kill then
		if not LVC.reset_standby and state_lxsiren[veh] ~= 0 then
			UTIL:SetToneByID('MAIN_MEM', state_lxsiren[veh])
		end
		SetLxSirenStateForVeh(veh, 0)
		SetAuxiliaryStateForVeh(veh, 0)
		SetAirManuStateForVeh(veh, 0)
		HUD:SetItemState('siren', false)
		HUD:SetItemState('horn', false)
		count_broadcast_timer = delay_broadcast_timer
	end
end)

--[[On vehicle change, update last_veh to prevent future update, set the initial VCF_Index back to 1 and load VCF data for that index, then load settings ontop of defaults.]]
RegisterNetEvent('lvc:onVehicleChange')
AddEventHandler('lvc:onVehicleChange', function()
	last_veh = veh
	VCF_index = 1
	if player_is_emerg_driver then
		UTIL:UpdateCurrentVCFData(veh, true)
		STORAGE:LoadSettings()
		RegisterKeyMaps()
		HUD:RefreshHudItemStates()
		AUDIO:SetRadioState('OFF')
	end
end)


--------------REGISTERED COMMANDS---------------
--Toggle debug mode
RegisterCommand('lvcdebug', function(source, args)
	if player_is_emerg_driver then
		debug_mode = not debug_mode
		UTIL:Print(("^4LVC ^5VCF Data:^7 %s"):format(json.encode(UTIL:GetApprovedVCFs())))
		HUD:ShowNotification(('~y~~h~Info:~h~ ~s~debug mode set to %s. See console.'):format(debug_mode), true)
		UTIL:Print(('^3LVC Info: debug mode set to %s temporarily. Debug_mode resets after resource restart unless set in fxmanifest. Make sure to run "refresh" to see fxmanifest changes.'):format(debug_mode), true)
		if debug_mode then
			TriggerEvent('lvc:onVehicleChange')
		end
	else
		HUD:ShowNotification('~b~~h~LVC~h~~y~ ~h~Info:~h~~s~ vehicle not found, please enter a vehicle first.', true)
		UTIL:Print('^3LVC Info: debug mode not set. Please enter a vehicle and run the command again.', true)
	end
end)
TriggerEvent('chat:addSuggestion', '/lvcdebug', 'Toggle Luxart Vehicle Control Debug Mode.')

--Toggle control lock command
RegisterCommand('lvclock', function(source, args)
	if player_is_emerg_driver then
		key_lock = not key_lock
		AUDIO:Play('Key_Lock', AUDIO.lock_volume, true)
		HUD:SetItemState('lock', key_lock)
		--if HUD is visible do not show notification
		if not HUD:GetHudState() then
			if key_lock then
				HUD:ShowNotification('Siren Control Box: ~r~Locked', true)
			else
				HUD:ShowNotification('Siren Control Box: ~g~Unlocked', true)
			end
		end
	end
end)
RegisterKeyMapping('lvclock', 'LVC: Lock out controls', 'keyboard', SETTINGS.lockout_default_hotkey)
TriggerEvent('chat:addSuggestion', '/lvclock', 'Toggle Luxart Vehicle Control Keybinding Lockout.')

--Crash recovery command
RegisterCommand('lvcrecovercrash', function()
	if not main_thread_running then
		local timer = 3000
		local blocked = false
		CreateThread(function()
			while timer > 0 do
				timer = timer - 1
				if main_thread_running then
					blocked = true
				end
				Wait(1)
			end
		end)
		
		if not blocked then
			test = { test2 = { test3 = 3 } }
			UTIL:Print("^3LVC Development Log: attempting to recover from a crash... This may not work. Please make a bug report with log file.", true)
			HUD:ShowNotification("~r~LVC Log~w~: ~y~please make a bug report with log file~w~.", true)
			HUD:ShowNotification("~r~LVC Log~w~: attempting to recover from a crash...", true)
			CreateThread(MainThread)
			return
		end
	end
	UTIL:Print("^3LVC Development Log: unable to recover, appears to be running. ~y~Please make a bug report with log file~w~.", true)
	HUD:ShowNotification("~r~LVC Log~w~: unable to recover, running. ~y~Please make a bug report with log file~w~.", true)
end)
TriggerEvent('chat:addSuggestion', '/lvcrecovercrash', 'Attempts to recover LVC after a crash.')
------------------------------------------------
--Dynamically Run RegisterCommand and KeyMapping functions for all 14 possible sirens
--Then at runtime 'slide' all sirens down removing any restricted sirens.
RegisterKeyMaps = function()
	for tone, _ in ipairs(SIRENS) do
		local command = '_lvc_siren_' .. tone
		local description = 'LVC Siren: ' .. MakeOrdinal(tone)

		RegisterCommand(command, function(source, args)
			if player_is_emerg_driver and not key_lock then
				if IsVehicleSirenOn(veh) then
					local tone_option = UTIL:GetToneOption(tone)
					if tone_option ~= nil then
						if tone_option == 1 or tone_option == 3 then
							if ( state_lxsiren[veh] ~= tone or state_lxsiren[veh] == 0 ) then
								HUD:SetItemState('siren', true)
								AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
								SetLxSirenStateForVeh(veh, tone)
								count_broadcast_timer = delay_broadcast_timer
							else
								if state_auxiliary[veh] == 0 then
									HUD:SetItemState('siren', false)
								end
								AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
								SetLxSirenStateForVeh(veh, 0)
								count_broadcast_timer = delay_broadcast_timer
							end
						end
					end
				end
			end
		end)

		--CHANGE BELOW if you'd like to change which keys are used for example NUMROW1 through 0
		if tone < 11 and SETTINGS.main_siren_set_register_keys_set_defaults then
			RegisterKeyMapping(command, description, 'keyboard', tone)
		elseif tone == 11 and SETTINGS.main_siren_set_register_keys_set_defaults then
			RegisterKeyMapping(command, description, 'keyboard', '0')
		else
			RegisterKeyMapping(command, description, 'keyboard', '')
		end
	end
end

--Make number into ordinal number, used for FiveM RegisterKeys
MakeOrdinal = function(number)
	local sufixes = { 'th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th' }
	local mod = (number % 100)
	if mod == 11 or mod == 12 or mod == 13 then
		return number .. 'th'
	else
		return number..sufixes[(number % 10) + 1]
	end
end

--On resource start/restart
CreateThread(function()
	debug_mode = GetResourceMetadata(GetCurrentResourceName(), 'debug_mode', 0) == 'true'
	SetNuiFocus( false )
	UTIL:FixOversizeKeys(SETTINGS.VCF_Assignments)

	Wait(100)
	CreateThread(MainThread)
	if not SETTINGS.police_scanner then
		SetAudioFlag('PoliceScannerDisabled', true)
	end
end)			

------------------------------------------------
-------------------FUNCTIONS--------------------
------------------------------------------------
--Request new script audio bank, unloading the oldest (FIFO) down to 7 due to limitations.
function ReqAudioBank(bank)
	if bank == nil or bank == '' then
		return
	end
	
	while #loaded_banks > 6 do
		ReleaseNamedScriptAudioBank(loaded_banks[7])
		ReleaseScriptAudioBank()
		table.remove(loaded_banks, 7)
	end
	for i,v in ipairs(loaded_banks) do
		if v == bank then
			return
		end
	end
	
	table.insert(loaded_banks, 1, bank)
	--reformat bank strings for users who format string with XX\\XX due to XML parsing
	local _, count = string.gsub(bank, "\\", "")
	if count > 1 then
		local lead, trail = string.match(bank, "(.*)%\\\\(.*)")
		bank = lead.."\\"..trail
	end
	RequestScriptAudioBank(bank, false)
	UTIL:Print(('^4LVC ^5AUDIOBANKS: ^7 Requesting "%s"'):format(bank))
	Wait(50)
end

---------------------------------------------------------------------
--	Clear nonexistant or destroyed entities whos sound ID (snd_XXX) is still present.
local function CleanupSounds()
	if count_sndclean_timer > delay_sndclean_timer then
		count_sndclean_timer = 0
		for k, v in pairs(state_lxsiren) do
			if v > 0 then
				if not DoesEntityExist(k) or IsEntityDead(k) then
					if snd_lxsiren[k] ~= nil then
						StopSound(snd_lxsiren[k])
						ReleaseSoundId(snd_lxsiren[k])
						snd_lxsiren[k] = nil
						state_lxsiren[k] = nil
					end
				end
			end
		end
		for k, v in pairs(state_auxiliary) do
			if v > 0 then
				if not DoesEntityExist(k) or IsEntityDead(k) then
					if snd_auxilary[k] ~= nil then
						StopSound(snd_auxilary[k])
						ReleaseSoundId(snd_auxilary[k])
						snd_auxilary[k] = nil
						state_auxiliary[k] = nil
					end
				end
			end
		end
		for k, v in pairs(state_airmanu) do
			if v == true then
				if not DoesEntityExist(k) or IsEntityDead(k) or IsVehicleSeatFree(k, -1) then
					if snd_airmanu[k] ~= nil then
						StopSound(snd_airmanu[k])
						ReleaseSoundId(snd_airmanu[k])
						snd_airmanu[k] = nil
						state_airmanu[k] = nil
					end
				end
			end
		end
	else
		count_sndclean_timer = count_sndclean_timer + 1
	end
end
---------------------------------------------------------------------
function TogIndicStateForVeh(veh, newstate)
	if DoesEntityExist(veh) and not IsEntityDead(veh) then
		if newstate == ind_state_o then
			SetVehicleIndicatorLights(veh, 0, false) -- R
			SetVehicleIndicatorLights(veh, 1, false) -- L
		elseif newstate == ind_state_l then
			SetVehicleIndicatorLights(veh, 0, false) -- R
			SetVehicleIndicatorLights(veh, 1, true) -- L
		elseif newstate == ind_state_r then
			SetVehicleIndicatorLights(veh, 0, true) -- R
			SetVehicleIndicatorLights(veh, 1, false) -- L
		elseif newstate == ind_state_h then
			SetVehicleIndicatorLights(veh, 0, true) -- R
			SetVehicleIndicatorLights(veh, 1, true) -- L
		end
		state_indic[veh] = newstate
	end
end

---------------------------------------------------------------------
function TogMuteDfltSrnForVeh(veh, toggle)
	if DoesEntityExist(veh) and not IsEntityDead(veh) then
		DisableVehicleImpactExplosionActivation(veh, toggle)
	end
end

---------------------------------------------------------------------
function SetLxSirenStateForVeh(veh, newstate, vcfid, mode_id)
	-- optional argument vcfid, only passed from peers, own client will use VCF_ID.
	local vcfid = vcfid or VCF_ID
	if vcfid == nil or VCFs[vcfid] == nil or VCFs[vcfid].SIRENS == nil then
		UTIL:Print(string.format('^3LVC Development Log: vcfid: %s VCF_ID: %s VCFs: %s', vcfid, VCF_ID, json.encode(VCFs)), true)
	end
	local sirens = VCFs[vcfid].SIRENS
	-- mode_id from peer, or current client mode see cl_modes.lua for ENUM.
	local mode_id = mode_id or MCTRL:GetSirenMode()
	--	mode string, ref, and bank dereferenced from mode_id
	local mode = MCTRL:GetSirenModeTable(mode_id)

	if DoesEntityExist(veh) and not IsEntityDead(veh) then
		if newstate ~= state_lxsiren[veh] or mode_id ~= state_mode[veh] and newstate ~= nil then
			-- stop Siren sound
			if snd_lxsiren[veh] ~= nil then
				StopSound(snd_lxsiren[veh])
				ReleaseSoundId(snd_lxsiren[veh])
				snd_lxsiren[veh] = nil
			end
			if newstate ~= 0 then							
				if mode.bank ~= nil and sirens[newstate][mode.bank] ~= nil then
					ReqAudioBank(sirens[newstate][mode.bank])
				end
				snd_lxsiren[veh] = GetSoundId()
				-- if siren string is not set in VCF fallback on normal mode
				if sirens[newstate][mode.string] == "" then
					mode = MCTRL:GetSirenModeTable(MCTRL.NORMAL)
				end
				PlaySoundFromEntity(snd_lxsiren[veh], sirens[newstate][mode.string], veh, sirens[newstate][mode.ref], 0, 0)
			else
				if MCTRL:GetSirenMode() == MCTRL.RUMBLER then
					MCTRL:SetTempRumblerMode(false, true)
				end
			end
			state_lxsiren[veh] 	= newstate
			state_mode[veh]		= mode_id
		end
	end
end

---------------------------------------------------------------------
function SetAuxiliaryStateForVeh(veh, newstate, vcfid, mode_id)
	local vcfid = vcfid or VCF_ID
	if vcfid == nil or VCFs[vcfid] == nil or VCFs[vcfid].SIRENS == nil then
		UTIL:Print(string.format('^3LVC Development Log: vcfid: %s VCF_ID: %s VCFs: %s', vcfid, VCF_ID, json.encode(VCFs)), true)
	end
	local sirens = VCFs[vcfid].SIRENS
	local mode_id = mode_id or MCTRL:GetSirenMode()
	local mode = MCTRL:GetSirenModeTable(mode_id)

	if DoesEntityExist(veh) and not IsEntityDead(veh) then
		if newstate ~= state_auxiliary[veh] or mode_id ~= state_mode[veh] and newstate ~= nil then
			if snd_auxilary[veh] ~= nil then
				StopSound(snd_auxilary[veh])
				ReleaseSoundId(snd_auxilary[veh])
				snd_auxilary[veh] = nil
			end
			if newstate ~= 0 then
				if mode.bank ~= nil and sirens[newstate][mode.bank] ~= nil then
					ReqAudioBank(sirens[newstate][mode.bank])
				end
				snd_auxilary[veh] = GetSoundId()
				if sirens[newstate][mode.string] == "" then
					mode = MCTRL:GetSirenModeTable(MCTRL.NORMAL)
				end
				PlaySoundFromEntity(snd_auxilary[veh], sirens[newstate][mode.string], veh, sirens[newstate][mode.ref], 0, 0)
			end
			state_auxiliary[veh] = newstate
			state_mode[veh] 	 = newstate
		end
	end
end

---------------------------------------------------------------------
function SetAirManuStateForVeh(veh, newstate, vcfid, horn, mode_id)
	local vcfid = vcfid or VCF_ID
	if vcfid == nil or VCFs[vcfid] == nil or VCFs[vcfid].SIRENS == nil or VCFs[vcfid].HORNS == nil then
		UTIL:Print(string.format('^3LVC Development Log: vcfid: %s VCF_ID: %s VCFs: %s', vcfid, VCF_ID, json.encode(VCFs)), true)
	end
	local horn = horn or false
	local mode_id = mode_id or MCTRL:GetSirenMode()
	local mode = MCTRL:GetSirenModeTable(mode_id)

	local sirens = VCFs[vcfid].SIRENS
	local horns = nil
	if horn then
		horns = VCFs[vcfid].HORNS
	end
	
	if DoesEntityExist(veh) and not IsEntityDead(veh) then
		if newstate ~= state_airmanu[veh] and newstate ~= nil then
			if snd_airmanu[veh] ~= nil then
				StopSound(snd_airmanu[veh])
				ReleaseSoundId(snd_airmanu[veh])
				snd_airmanu[veh] = nil
			end
			if newstate ~= 0 then
				snd_airmanu[veh] = GetSoundId()
				if horn then
					if mode.bank ~= nil and horns[newstate][mode.bank] ~= nil then
						ReqAudioBank(horns[newstate][mode.bank])
					end
					if horns[newstate][mode.string] == "" then
						mode = MCTRL:GetSirenModeTable(MCTRL.NORMAL)
					end		
					PlaySoundFromEntity(snd_airmanu[veh], horns[newstate][mode.string], veh, horns[newstate][mode.ref], 0, 0)
				else
					if mode.bank ~= nil and sirens[newstate][mode.bank] ~= nil then
						ReqAudioBank(sirens[newstate][mode.bank])
					end
					if sirens[newstate][mode.string] == "" then
						mode = MCTRL:GetSirenModeTable(MCTRL.NORMAL)
					end						
					PlaySoundFromEntity(snd_airmanu[veh], sirens[newstate][mode.string], veh, sirens[newstate][mode.ref], 0, 0)
				end
			end
			state_airmanu[veh] = newstate
		end
	end
end

------------------------------------------------
----------------EVENT HANDLERS------------------
------------------------------------------------
RegisterNetEvent('lvc:TogIndicState_c')
AddEventHandler('lvc:TogIndicState_c', function(sender, newstate)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= playerped then
			if IsPedInAnyVehicle(ped_s, false) then
				local veh = GetVehiclePedIsUsing(ped_s)
				TogIndicStateForVeh(veh, newstate)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:TogDfltSrnMuted_c')
AddEventHandler('lvc:TogDfltSrnMuted_c', function(sender, toggle)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= playerped then
			if IsPedInAnyVehicle(ped_s, false) then
				local veh = GetVehiclePedIsUsing(ped_s)
				TogMuteDfltSrnForVeh(veh, toggle)
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetLxSirenState_c')
AddEventHandler('lvc:SetLxSirenState_c', function(sender, newstate, vcfid, mode)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= playerped then
			if IsPedInAnyVehicle(ped_s, false) then
				local veh = GetVehiclePedIsUsing(ped_s)
				-- If the client is using local-override, switch to correct mode.
				if mode == 3 then
					mode = 1 
				end
				
				--Criteria for override enabled, same faction (LE,Fire,etc.) and not 0
				if MCTRL:GetOverridePeerState() and VCFs[vcfid].LVC.faction == LVC.faction and newstate ~= 0 then
					if MCTRL:GetSirenMode() == 3 then
						mode = 3
					end
					--Get peers siren have an assigned fallback position, if assigned
					local fallback = VCFs[vcfid].SIRENS[newstate].Fallback or nil
					
					--Use parallel position if available
					if SIRENS[newstate] ~= nil then
						UTIL:Print(("using parallel %s, %s, %s").format(newstate, VCF_ID, mode))
						SetLxSirenStateForVeh(veh, newstate, VCF_ID, mode)
					--parallel not found, is fallback assigned, otherwise play peers 
					elseif SIRENS[fallback] ~= nil then
						UTIL:Print('using fallback')
						SetLxSirenStateForVeh(veh, fallback, VCF_ID, mode)
					else
						UTIL:Print('using peers all fail')
						SetLxSirenStateForVeh(veh, newstate, vcfid, mode)
					end
				else
					UTIL:Print('using peers cond not met')
					SetLxSirenStateForVeh(veh, newstate, vcfid, mode)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetAuxilaryState_c')
AddEventHandler('lvc:SetAuxilaryState_c', function(sender, newstate, vcfid, mode)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= playerped then
			if IsPedInAnyVehicle(ped_s, false) then
				local veh = GetVehiclePedIsUsing(ped_s)
				
				if mode == 3 then
					mode = 1 
				end
				if MCTRL:GetOverridePeerState() and VCFs[vcfid].LVC.faction == LVC.faction and newstate ~= 0 then
					local fallback = VCFs[vcfid].SIRENS[newstate].Fallback
					if SIRENS[newstate] ~= nil then
						SetAuxiliaryStateForVeh(veh, newstate, VCF_ID, mode)
					elseif SIRENS[fallback] ~= nil then
						SetAuxiliaryStateForVeh(veh, fallback, VCF_ID, mode)
					else
						SetAuxiliaryStateForVeh(veh, newstate, vcfid, mode)
					end
				else
					SetAuxiliaryStateForVeh(veh, newstate, vcfid, mode)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
RegisterNetEvent('lvc:SetAirManuState_c')
AddEventHandler('lvc:SetAirManuState_c', function(sender, newstate, vcfid, using_horn, mode)
	local player_s = GetPlayerFromServerId(sender)
	local ped_s = GetPlayerPed(player_s)
	if DoesEntityExist(ped_s) and not IsEntityDead(ped_s) then
		if ped_s ~= playerped then
			if IsPedInAnyVehicle(ped_s, false) then
				local veh = GetVehiclePedIsUsing(ped_s)
				
				if mode == 3 then
					mode = 1 
				end
				local fallback = nil
				if MCTRL:GetOverridePeerState() and VCFs[vcfid].LVC.faction == LVC.faction and newstate ~= 0 then
					if using_horn then
						fallback = VCFs[vcfid].HORNS[newstate].Fallback or nil
					else
						fallback = VCFs[vcfid].SIRENS[newstate].Fallback or nil
					end
					
					if SIRENS[newstate] ~= nil then
						SetAirManuStateForVeh(veh, newstate, VCF_ID, using_horn, mode)
					elseif fallback ~= nil and (HORNS[fallback] ~= nil or SIRENS[fallback] ~= nil) then
						SetAirManuStateForVeh(veh, fallback, VCF_ID, using_horn, mode)
					else
						SetAirManuStateForVeh(veh, newstate, vcfid, using_horn, mode)
					end
				else
					SetAirManuStateForVeh(veh, newstate, vcfid, using_horn, mode)
				end
			end
		end
	end
end)

---------------------------------------------------------------------
function MainThread()
	-- Load initial data for audio feedback, wait for initial profile data to populate. After this override init profile data with new data onVehicleChange.
	VCF_index = 1
	UTIL:UpdateCurrentVCFData(veh, true)
	while VCF_ID == nil do
		Wait(100)
	end
	
	-- Cached Local Variables
	local SETTINGS = SETTINGS
	local HUD = HUD
	local AUDIO = AUDIO
	local MCTRL = MCTRL
	local UTIL = UTIL
	local STORAGE = STORAGE
	
	while true do
		--	Crash recovery variable, resets to true at end of loop.
		main_thread_running = false
		CleanupSounds()
		DistantCopCarSirens(false)
		----- IS IN VEHICLE -----
		if GetPedInVehicleSeat(veh, -1) == playerped then
			if state_indic[veh] == nil then
				state_indic[veh] = ind_state_o
			end

			-- INDIC AUTO CONTROL
			if actv_ind_timer == true then
				if state_indic[veh] == ind_state_l or state_indic[veh] == ind_state_r then
					if GetEntitySpeed(veh) < 6 then
						count_ind_timer = 0
					else
						if count_ind_timer > delay_ind_timer then
							count_ind_timer = 0
							actv_ind_timer = false
							state_indic[veh] = ind_state_o
							TogIndicStateForVeh(veh, state_indic[veh])
							count_broadcast_timer = delay_broadcast_timer
						else
							count_ind_timer = count_ind_timer + 1
						end
					end
				end
			end


			--- IS EMERG VEHICLE ---
			if player_is_emerg_driver then
				if UpdateOnscreenKeyboard() ~= 0 and not IsEntityDead(veh) then
					--- SET INIT TABLE VALUES ---
					if state_lxsiren[veh] == nil then
						state_lxsiren[veh] = 0
					end
					if state_auxiliary[veh] == nil then
						state_auxiliary[veh] = 0
					end
					if state_airmanu[veh] == nil then
						state_airmanu[veh] = 0
					end
					if state_lxsiren[veh] == nil then
						state_mode[veh] = 1
					end
					TogMuteDfltSrnForVeh(veh, true)

					--- IF LIGHTS ARE OFF TURN OFF SIREN ---
					if not IsVehicleSirenOn(veh) and state_lxsiren[veh] > 0 then
						--	SAVE TONE BEFORE TURNING OFF
						if not LVC.reset_standby then
							LVC.main_mem = state_lxsiren[veh]
						end
						SetLxSirenStateForVeh(veh, 0)
						count_broadcast_timer = delay_broadcast_timer
					end
					if not IsVehicleSirenOn(veh) and state_auxiliary[veh] > 0 then
						SetAuxiliaryStateForVeh(veh, 0)
						count_broadcast_timer = delay_broadcast_timer
					end

					----- CONTROLS -----
					if not IsPauseMenuActive() then
						if not key_lock and not AUDIO.radio_wheel_active then
							------ TOG DFLT SRN LIGHTS ------
							if IsDisabledControlJustReleased(0, 85) then
								if IsVehicleSirenOn(veh) then
									AUDIO:Play('Off', AUDIO.off_volume)
									--	SET NUI IMAGES
									HUD:SetItemState('switch', false)
									HUD:SetItemState('siren', false)
									--	TURN OFF SIRENS (R* LIGHTS)
									SetVehicleSiren(veh, false)
									if trailer ~= nil and trailer ~= 0 then
										SetVehicleSiren(trailer, false)
									end
								else
									AUDIO:Play('On', AUDIO.on_volume) -- On
									--	SET NUI IMAGES
									HUD:SetItemState('switch', true)
									--	TURN OFF SIRENS (R* LIGHTS)
									SetVehicleSiren(veh, true)
									if trailer ~= nil and trailer ~= 0 then
										SetVehicleSiren(trailer, true)
									end
								end
								AUDIO:ResetActivityTimer()
							------ TOG LX SIREN ------
							elseif IsDisabledControlJustReleased(0, 19) then
								if state_lxsiren[veh] == 0 then
									if IsVehicleSirenOn(veh) then
										local new_tone = nil
										AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
										if LVC.reset_standby then
											if MCTRL:GetSirenMode() == MCTRL.RUMBLER then
												MCTRL:SetSirenMode(1)
											end
											new_tone = UTIL:GetNextSirenTone(0, veh, true)
										else
											--	GET THE SAVED TONE VERIFY IT IS APPROVED, AND NOT DISABLED / BUTTON ONLY
											local option = UTIL:GetToneOption(LVC.Main_Mem)
											if option ~= 3 and option ~= 4 then
												new_tone = LVC.Main_Mem
											else
												new_tone = UTIL:GetNextSirenTone(0, veh, true)
											end
										end
										SetLxSirenStateForVeh(veh, new_tone)
										HUD:SetItemState('siren', true)
									end
								else
									AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
									-- ONLY CHANGE NUI STATE IF PWRCALL IS OFF AS WELL
									if state_auxiliary[veh] == 0 then
										HUD:SetItemState('siren', false)
									end
									LVC.Main_Mem = state_lxsiren[veh]
									SetLxSirenStateForVeh(veh, 0)
								end
								AUDIO:ResetActivityTimer()
								count_broadcast_timer = delay_broadcast_timer
							-- AUXILIARY
							elseif IsDisabledControlJustReleased(0, 172) and not IsMenuOpen() then
								if state_auxiliary[veh] == 0 then
									if IsVehicleSirenOn(veh) then
										AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
										HUD:SetItemState('siren', true)
										SetAuxiliaryStateForVeh(veh, LVC.auxiliary)
									end
								else
									AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
									if state_lxsiren[veh] == 0 then
										HUD:SetItemState('siren', false)
									end
									SetAuxiliaryStateForVeh(veh, 0)
								end
								AUDIO:ResetActivityTimer()
								count_broadcast_timer = delay_broadcast_timer
							end
							-- CYCLE LX SRN TONES
							if state_lxsiren[veh] > 0 then
								if IsDisabledControlJustReleased(0, 80) then
									AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
									HUD:SetItemState('horn', false)
									SetLxSirenStateForVeh(veh, UTIL:GetNextSirenTone(state_lxsiren[veh], veh, true))
									count_broadcast_timer = delay_broadcast_timer
								elseif IsDisabledControlPressed(0, 80) then
									HUD:SetItemState('horn', true)	
								end
							end

							-- MANU
							if state_lxsiren[veh] < 1 then
								if IsDisabledControlPressed(0, 80) then
									AUDIO:ResetActivityTimer()
									actv_manu = true
									HUD:SetItemState('siren', true)
								else
									if actv_manu then
										HUD:SetItemState('siren', false)
									end
									actv_manu = false
								end
							else
								if actv_manu then
									HUD:SetItemState('siren', false)
								end
								actv_manu = false
							end

							-- TOG RUMBLER (LSHIFT+E)
							if LVC.rumbler and LVC.rumbler_enabled and IsControlPressed(0, 131) and MCTRL:GetSirenMode() ~= MCTRL.LOCAL then
								if IsDisabledControlJustReleased(0, 86) and state_lxsiren[veh] > 0 then
									MCTRL:SetTempRumblerMode(true)				
								end
							end
							
							-- HORN
							if IsDisabledControlPressed(0, 86) and not (IsControlPressed(0, 131) and LVC.rumbler_enabled) then
								actv_horn = true
								AUDIO:ResetActivityTimer()
								HUD:SetItemState('horn', true)
							else
								if actv_horn or actv_manu then
									HUD:SetItemState('horn', false)
									actv_horn = false
								end
							end	
		 

							--AIRHORN AND MANU BUTTON SFX
							if AUDIO.airhorn_sfx and actv_horn or actv_manu then
								if IsDisabledControlJustPressed(0, 86) then
									AUDIO:Play('Press', AUDIO.upgrade_volume)
								end
								if IsDisabledControlJustReleased(0, 86) then
									AUDIO:Play('Release', AUDIO.upgrade_volume)
								end
							end

							if AUDIO.manual_sfx and state_lxsiren[veh] == 0 then
								if IsDisabledControlJustPressed(0, 80) then
									AUDIO:Play('Press', AUDIO.upgrade_volume)
								end
								if IsDisabledControlJustReleased(0, 80) then
									AUDIO:Play('Release', AUDIO.upgrade_volume)
								end
							end
						elseif not AUDIO.radio_wheel_active then
							if (IsDisabledControlJustReleased(0, 86) or
								IsDisabledControlJustReleased(0, 172) or
								IsDisabledControlJustReleased(0, 19) or
								IsDisabledControlJustReleased(0, 85)) then
									if SETTINGS.locked_press_count % SETTINGS.reminder_rate == 0 then
										AUDIO:Play('Locked_Press', AUDIO.lock_reminder_volume, true) -- lock reminder
										HUD:ShowNotification('~y~~h~Reminder:~h~ ~s~Your siren controller is ~r~locked~s~.', true)
									end
									SETTINGS.locked_press_count = SETTINGS.locked_press_count + 1
							end
						end
					end

					---- ADJUST HORN / MANU STATE ----
					local hmanu_state_new = 0
					if actv_horn == true and actv_manu == false then
						hmanu_state_new = LVC.horn
					elseif actv_horn == false and actv_manu == true then
						hmanu_state_new = LVC.primary_manual
					elseif actv_horn == true and actv_manu == true then
						hmanu_state_new = LVC.secondary_manual
					end

					if LVC.airhorn_intrp then
						if hmanu_state_new == LVC.horn then
							if state_lxsiren[veh] > 0 and actv_lxsrnmute_temp == false then
								srntone_temp = state_lxsiren[veh]
								SetLxSirenStateForVeh(veh, 0)
								actv_lxsrnmute_temp = true
							end
						else
							if actv_lxsrnmute_temp == true then
								SetLxSirenStateForVeh(veh, srntone_temp)
								actv_lxsrnmute_temp = false
							end
						end
					end

					if state_airmanu[veh] ~= hmanu_state_new then
						SetAirManuStateForVeh(veh, hmanu_state_new, VCF_ID, (actv_horn and not actv_manu))
						count_broadcast_timer = delay_broadcast_timer
					end
				end
			else
				-- DISABLE SIREN AUDIO FOR ALL VEHICLES NOT VC_EMERGENCY (VEHICLES.META)
				TogMuteDfltSrnForVeh(veh, true)
			end

			--- IS ANY LAND VEHICLE ---
			if GetVehicleClass(veh) ~= 14 and GetVehicleClass(veh) ~= 15 and GetVehicleClass(veh) ~= 16 and GetVehicleClass(veh) ~= 21 then
				----- CONTROLS -----
				if not IsPauseMenuActive() then
					-- IND L
					if IsDisabledControlJustReleased(0, SETTINGS.left_signal_key) then -- INPUT_VEH_PREV_RADIO_TRACK
						local cstate = state_indic[veh]
						if cstate == ind_state_l then
							state_indic[veh] = ind_state_o
							actv_ind_timer = false
						else
							state_indic[veh] = ind_state_l
							actv_ind_timer = true
						end
						TogIndicStateForVeh(veh, state_indic[veh])
						count_ind_timer = 0
						count_broadcast_timer = delay_broadcast_timer
					-- IND R
					elseif IsDisabledControlJustReleased(0, SETTINGS.right_signal_key) then -- INPUT_VEH_NEXT_RADIO_TRACK
						local cstate = state_indic[veh]
						if cstate == ind_state_r then
							state_indic[veh] = ind_state_o
							actv_ind_timer = false
						else
							state_indic[veh] = ind_state_r
							actv_ind_timer = true
						end
						TogIndicStateForVeh(veh, state_indic[veh])
						count_ind_timer = 0
						count_broadcast_timer = delay_broadcast_timer
					-- IND H
					elseif IsControlPressed(0, SETTINGS.hazard_key) then -- INPUT_FRONTEND_CANCEL / Backspace
						if GetLastInputMethod(0) then -- last input was with kb
							Wait(SETTINGS.hazard_hold_duration)
							if IsControlPressed(0, SETTINGS.hazard_key) then -- INPUT_FRONTEND_CANCEL / Backspace
								local cstate = state_indic[veh]
								if cstate == ind_state_h then
									state_indic[veh] = ind_state_o
									AUDIO:Play('Hazards_Off', AUDIO.hazards_volume, true) -- Hazards Off
								else
									state_indic[veh] = ind_state_h
									AUDIO:Play('Hazards_On', AUDIO.hazards_volume, true) -- Hazards On
								end
								TogIndicStateForVeh(veh, state_indic[veh])
								actv_ind_timer = false
								count_ind_timer = 0
								count_broadcast_timer = delay_broadcast_timer
								Wait(300)
							end
						end
					end
				end

				----- AUTO BROADCAST VEH STATES -----
				if count_broadcast_timer > delay_broadcast_timer then
					count_broadcast_timer = 0
					--- IS EMERG VEHICLE ---
					if GetVehicleClass(veh) == 18 then
						local mode = MCTRL:GetSirenMode()
						TriggerServerEvent('lvc:TogDfltSrnMuted_s', dsrn_mute)
						TriggerServerEvent('lvc:SetLxSirenState_s', state_lxsiren[veh], VCF_ID, mode)
						TriggerServerEvent('lvc:SetAuxilaryState_s', state_auxiliary[veh], VCF_ID, mode)
						TriggerServerEvent('lvc:SetAirManuState_s', state_airmanu[veh], VCF_ID, (actv_horn and not actv_manu), mode)
					end
					--- IS ANY OTHER VEHICLE ---
					TriggerServerEvent('lvc:TogIndicState_s', state_indic[veh])
				else
					count_broadcast_timer = count_broadcast_timer + 1
				end
			end
		end
		main_thread_running = true
		Wait(0)
	end
end
