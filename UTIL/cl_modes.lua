--[[
---------------------------------------------------
LUXART VEHICLE CONTROL FLEET (FOR FIVEM)
---------------------------------------------------
Coded by Lt.Caine
ELS Clicks by Faction
Additional Modification by TrevorBarns
---------------------------------------------------
FILE: cl_modes.lua
PURPOSE: Functionality to switch between rumbler, 
		 local, and server side sirens.
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
MCTRL = { }
MCTRL.NORMAL = 1
MCTRL.RUMBLER = 2
MCTRL.LOCAL = 3

local override_peer_sirens = false
local siren_mode = 1

--RUMBLER
local rumbler_duration_index = 1
local rumbler_duration = 5
local timer = rumbler_duration
local previous_mode = nil

local siren_modes = {
						{ string = 'String', ref = 'Ref', bank = 'Bank' },
						{ string = 'RumblerString', ref = 'RumblerRef', bank = 'RumblerBank' },
						{ string = 'ResidentString', ref = 0, bank = nil },
					}
local rumbler_durations = { 5, 10, 30, -1 }


function MCTRL:SetOverridePeerState(state)
	override_peer_sirens = state
end

function MCTRL:GetOverridePeerState()
	return override_peer_sirens
end

function MCTRL:SetSirenMode(mode)
	if type(mode) == 'boolean' then
		if not mode then
			mode = 1
		else
			mode = 3
		end
	end

	siren_mode = mode
end

function MCTRL:GetSirenMode()
	return siren_mode
end

function MCTRL:GetSirenModeTable(mode)
	return siren_modes[mode]
end

function MCTRL:SetRumblerDurationIndex(duration_index)
	rumbler_duration_index = duration_index
	rumbler_duration = rumbler_durations[rumbler_duration_index]
	timer = rumbler_duration
end

function MCTRL:GetRumblerDurationIndex()
	return rumbler_duration_index
end

function MCTRL:SetTempRumblerMode(state, kill)
	kill = kill or false
	if state and siren_mode ~= self.RUMBLER then
		previous_mode = siren_mode
		siren_mode = self.RUMBLER
		AUDIO:Play('Upgrade', AUDIO.upgrade_volume)
		SetLxSirenStateForVeh(veh, state_lxsiren[veh])
	elseif siren_mode == self.RUMBLER then
		if previous_mode ~= nil then
			siren_mode = previous_mode
		else
			siren_mode = self.NORMAL
		end
		AUDIO:Play('Downgrade', AUDIO.downgrade_volume)
		if not kill then
			SetLxSirenStateForVeh(veh, state_lxsiren[veh])
		end
	end
end

CreateThread(function()
	Wait(500)
	while true do
		if LVC.rumbler then
			if siren_mode == MCTRL.RUMBLER and rumbler_duration ~= -1 then
				while timer > 0 and siren_mode == MCTRL.RUMBLER do
					timer = timer - 1
					Wait(1000)
				end
				timer = rumbler_duration
				if siren_mode == MCTRL.RUMBLER then
					siren_mode = previous_mode
					SetLxSirenStateForVeh(veh, state_lxsiren[veh])
					previous_mode = nil
				end
				Wait(0)
			else
				Wait(1000)
			end
		else
			Wait(1000)
		end
	end
end)

