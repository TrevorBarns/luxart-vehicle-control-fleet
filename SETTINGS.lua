--------------------COMMUNITY ID-------------------
community_id = ''
--	Sets a prefix for saved values at the user end, without this people who play on multiple LVC server could face conflicts. **Once set DO NOT CHANGE. It will result in loss of data for end users.**
--		I recommend something short (4-6 characters) for example a community abbreviation. SPACES ARE NOT ALLOWED.

------------------MENU KEYBINDING------------------
open_menu_key = 'O'
--	Sets default key for RegisterKeyMapping. Examples: 'l','F5', etc. DEFAULT: 'O', users may set one in their GTA V > Settings > Hotkeys > FiveM settings. 
--		More info: https://cookbook.fivem.net/2020/01/06/using-the-new-console-key-bindings/
--		List of Keys: https://pastebin.com/u9ewvWWZ


---------------LOCKOUT FUNCTIONALITY---------------
lockout_default_hotkey = ''
--	Sets default key for RegisterKeyMapping. Examples: 'l','F5', etc. DEFAULT: NONE, users may set one in their GTA V > Settings > Hotkeys > FiveM settings. 
--		More info: https://cookbook.fivem.net/2020/01/06/using-the-new-console-key-bindings/
--		List of Keys: https://pastebin.com/u9ewvWWZ
locked_press_count = 5    
--	Initial press count for reminder e.g. if this is 5 and reminder_rate is 10 then, after 5 key presses it will remind you the first time, after that every 10 key presses. 
reminder_rate = 10
--	How often, in luxart key presses, to remind you that your siren controller is locked.

--------------CUSTOM MANU/HORN/SIREN---------------
main_siren_set_register_keys_set_defaults = true
--	Enables RegisterKeyMapping for all main_allowed_tones and sets the default keys to numrow 1-0.
	-- False: leaves registered key maps unassigned for user assignment in GTA V Settings > Controls > FiveM

--------------TURN SIGNALS / HAZARDS---------------
hazard_key = 202	
left_signal_key = 84
right_signal_key = 83
hazard_hold_duration = 750
--	Time in milliseconds backspace must be pressed to turn on / off hazard lights. 

---------------------VCF FILES---------------------
VCF_Files = {
	'DEFAULT.xml',
}

VCF_Assignments = {
	['DEFAULT'] = { 1 },
}

------------------PLUG-IN SUPPORT------------------
plugins_installed = true

