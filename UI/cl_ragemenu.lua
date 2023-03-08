--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_ragemenu.lua
PURPOSE: Handle RageUI
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

RMenu.Add('lvc', 'main', RageUI.CreateMenu(' ', 'Main Menu', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'maintone', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'),' ', 'Main Siren Settings', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'rumbler', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'), ' ', 'Rumbler Options', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'hudsettings', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'),' ', 'HUD Settings', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'audiosettings', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'), ' ', 'Audio Settings', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'volumesettings', RageUI.CreateSubMenu(RMenu:Get('lvc', 'audiosettings'), ' ', 'Audio Settings', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'plugins', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'), ' ', 'Plugins', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'saveload', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'), ' ', 'Storage Management', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'copyprofile', RageUI.CreateSubMenu(RMenu:Get('lvc', 'saveload'), ' ', 'Copy Profile Settings', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu.Add('lvc', 'info', RageUI.CreateSubMenu(RMenu:Get('lvc', 'main'), ' ', 'More Information', 0, 0, "lvc", "lvc_fleet_logo"))
RMenu:Get('lvc', 'main'):SetTotalItemsPerPage(13)
RMenu:Get('lvc', 'maintone'):SetTotalItemsPerPage(15)
RMenu:Get('lvc', 'volumesettings'):SetTotalItemsPerPage(12)
RMenu:Get('lvc', 'main'):DisplayGlare(false)
RMenu:Get('lvc', 'maintone'):DisplayGlare(false)
RMenu:Get('lvc', 'rumbler'):DisplayGlare(false)
RMenu:Get('lvc', 'hudsettings'):DisplayGlare(false)
RMenu:Get('lvc', 'audiosettings'):DisplayGlare(false)
RMenu:Get('lvc', 'volumesettings'):DisplayGlare(false)
RMenu:Get('lvc', 'plugins'):DisplayGlare(false)
RMenu:Get('lvc', 'saveload'):DisplayGlare(false)
RMenu:Get('lvc', 'copyprofile'):DisplayGlare(false)
RMenu:Get('lvc', 'info'):DisplayGlare(false)

--Strings for Save/Load confirmation, not ideal but it works.
local ok_to_disable  = true
local confirm_s_msg
local confirm_l_msg
local confirm_fr_msg
local confirm_s_desc
local confirm_l_desc
local confirm_fr_desc
local confirm_c_msg = { }
local confirm_c_desc = { }
local profile_c_op = { }
local profile_s_op = 75
local profile_l_op = 75
local hazard_state = false
local sl_btn_debug_msg = ''

local approved_VCF_ids = {}
local approved_VCF_names = { }
local profiles = { } 

local curr_version
local repo_version
local newer_version
local version_description
local version_formatted

Keys.Register(SETTINGS.open_menu_key, 'lvc', 'LVC: Open Menu', function()
	if not key_lock and player_is_emerg_driver and UpdateOnscreenKeyboard() ~= 0 and MENU.menu_access then
		if UTIL:GetVehicleProfileName() == 'DEFAULT' then
			local veh_name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
			sl_btn_debug_msg = ' Using ~b~DEFAULT~s~ profile for \'~b~' .. veh_name .. '~s~\'.'
		else
			sl_btn_debug_msg = ''
		end
		profiles = STORAGE:GetSavedProfiles()
		RageUI.Visible(RMenu:Get('lvc', 'main'), not RageUI.Visible(RMenu:Get('lvc', 'main')))
	end
end)


--Trims front off tone-strings longer than 36 characters for front-end display
local function TrimToneString(tone_string)
	if #tone_string > 36 then
		local trim_amount = #tone_string - 33
		tone_string = string.format("...%s", string.sub(tone_string, trim_amount, 37))
	end
	
	return tone_string
end

--Returns true if any menu is open
function IsMenuOpen()
	return 	RageUI.Visible(RMenu:Get('lvc', 'main')) or
			RageUI.Visible(RMenu:Get('lvc', 'maintone')) or
			RageUI.Visible(RMenu:Get('lvc', 'rumbler')) or
			RageUI.Visible(RMenu:Get('lvc', 'hudsettings')) or
			RageUI.Visible(RMenu:Get('lvc', 'audiosettings')) or
			RageUI.Visible(RMenu:Get('lvc', 'volumesettings')) or
			RageUI.Visible(RMenu:Get('lvc', 'saveload')) or
			RageUI.Visible(RMenu:Get('lvc', 'copyprofile')) or
			RageUI.Visible(RMenu:Get('lvc', 'info')) or
			RageUI.Visible(RMenu:Get('lvc', 'plugins')) or
			IsPluginMenuOpen()
end

--Handle user input to cancel confirmation message for SAVE/LOAD
CreateThread(function()
	while true do
		while player_is_emerg_driver and not RageUI.Settings.Controls.Back.Enabled do
			for Index = 1, #RageUI.Settings.Controls.Back.Keys do
				if IsDisabledControlJustPressed(RageUI.Settings.Controls.Back.Keys[Index][1], RageUI.Settings.Controls.Back.Keys[Index][2]) then
					confirm_s_msg = nil
					confirm_s_desc = nil
					profile_s_op = 75
					confirm_l_msg = nil
					confirm_l_desc = nil
					profile_l_op = 75
					confirm_r_msg = nil
					confirm_fr_msg = nil
					for i, _ in ipairs(profiles) do
						profile_c_op[i] = 75
						confirm_c_msg[i] = nil
						confirm_c_desc[i] = nil
					end
					Wait(10)
					RageUI.Settings.Controls.Back.Enabled = true
					break
				end
			end
			Wait(0)
		end
		Wait(100)
	end
end)

--Handle Disabling Controls while menu open
CreateThread(function()
	Wait(1000)
	while true do
		while player_is_emerg_driver and IsMenuOpen() do
			DisableControlAction(0, 27, true)
			DisableControlAction(0, 99, true)
			DisableControlAction(0, 172, true)
			DisableControlAction(0, 173, true)
			DisableControlAction(0, 174, true)
			DisableControlAction(0, 175, true)
			Wait(0)
		end
		Wait(100)
	end
end)

--Triggered when vehicle changes (cl_lvc.lua)
RegisterNetEvent('lvc:onVehicleChange')
AddEventHandler('lvc:onVehicleChange', function()
	Wait(500)
	while VCFs.set == nil or VCFs.set == false do
		Wait(100)
	end
	approved_VCF_ids = UTIL:GetApprovedVCFIds()
	approved_VCF_names = UTIL:GetApprovedVCFNames()
end)

--Close all menus on vehicle exit.
CreateThread(function()
	while true do
		if IsMenuOpen() then
			if (not player_is_emerg_driver) then
				RageUI.CloseAll()
			end
		end
		Wait(500)
	end
end)

-- Resource start version handling
CreateThread(function()
	Wait(500)
	curr_version = STORAGE:GetCurrentVersion()
	repo_version = STORAGE:GetRepoVersion()
	newer_version = STORAGE:GetIsNewerVersion()
	version_description = ', the latest version.'
	version_formatted = curr_version or 'unknown'

	if newer_version == 'older' then
		version_description, version_formatted = ', an out-of-date version.', '~o~~h~'..curr_version		
	elseif newer_version == 'newer' then
		version_description = ', an ~y~experimental~s~ version.'
	elseif newer_version == 'unknown' then
		version_description = ', the latest version could not be determined.'
	end
end)

CreateThread(function()
    while true do
		--Main Menu Visible
		while player_is_emerg_driver do
			RageUI.IsVisible(RMenu:Get('lvc', 'main'), function()
				if #approved_VCF_ids > 1 then
					RageUI.List('Profile', approved_VCF_names, VCF_index, "Change which profile is loaded.", {}, true, {
					  onListChange = function(Index, Item)
						VCF_index = Index
						VCF_ID = UTIL:GetApprovedVCFIds()[VCF_index]
						STORAGE:LoadSettings(true)	
						UTIL:UpdateCurrentVCFData(veh)
					  end,
					})
				end				
				if MENU.toggle_local_override then
					RageUI.Checkbox('Local Override', 'When enabled, LVC will revert to client-side sirens (resident.rpf) when able (depending on LVC configuration).', MCTRL:GetSirenMode() == MCTRL.LOCAL, {}, {
					  onChecked = function()
						  LVC.local_override = true
						  MCTRL:SetSirenMode(3)
					  end,
					  onUnChecked = function()
						  LVC.local_override = false
						  MCTRL:SetSirenMode(1)
					  end,
					})
				end	
				if MENU.toggle_peer_override then
					RageUI.Checkbox('Peer Override', 'When enabled, LVC will override peers choice in siren with your own when able (depending on LVC configuration).', MCTRL:GetOverridePeerState(), {}, {
					  onChecked = function()
						  LVC.peer_override = true
						  MCTRL:SetOverridePeerState(true)
					  end,
					  onUnChecked = function()
						  LVC.peer_override = false
						  MCTRL:SetOverridePeerState(false)
					  end,
					})		
				end
				RageUI.Separator('Siren Settings')
				if MENU.menu_main_siren_settings then
					RageUI.Button('Main Siren Settings', 'Change which/how each available primary tone is used.', {RightLabel = '→→→'}, true, {
					}, RMenu:Get('lvc', 'maintone'))
				end
				
				if #HORNS > 1 then
					RageUI.List('Horn', HORNS, LVC.horn, 'Change your horn.', {}, true, {
					  onListChange = function(Index, Item)
						LVC.horn = Index
					  end,
					  onSelected = function()
						proposed_name = HUD:KeyboardInput('Enter new tone name for ' .. TrimToneString(HORNS[LVC.horn].String) .. ':', HORNS[LVC.horn].Name, 15)
						if proposed_name ~= nil then
							UTIL:ChangeToneString(LVC.horn, proposed_name, true)
						end
					  end,
					})			
				end

				if MENU.custom_manual then
					--PRIMARY MANUAL TONE List
					--Get Current Tone ID and index ToneTable offset by 1 to correct airhorn missing
					if LVC.primary_manual ~= -1 then
						RageUI.List('Primary Manual Tone', SIRENS, LVC.primary_manual, 'Change your primary manual tone.', {}, true, {
						  onListChange = function(Index, Item)
							LVC.primary_manual = Index
						  end,
						  onSelected = function()
							proposed_name = HUD:KeyboardInput('Enter new tone name for ' .. TrimToneString(SIRENS[LVC.primary_manual].String) .. ':', SIRENS[LVC.primary_manual].Name, 15)
							if proposed_name ~= nil then
								UTIL:ChangeToneString(LVC.primary_manual, proposed_name)
							end
						  end,
						})
					end				
					
					--SECONDARY MANUAL TONE List
					--Get Current Tone ID and index ToneTable offset by 1 to correct airhorn missing
					if LVC.secondary_manual ~= -1 then
						RageUI.List('Secondary Manual Tone', SIRENS, LVC.secondary_manual, 'Change your secondary manual tone.', {}, true, {
						  onListChange = function(Index, Item)
							LVC.secondary_manual = Index
						  end,
						  onSelected = function()
							proposed_name = HUD:KeyboardInput('Enter new tone name for ' .. TrimToneString(SIRENS[LVC.secondary_manual].String) .. ':', SIRENS[LVC.secondary_manual].Name, 15)
							if proposed_name ~= nil then
								UTIL:ChangeToneString(LVC.secondary_manual, proposed_name)
							end
						  end,
						})
					end
				end

				--AUXILARY MANUAL TONE List
				--Get Current Tone ID and index ToneTable offset by 1 to correct airhorn missing
				if MENU.custom_auxiliary then
					--AST List
					if LVC.auxiliary ~= -1 then
						RageUI.List('Auxiliary Siren Tone', SIRENS, LVC.auxiliary, 'Change your auxiliary/dual siren tone.', {}, true, {
						  onListChange = function(Index, Item)
							LVC.auxiliary = Index
						  end,
						  onSelected = function()
							proposed_name = HUD:KeyboardInput('Enter new tone name for ' .. TrimToneString(SIRENS[LVC.auxiliary].String) .. ':', SIRENS[LVC.auxiliary].Name, 15)
							if proposed_name ~= nil then
								UTIL:ChangeToneString(LVC.auxiliary, proposed_name)
							end
						  end,
						})
					end
				end
				--MAIN MENU TO SUBMENU BUTTONS
				RageUI.Separator('Other Settings')
				if MENU.menu_hud_settings then
					RageUI.Button('HUD Settings', 'Open HUD settings menu.', {RightLabel = '→→→'}, true, {
					  onSelected = function()
					  end,
					}, RMenu:Get('lvc', 'hudsettings'))
				end
				RageUI.Button('Audio Settings', 'Open audio settings menu.', {RightLabel = '→→→'}, true, {
				  onSelected = function()
				  end,
				}, RMenu:Get('lvc', 'audiosettings'))
				RageUI.Separator('Miscellaneous')
				if SETTINGS.plugins_installed then
					RageUI.Button('Plugins', 'Open Plugins Menu.', {RightLabel = '→→→'}, true, {
					  onSelected = function()
					  end,
					}, RMenu:Get('lvc', 'plugins'))
				end
				RageUI.Button('Storage Management', 'Save / Load vehicle profiles.', {RightLabel = '→→→'}, true, {
				  onSelected = function()
				  end,
				}, RMenu:Get('lvc', 'saveload'))
				RageUI.Button('More Information', 'Learn more about Luxart Vehicle Control.', {RightLabel = '→→→'}, true, {
				  onSelected = function()
				  end,
				}, RMenu:Get('lvc', 'info'))
			end)
			---------------------------------------------------------------------
			----------------------------MAIN TONE MENU---------------------------
			---------------------------------------------------------------------
			RageUI.IsVisible(RMenu:Get('lvc', 'maintone'), function()
				if MENU.toggle_airhorn_intrp or MENU.toggle_reset_standby or MENU.main_siren_settings_menu or MENU.toggle_park_kill then
					RageUI.Separator('Siren Settings')
					if MENU.menu_rumbler_options and LVC.rumbler then
						RageUI.Button('Rumbler Options', 'Options related to rumbler / howler siren.', {RightLabel = '→→→'}, true, {
						  onSelected = function()
						  end,
						}, RMenu:Get('lvc', 'rumbler'))
					end					
					if MENU.toggle_airhorn_intrp then
						RageUI.Checkbox('Airhorn Interrupt Mode', 'Toggles whether the airhorn interrupts main siren.', LVC.airhorn_intrp, {}, {
						  onChecked = function()
							LVC.airhorn_intrp = true
						  end,
						  onUnChecked = function()
							LVC.airhorn_intrp = false
						  end,
						})
					end
					if MENU.toggle_reset_standby then
						RageUI.Checkbox('Reset to Standby', '~g~Enabled~s~, the primary siren will reset to 1st siren on siren toggle. ~r~Disabled~s~, the last played tone will resume on siren toggle.', LVC.reset_standby, {}, {
						  onChecked = function()
							LVC.reset_standby = true
						  end,
						  onUnChecked = function()
							LVC.reset_standby = false
						  end,
						})
					end
					if MENU.toggle_park_kill then
						RageUI.Checkbox('Siren Park Kill', 'Toggles whether your sirens turn off automatically when you exit your vehicle. ', LVC.park_kill, {}, {
						  onChecked = function()
							LVC.park_kill = true
						  end,
						  onUnChecked = function()
							LVC.park_kill = false
						  end,
						})
					end
					if MENU.custom_tone_options then
						RageUI.Separator('Tone Options')
						for tone, siren_table in pairs(SIRENS) do
							RageUI.List(siren_table.Name, { 'Cycle & Button', 'Cycle Only', 'Button Only', 'Disabled' }, UTIL:GetToneOption(tone), '~g~Cycle:~s~ play as you cycle through sirens.\n~g~Button:~s~ play when registered key is pressed.\n~b~Select to rename siren tones.', {}, true, {
								onListChange = function(Index, Item)
									if UTIL:IsOkayToDisable(tone, Index) or Index < 3 then
										UTIL:SetToneOption(tone, Index)
									else
										HUD:ShowNotification('~y~~h~Info:~h~ ~s~Luxart Vehicle Control\nAction prohibited, cannot disable all sirens.', true)
									end
								end,
								onSelected = function()
									proposed_name = HUD:KeyboardInput('Enter new tone name for ' .. TrimToneString(siren_table.String) .. ':', siren_table.Name, 15)
									if proposed_name ~= nil then
										UTIL:ChangeToneString(tone, proposed_name)
									end
								end,
							})
						end
					end
				end
			end)	
			if MENU.menu_rumbler_options and LVC.rumbler then
				RageUI.IsVisible(RMenu:Get('lvc', 'rumbler'), function()
					RageUI.Checkbox('Enabled', 'Toggles controls for rumbler / howler functionality. ~c~(DEFAULT: LSHIFT+E)', LVC.rumbler_enabled, {}, {
						onChecked = function()
							LVC.rumbler_enabled = true
						end,
						onUnChecked = function()
							LVC.rumbler_enabled = false
							if MCTRL:GetSirenMode() == MCTRL.RUMBLER then
								MCTRL:SetSirenMode(MCTRL.NORMAL)
								SetLxSirenStateForVeh(veh, state_lxsiren[veh])
							end
						end,
					})
					if MENU.custom_rumbler_duration then
						RageUI.List('Duration', {'5', '10', '30', 'Indefinite'}, MCTRL:GetRumblerDurationIndex(), 'Determines how long to run rumbler tone before reverting to normal siren tone.', {}, LVC.rumbler_enabled, {
						  onListChange = function(Index, Item)
							MCTRL:SetRumblerDurationIndex(Index)
						  end,
						})
					end
				end)
			end
			---------------------------------------------------------------------
			-------------------------OTHER SETTINGS MENU-------------------------
			---------------------------------------------------------------------
			--HUD SETTINGS
			RageUI.IsVisible(RMenu:Get('lvc', 'hudsettings'), function()
				--if MENU.toggle_hud then
					RageUI.Checkbox('Enabled', 'Toggles whether HUD is displayed. Requires GTA V HUD to be enabled.', HUD.enabled, {}, {
						onChecked = function()
							HUD:SetHudState(true)
						end,
						onUnChecked = function()
							HUD:SetHudState(false)
						end,
					})
				--end
				RageUI.Button('Move Mode', 'Move HUD position on screen. To exit ~r~right-click~s~ or hit "~r~Esc~s~".', {}, HUD.enabled, {
					onSelected = function()
						HUD:SetMoveMode(true)
					end,
					});
				RageUI.Slider('Scale', (HUD:GetHudScale()*4), 6, 0.2, 'Change scale of the HUD.', false, {}, HUD.enabled, {
					onSliderChange = function(Index)
						HUD:SetHudScale(Index/4)
						Citizen.SetTimeout(500, STORAGE.SaveHUDSettings)
					end,
				});
				if MENU.custom_backlight_mode then
					RageUI.List('Backlight', {'Auto', 'Off', 'On'}, HUD.backlight_mode, 'Changes HUD backlight behavior. ~b~Auto~s~ is determined by headlight state.', {}, HUD.enabled, {
					  onListChange = function(Index, Item)
						HUD:SetHudBacklightMode(Index)
					  end,
					})
				end
				RageUI.Button('Reset', 'Reset HUD position to default.', {}, HUD.enabled, {
					onSelected = function()
						HUD:ResetPosition()
						HUD:SetHudState(false)
						HUD:SetHudState(true)
					end,
				});
			end)
			--AUDIO SETTINGS MENU
			RageUI.IsVisible(RMenu:Get('lvc', 'audiosettings'), function()
				if MENU.toggle_radio then
					RageUI.Checkbox('Radio Controls', 'When enabled, the ~b~tilde~s~ will act as a radio wheel key.', AUDIO.radio, {}, {
					  onChecked = function()
						  AUDIO.radio = true
						  SetVehicleRadioEnabled(veh, true)
					  end,
					  onUnChecked = function()
						  AUDIO.radio = false
						  SetVehicleRadioEnabled(veh, false)
					  end,
					})
				end
				
				RageUI.Separator('SoundFX Settings')
				if MENU.custom_scheme then
					RageUI.List('Siren Box Scheme', AUDIO.schemes, AUDIO.scheme_index, 'Change what SFX to use for siren box clicks. Press ~b~Enter~s~ to demo the scheme.', {}, true, {
					  onListChange = function(Index, Item)
						AUDIO.scheme_index = Index
						AUDIO.scheme = Value
					  end,
					  onSelected = function(Index, Item)
						AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
					  end,
					})
				end
				if MENU.toggle_clicks then
					RageUI.Checkbox('Manual Button Clicks', 'When enabled, your manual tone button will activate the upgrade SFX.', AUDIO.manual_sfx, {}, {
					  onChecked = function()
						  AUDIO.manual_sfx = true
					  end,
					  onUnChecked = function()
						  AUDIO.manual_sfx = false
					  end,
					})
					RageUI.Checkbox('Airhorn Button Clicks', 'When enabled, your airhorn button will activate the upgrade SFX.', AUDIO.airhorn_sfx, {}, {
					  onChecked = function()
						  AUDIO.airhorn_sfx = true
					  end,
					  onUnChecked = function()
						  AUDIO.airhorn_sfx = false
					  end,
					})
				end
				if MENU.custom_activity_reminder then
					RageUI.List('Activity Reminder', {'Off', '1/2', '1', '2', '5', '10'}, AUDIO:GetActivityReminderIndex(), ('Receive reminder tone that your lights are on. Options are in minutes. Timer (sec): %1.0f'):format((AUDIO:GetActivityTimer() / 1000) or 0), {}, true, {
					  onListChange = function(Index, Item)
						AUDIO:SetActivityReminderIndex(Index)
						AUDIO:ResetActivityTimer()
					  end,
					})
				end
				RageUI.Button('Adjust Volumes', 'Open volume settings menu.', {RightLabel = '→→→'}, true, {
				  onSelected = function()
				  end,
				}, RMenu:Get('lvc', 'volumesettings'))
			end)		
			--VOLUME SETTINGS MENU
			RageUI.IsVisible(RMenu:Get('lvc', 'volumesettings'), function()
				RageUI.Slider('On Volume', (AUDIO.on_volume*100), 100, 2, 'Set volume of light slider / button. Plays when lights are turned ~g~on~s~. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.on_volume = (Index / 100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('On', AUDIO.on_volume)
				  end,
				})
				RageUI.Slider('Off Volume', (AUDIO.off_volume*100), 100, 2, 'Set volume of light slider / button. Plays when lights are turned ~r~off~s~. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.off_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('Off', AUDIO.off_volume)
				  end,
				})
				RageUI.Slider('Upgrade Volume', (AUDIO.upgrade_volume*100), 100, 2, 'Set volume of siren button. Plays when siren is turned ~g~on~s~. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.upgrade_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
				  end,
				})
				RageUI.Slider('Downgrade Volume', (AUDIO.downgrade_volume*100), 100, 2, 'Set volume of siren button. Plays when siren is turned ~r~off~s~. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.downgrade_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
				  end,
				})
				RageUI.Slider('Activity Reminder Volume', (AUDIO.activity_reminder_volume*500), 100, 2, 'Set volume of activity reminder tone. Plays when lights are ~g~on~s~, siren is ~r~off~s~, and timer is has finished. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.activity_reminder_volume = (Index/500)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('Reminder', AUDIO.activity_reminder_volume)
				  end,
				})
				RageUI.Slider('Hazards Volume', (AUDIO.hazards_volume*100), 100, 2, 'Set volume of hazards button. Plays when hazards are toggled. Press ~b~Enter~s~ to play the sound.', true, {MuteOnSelected = true}, true, {
				  onSliderChange = function(Index)
					AUDIO.hazards_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					if hazard_state then
						AUDIO:Play('Hazards_On', AUDIO.hazards_volume, true)
					else
						AUDIO:Play('Hazards_Off', AUDIO.hazards_volume, true)
					end
					hazard_state = not hazard_state
				  end,
				})
				RageUI.Slider('Lock Volume', (AUDIO.lock_volume*100), 100, 2, 'Set volume of lock notification sound. Plays when siren box lockout is toggled. Press ~b~Enter~s~ to play the sound.', true, {}, true, {
				  onSliderChange = function(Index)
					AUDIO.lock_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('key_lock', AUDIO.lock_volume, true)
				  end,
				})
				RageUI.Slider('Lock Reminder Volume', (AUDIO.lock_reminder_volume*100), 100, 2, 'Set volume of lock reminder sound. Plays when locked out keys are pressed repeatedly. Press ~b~Enter~s~ to play the sound.', true, {}, true, {
				  onSliderChange = function(Index)
					AUDIO.lock_reminder_volume = (Index/100)
				  end,
				  onSelected = function(Index, Item)
					AUDIO:Play('Locked_Press', AUDIO.lock_reminder_volume, true)
				  end,
				})
			end)
			---------------------------------------------------------------------
			----------------------------SAVE LOAD MENU---------------------------
			---------------------------------------------------------------------
			RageUI.IsVisible(RMenu:Get('lvc', 'saveload'), function()
				RageUI.Button('Save Settings', confirm_s_desc or 'Save LVC settings.' .. sl_btn_debug_msg, {RightLabel = confirm_s_msg or '('.. UTIL:GetVehicleProfileName() .. ')', RightLabelOpacity = profile_s_op}, true, {
					onSelected = function()
						if confirm_s_msg == 'Are you sure?' then
							STORAGE:SaveSettings()
							HUD:ShowNotification('~g~Success~s~: Your settings have been saved.', true)
							confirm_s_msg = nil
							confirm_s_desc = nil
							profile_s_op = 75
						else
							RageUI.Settings.Controls.Back.Enabled = false
							profile_s_op = 255
							confirm_s_msg = 'Are you sure?'
							confirm_s_desc = '~r~This will override any existing save data for this vehicle profile ('..UTIL:GetVehicleProfileName()..').'
							confirm_l_msg = nil
							profile_l_op = 75
							confirm_r_msg = nil
							confirm_fr_msg = nil
						end
					end,
				})
				RageUI.Button('Load Settings', confirm_l_desc or 'Load LVC settings.' .. sl_btn_debug_msg, {RightLabel = confirm_l_msg or '('.. UTIL:GetVehicleProfileName() .. ')', RightLabelOpacity = profile_l_op}, true, {
				  onSelected = function()
					if confirm_l_msg == 'Are you sure?' then
						STORAGE:LoadSettings()
						HUD:ShowNotification('~g~Success~s~: Your settings have been loaded.', true)
						confirm_l_msg = nil
						confirm_l_desc = nil
						profile_l_op = 75
					else
						RageUI.Settings.Controls.Back.Enabled = false
						profile_l_op = 255
						confirm_l_msg = 'Are you sure?'
						confirm_l_desc = '~r~This will override any unsaved settings.'
						confirm_s_msg = nil
						profile_s_op = 75
						confirm_r_msg = nil
						confirm_fr_msg = nil
					end
				  end,
				})
				RageUI.Separator('Advanced Settings')
				RageUI.Button('Copy Settings', 'Copy profile settings from another vehicle. ~o~Coming soon to LVC:F.', {RightLabel = '→→→'}, false, {
				}, RMenu:Get('lvc', 'copyprofile'))
				RageUI.Button('Reset Settings', '~r~Reset LVC to it\'s default state, preserves existing saves. Will override any unsaved settings.', {RightLabel = confirm_r_msg}, true, {
				  onSelected = function()
					if confirm_r_msg == 'Are you sure?' then
						STORAGE:ResetSettings()
						HUD:ShowNotification('~g~Success~s~: Settings have been reset.', true)
						confirm_r_msg = nil
					else
						RageUI.Settings.Controls.Back.Enabled = false
						confirm_r_msg = 'Are you sure?'
						confirm_l_msg = nil
						profile_l_op = 75
						confirm_s_msg = nil
						profile_s_op = 75
						confirm_fr_msg = nil
					end
				  end,
				})
				RageUI.Button('Factory Reset', '~r~Permanently delete any saves, resetting LVC to its default state.', {RightLabel = confirm_fr_msg}, true, {
				  onSelected = function()
					if confirm_fr_msg == 'Are you sure?' then
						RageUI.CloseAll()
						Wait(100)
						local choice = HUD:FrontEndAlert('Warning', 'Are you sure you want to delete all saved LVC data and Factory Reset?', '~g~No: Escape \t ~r~Yes: Enter')
						if choice then
							STORAGE:FactoryReset()
						else
							RageUI.Visible(RMenu:Get('lvc', 'saveload'), true)
						end
						confirm_fr_msg = nil
					else
						RageUI.Settings.Controls.Back.Enabled = false
						confirm_fr_msg = 'Are you sure?'
						confirm_l_msg = nil
						profile_l_op = 75
						confirm_s_msg = nil
						profile_s_op = 75
						confirm_r_msg = nil
					end
				  end,
				})
			end)

			--Copy Profiles Menu
			RageUI.IsVisible(RMenu:Get('lvc', 'copyprofile'), function()
				for i, profile_name in ipairs(profiles) do
					if profile_name ~= UTIL:GetVehicleProfileName() then
						profile_c_op[i] = profile_c_op[i] or 75
						RageUI.Button(profile_name, confirm_c_desc[i] or 'Attempt to load settings from profile \'~b~'..profile_name..'~s~\'.', {RightLabel = confirm_c_msg[i] or 'Load', RightLabelOpacity = profile_c_op[i]}, true, {
						  onSelected = function()
							if confirm_c_msg[i] == 'Are you sure?' then
								STORAGE:LoadSettings(profile_name)
								HUD:ShowNotification('~g~Success~s~: Your settings have been loaded.', true)
								confirm_c_msg[i] = nil
								confirm_c_desc[i] = nil
								profile_c_op[i] = 75
							else
								RageUI.Settings.Controls.Back.Enabled = false
								for j, _ in ipairs(profiles) do
									if i ~= j then
										profile_c_op[j] = 75
										confirm_c_msg[j] = nil
										confirm_c_desc[j] = nil
									end
								end
								profile_c_op[i] = 255
								confirm_c_msg[i] = 'Are you sure?'
								confirm_c_desc[i] = '~r~This will override any unsaved settings.'
							end
						  end,
						})
					end
				end
			end)
			---------------------------------------------------------------------
			------------------------------ABOUT MENU-----------------------------
			---------------------------------------------------------------------
			RageUI.IsVisible(RMenu:Get('lvc', 'info'), function()
				RageUI.Button('Current Version', ('This server is running %s%s'):format(version_formatted, version_description), { RightLabel = version_formatted }, true, {
				  onSelected = function()
				  end,
				});
				if newer_version == 'older' then
					RageUI.Button(Lang:t('menu.latest_version'), ('The latest update is %s.'):format(repo_version), {RightLabel = repo_version or 'unknown'}, true, {
						onSelected = function()
					end,
					});
				end
				RageUI.Button('About / Credits', 'Originally designed and created by ~b~Lt. Caine~s~. ELS sound effects by ~b~Faction~s~. LVC:Fleet expansion by ~b~Trevor Barns~s~.\n\nSpecial thanks to all contributors (see GitHub), the RageUI team, and everyone else who helped beta test, this would not have been possible without you all!', {}, true, {
					onSelected = function()
				end,
				});				
				RageUI.Button('Website', 'Learn more about Luxart Engineering and it\'s products at ~b~https://www.luxartengineering.com~w~!', {}, true, {
					onSelected = function()
				end,
				});
			end)
			Wait(0)
		end
		Wait(500)
	end
end)