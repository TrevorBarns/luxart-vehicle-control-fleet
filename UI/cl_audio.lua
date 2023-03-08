--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_audio.lua
PURPOSE: NUI Audio Related Functions.
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
AUDIO = { }
AUDIO.radio_wheel_active = false

local activity_timer = 0
local activity_reminder_lookup = { [2] = 30000, [3] = 60000, [4] = 120000, [5] = 300000, [6] = 600000 }

------ACTIVITY REMINDER FUNCTIONALITY------
CreateThread(function()
	local self = AUDIO
	while true do
		while player_is_emerg_driver and self.activity_reminder_interval_index ~= nil and self.activity_reminder_interval_index > 1 do
			if IsVehicleSirenOn(veh) and state_lxsiren[veh] == 0 and state_auxiliary[veh] == 0 then
				if activity_timer < 1 then
					self:Play('Reminder', self.activity_reminder_volume)
					self:ResetActivityTimer()
				end
			end
			Wait(100)
		end
		Wait(1000)
	end
end)

-- Activity Reminder Timer
CreateThread(function()
	local self = AUDIO
	while true do
		while player_is_emerg_driver and self.activity_reminder_interval_index ~= nil and self.activity_reminder_interval_index > 1 and IsVehicleSirenOn(veh) and state_lxsiren[veh] == 0 and state_auxiliary[veh] == 0 do
			if activity_timer > 1 then
				Wait(1000)
				activity_timer = activity_timer - 1000
			else
				Wait(100)
				self:ResetActivityTimer()
			end
		end
		Wait(1000)
	end
end)

--	Handles radio wheel controls and default horn on siren change playback. 
CreateThread(function()
	local self = AUDIO
	while true do
		while player_is_emerg_driver do
			-- RADIO WHEEL
			if IsControlPressed(0, 243) and self.radio then
				while IsControlPressed(0, 243) do
					self.radio_wheel_active = true
					SetControlNormal(0, 85, 1.0)
					Wait(0)
				end
				Wait(100)
				self.radio_wheel_active = false
			else
				DisableControlAction(0, 85, true) -- INPUT_VEH_RADIO_WHEEL
			end
			Wait(0)
		end
		Wait(200)
	end
end)


---------------------------------------------------------------------
--[[Play NUI front in audio.]]
function AUDIO:Play(sound_file, sound_volume, schemeless)
	local schemeless = schemeless or false
	-- game SFX normalized volume
	sound_volume = sound_volume * GetProfileSetting(300) / 10
	if not schemeless then
		self.scheme = self.schemes[self.scheme_index]
		sound_file = self.scheme .. '/' .. sound_file;
	end

	SendNUIMessage({
	  _type  = 'audio',
	  file   = sound_file,
	  volume = sound_volume
	})
end

--[[After activity has occurred, reset the activity timer to the selected reminder interval]]
function AUDIO:ResetActivityTimer()
	activity_timer = activity_reminder_lookup[self.activity_reminder_interval_index] or 0
end
--[[Getter for current time in seconds remaining.]]
function AUDIO:GetActivityTimer()
	return activity_timer
end

--[[After activity has occurred, reset the activity timer to the selected reminder interval]]
function AUDIO:GetActivityReminderIndex()
	return self.activity_reminder_interval_index
end

--[[Setter for activity reminder index]]
function AUDIO:SetActivityReminderIndex(index)
	if index ~= nil then
		self.activity_reminder_interval_index = index
	end
end

--[[Setter for radio wheel and radio station]]
function AUDIO:SetRadioState(station)
	SetVehicleRadioEnabled(veh, self.radio)
	SetVehRadioStation(veh, station)
	Wait(500)
	SetVehRadioStation(veh, station)
end

	