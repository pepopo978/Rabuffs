-- RABuffs_core.lua
--  Administrative/core elements.
-- Version 0.10.2

RAB_Lock = 1;

RABuffs_Version = "0.12.0";
RABuffs_DeciVersion = 0.100300;

RABui_Settings = {};
RABui_DefSettings = {
	Layout = {},
	updateInterval = 0.5,
	firstRun = true,
	currentProfileByChar = {},
	enableGreeting = true,
	lastVersion = RABuffs_Version,
	stoppvp = true,
	castbigbuffs = false,
	alwayscastbigbuffs = false,
	syntaxhelp = true,
	lockwindow = false,
	colorizechat = true,
	dummymode = true,
	partymode = true,
	uilocale = "",
	outlocale = "",
	showsolo = false,
	showparty = true,
	showraid = true,
	hideincombat = false,
	hideactive = false,
	trustctra = false,
	keepversions = false,
	enablefadingfx = true,
	showsampleoutputonclick = false,
	newestVersion = "fresh",
	newestVersionTitle = RABuffs_Version,
	newestVersionPlayer = "Default",
	newestVersionRealm = "Default"
};
RABui_DefBars = {
	{ class = "ALL", buffKey = "alive", label = "Alive", color = { 0.3, 1, 0.3 }, priority = 1, out = "RAID" },
	{ class = "ALL", buffKey = "mana", classes = "pdsa", label = "Healer", color = { 0.4, 0.6, 1 }, priority = 1, out = "RAID" },
	{ class = "ALL", buffKey = "mana", classes = "mlh", label = "DPS", color = { 0.2, 0.2, 1 }, priority = 1, out = "RAID" },
	{ class = "DRUID", buffKey = "motw", label = "Mark", color = { 0.8, 0.2, 1 }, priority = 10, out = "RAID" },
	{ class = "DRUID", buffKey = "thorns", label = "Thorns", color = { 0.8, 0.6, 1 }, priority = 5, out = "RAID" },
	{ class = "PRIEST", buffKey = "pwf", label = "Fortitude", color = { 0.9, 0.9, 0.9 }, priority = 10, out = "RAID" },
	{ class = "PRIEST", buffKey = "sprot", label = "Shadow Protection", color = { 0.6, 0.6, 0.6 }, priority = 5, out = "RAID" },
	{ class = "MAGE", buffKey = "ai", label = "Intellect", color = { 0, 0.6, 1 }, priority = 10, out = "RAID" }
};
RAB_ClassShort = {
	Mage = "m",
	Warlock = "l",
	Priest = "p",
	Rogue = "r",
	Druid = "d",
	Hunter = "h",
	Shaman = "s",
	Warrior = "w",
	Paladin = "a"
};
RABui_CompleteBars = {}; -- track which bars to hide/show

RAB_CastLog = {}; -- Spell targets out of LoS. [unit] = expires;
RAB_CurrentGroupStatus = -1;

RAB_NumBuffsCache = {};
RAB_BuffCache = {};
RAB_BuffLastUpdated = {};
RAB_NumDebuffsCache = {};
RAB_DebuffCache = {};
RAB_DebuffLastUpdated = {};

local RestorSelfAutoCastTimeOut = 1;
local RestorSelfAutoCast = false;

ptr = CreateFrame("Frame", "RAB_CoreDummy", UIParent);
ptr.subscribers = {};
ptr:SetScript("OnEvent", function()
	if (this.subscribers[event] ~= nil) then
		local key, val, unsub;
		for key, val in this.subscribers[event] do
			unsub = val();
			if (unsub == "remove") then
				this.subscribers[event][key] = nil;
			end
		end
	end
end);
ptr:SetScript("OnUpdate", function()
	if (RestorSelfAutoCast) then
		RestorSelfAutoCastTimeOut = RestorSelfAutoCastTimeOut - arg1;
		if (RestorSelfAutoCastTimeOut < 0) then
			RestorSelfAutoCast = false;
			SetCVar("autoSelfCast", "1");
		end
	end
	if (this.timerNext ~= nil and this.timers ~= nil and this.timerNext < GetTime()) then
		local key, val, nt;
		nt = GetTime() + 86400;
		for key, val in this.timers do
			if (val.trigger < GetTime() and val.enabled) then
				val.trigger = GetTime() + val.interval;
				okay = val.func();
			end
			nt = min(nt, val.trigger);
		end
	end
end);
function RAB_Core_Register(event, key, func)
	if (RAB_CoreDummy.subscribers[event] == nil) then
		RAB_CoreDummy:RegisterEvent(event);
		RAB_CoreDummy.subscribers[event] = {};
	end
	if (RAB_CoreDummy.subscribers[event][key] == nil or RAB_CoreDummy.subscribers[event][key] == func) then
		RAB_CoreDummy.subscribers[event][key] = func;
	else
		RAB_Print("[RABuffs/Core] Register event/key conflict for " .. event .. ":" .. key .. "; ignoring add request.",
				"warn");
	end
end

function RAB_Core_Unregister(event, key)
	if (RAB_CoreDummy.subscribers[event] ~= nil and RAB_CoreDummy.subscribers[event][key] ~= nil) then
		RAB_CoreDummy.subscribers[event][key] = nil;
		local k, v;
		for k, v in RAB_CoreDummy.subscribers[event] do
			return ;
		end
		RAB_CoreDummy.subscribers[event] = nil;
		RAB_CoreDummy:UnregisterEvent(event);
	end
end

function RAB_Core_AddTimer(interval, key, func)
	if (RAB_CoreDummy.timers == nil) then
		RAB_CoreDummy.timers = {};
		RAB_CoreDummy.timerNext = GetTime() + interval;
	end
	tinsert(RAB_CoreDummy.timers, {
		interval = interval,
		id = key,
		trigger = GetTime() + interval,
		enabled = true,
		func = func
	});
end

function RAB_Core_RemoveTimer(id)
	if (RAB_CoreDummy.timers ~= nil) then
		local key, val;
		for key, val in RAB_CoreDummy.timers do
			if (val.id == id) then
				RAB_CoreDummy.timers[key] = nil;
			end
		end
	end
end

function RAB_Core_Raise(eve, ar1, ar2, ar3, ar4, ar5, ar6, ar7, ar8, ar9)
	if (RAB_CoreDummy.subscribers[eve] ~= nil) then
		local e, a1, a2, a3, a4, a5, a6, a7, a8, a9 = event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9;
		event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = eve, ar1, ar2, ar3, ar4, ar5, ar6, ar7, ar8, ar9;
		RAB_CoreDummy:GetScript("OnEvent")();
		event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = e, a1, a2, a3, a4, a5, a6, a7, a8, a9;
	end
end

function RAB_Core_List()
	local key, val, k2, v2;
	for key, val in RAB_CoreDummy.subscribers do
		for k2, v2 in val do
			RAB_Print(key .. "." .. k2 .. ":" .. tostring(v2));
		end
	end
	for key, val in RAB_CoreDummy.timers do
		RAB_Print("TIMER: " .. val.id .. " " .. val.interval .. " " .. tostring(val.func));
	end
end

function RAB_StartUp()
	local key, val;
	for key, val in RABui_Settings do
		if (RABui_DefSettings[key] == nil) then
			RABui_Settings[key] = nil;
		end
	end
	for key, val in RABui_DefSettings do
		if (RABui_Settings[key] == nil) then
			RABui_Settings[key] = RABui_DefSettings[key];
		end
	end
	RABui_DefSettings = nil;

	-- Migrate old profile system
	RAB_MigrateOldProfiles();

	if (RABui_Bars == nil) then
		-- First run, populate.
		local profileKey = RAB_GetProfileKey();
		if (RABui_Settings.Layout[profileKey] ~= nil) then
			RABui_Bars = RABui_Settings.Layout[profileKey];
		else
			local _, uc = UnitClass("player");
			RABui_Bars = {};
			for key, val in RABui_DefBars do
				if (val.class == uc or val.class == "ALL") then
					tinsert(RABui_Bars, val);
				end
			end
		end
	end

	-- set new selfLimit and useOnClick values
	for index, bar in ipairs(RABui_Bars) do
		-- default useOnClick to true
		if bar.useOnClick == nil then
			bar.useOnClick = true;
		end
		-- default selfLimit to false
		if not bar.selfLimit then
			bar.selfLimit = false; -- default to false
		end

		-- convert from old cmd format if necessary
		if bar.cmd then
			local _, _, buffKey, groups, classes = string.find(bar.cmd, "(%a+) ?(%d*) ?(%a*)");

			-- remove self from start of name if present and set selfLimit to true
			if string.find(buffKey, "self") == 1 then
				buffKey = string.sub(buffKey, 5);
				bar.selfLimit = true;
			end

			if buffKey == "spiritzanza" then
				buffKey = "spiritofzanza";
			end

			if buffKey == "fortitude" then
				buffKey = "elixirfortitude";
			end

			-- look if old "self" or "selfbuffonly" or "wepbuffonly" type is set on the buff buffKey
			local buff = RAB_Buffs[buffKey];
			if buff and buff.type then
				if buff.type == "self" or buff.type == "selfbuffonly" or buff.type == "wepbuffonly" then
					bar.selfLimit = true;
				end
			end

			bar.buffKey = buffKey; -- key of the buff in RAB_Buffs
			bar.groups = groups;
			bar.classes = classes;
			bar.cmd = nil;
		end

		if not bar.classes then
			bar.classes = "";
		end

		if not bar.groups then
			bar.groups = "";
		end

		if not bar.buffKey or not RAB_Buffs[bar.buffKey] then
			RAB_Print("Bar " .. index .. " has an invalid name: " .. tostring(bar.buffKey) .. " please readd that buff", "warn");
			RABui_Bars[index] = nil;
		end
	end

	RABui_DefBars = nil;

	RAB_Versions = type(RABui_Settings.keepversions) == "table" and RABui_Settings.keepversions or {};

	return "remove"; -- unsubscribe event
end

function RAB_CleanUp()
	if (GetChannelName(RAB_gSync_Channel) ~= 0) then
		LeaveChannelByName(RAB_gSync_Channel);
	end
	RABui_IsUIShown = (RABFrame:IsShown() == 1);

	local profileKey = RAB_GetProfileKey();
	RABui_Settings.Layout[profileKey] = RABui_Bars;
	RABui_Bars = nil;
	RABui_Settings.keepversions = type(RABui_Settings.keepversions) == "table" and RAB_Versions or false;
end

function RAB_GroupStatusChange()
	local ns = 0;
	if (event == "CHAT_MSG_SYSTEM" and arg1 == ERR_RAID_YOU_JOINED) then
		ns = 2;
	elseif (event == "CHAT_MSG_SYSTEM" and arg1 == ERR_RAID_YOU_LEFT) then
		ns = 0;
	elseif (GetNumRaidMembers() > 0) then
		ns = 2;
	elseif (GetNumPartyMembers() > 0) then
		ns = 1;
	end
	if (ns ~= RAB_CurrentGroupStatus) then
		RABui_UpdateVisibility(ns, RAB_CurrentGroupStatus)
		RAB_Core_Raise("RAB_GROUPSTATUS", ns, RAB_CurrentGroupStatus);
		RAB_CurrentGroupStatus = ns;
	end
	if (event == "PLAYER_ENTERING_WORLD") then
		return "remove";
	end
end

RAB_Core_Register("PLAYER_ENTERING_WORLD", "groupStatus", RAB_GroupStatusChange);
RAB_Core_Register("CHAT_MSG_SYSTEM", "groupStatus", RAB_GroupStatusChange);
RAB_Core_Register("VARIABLES_LOADED", "load", RAB_StartUp);
RAB_Core_Register("PLAYER_LOGOUT", "unload", RAB_CleanUp);

-- Profile Management Functions
function RAB_GetCharKey()
	return GetCVar("realmName") .. "." .. UnitName("player");
end

function RAB_GetCurrentProfile()
	local charKey = RAB_GetCharKey();
	if RABui_Settings.currentProfileByChar and RABui_Settings.currentProfileByChar[charKey] then
		return RABui_Settings.currentProfileByChar[charKey];
	end
	return "Default";
end

function RAB_SetCurrentProfile(profileName)
	if not RABui_Settings.currentProfileByChar then
		RABui_Settings.currentProfileByChar = {};
	end
	RABui_Settings.currentProfileByChar[RAB_GetCharKey()] = profileName;
end

function RAB_GetProfileKey(profileName)
	if not profileName then
		profileName = RAB_GetCurrentProfile();
	end
	return RAB_GetCharKey() .. "." .. profileName;
end

function RAB_GetAllProfiles()
	local profiles = {};
	local playerPrefix = GetCVar("realmName") .. "." .. UnitName("player") .. ".";
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		return profiles;
	end
	
	for key, val in pairs(RABui_Settings.Layout) do
		if string.find(key, "^" .. string.gsub(playerPrefix, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) then
			local profileName = string.sub(key, string.len(playerPrefix) + 1);
			if profileName ~= "" then
				table.insert(profiles, profileName);
			end
		end
	end
	
	return profiles;
end

function RAB_SaveProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	RABui_Settings.Layout[profileKey] = {};
	
	-- Deep copy current bars
	for i, bar in ipairs(RABui_Bars) do
		RABui_Settings.Layout[profileKey][i] = {};
		for key, val in pairs(bar) do
			RABui_Settings.Layout[profileKey][i][key] = val;
		end
	end
	
	RAB_Print("Profile '" .. profileName .. "' saved");
	return true;
end

function RAB_CreateNewProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	
	-- Check if profile already exists
	if RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' already exists");
		return false;
	end
	
	-- Create new profile with empty bars
	RABui_Settings.Layout[profileKey] = {};
	
	-- Clear current bars and sync UI
	RABui_Bars = {};
	RABui_SyncBars();
	if RABui_UpdateTitle then
		RABui_UpdateTitle();
	end
	if RABui_Settings_Layout_SyncList then
		RABui_Settings_Layout_SyncList();
	end
	
	RAB_Print("New profile '" .. profileName .. "' created with empty bars");
	return true;
end

function RAB_LoadProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		RAB_Print("Error: No profiles available");
		return false;
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	if not RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' does not exist");
		return false;
	end
	
	-- Clear current bars
	RABui_Bars = {};
	
	-- Deep copy profile bars
	for i, bar in ipairs(RABui_Settings.Layout[profileKey]) do
		RABui_Bars[i] = {};
		for key, val in pairs(bar) do
			RABui_Bars[i][key] = val;
		end
	end
	
	RAB_SetCurrentProfile(profileName);
	RAB_Print("Profile '" .. profileName .. "' loaded");
	
	-- Refresh UI
	RABui_SyncBars();
	if RABui_UpdateTitle then
		RABui_UpdateTitle();
	end
	if RAB_Settings_Frame and RAB_Settings_Frame:IsVisible() then
		RABui_Settings_Refresh();
	end
	
	return true;
end

function RAB_DeleteProfile(profileName)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end
	
	if profileName == "Default" then
		RAB_Print("Error: Cannot delete the Default profile");
		return false;
	end
	
	-- Safety check: ensure Layout table exists
	if not RABui_Settings or not RABui_Settings.Layout then
		RAB_Print("Error: No profiles available");
		return false;
	end
	
	local profileKey = RAB_GetProfileKey(profileName);
	if not RABui_Settings.Layout[profileKey] then
		RAB_Print("Error: Profile '" .. profileName .. "' does not exist");
		return false;
	end
	
	RABui_Settings.Layout[profileKey] = nil;
	
	-- If we just deleted the current profile, switch to Default
	if RAB_GetCurrentProfile() == profileName then
		RAB_LoadProfile("Default");
	end
	
	RAB_Print("Profile '" .. profileName .. "' deleted");
	return true;
end

function RAB_MigrateOldProfiles()
	local playerPrefix = RAB_GetCharKey() .. ".";
	local oldCurrentKey = playerPrefix .. "current";
	local newDefaultKey = playerPrefix .. "Default";

	-- Migrate .current to Default if Default doesn't exist
	if RABui_Settings.Layout[oldCurrentKey] and not RABui_Settings.Layout[newDefaultKey] then
		RABui_Settings.Layout[newDefaultKey] = RABui_Settings.Layout[oldCurrentKey];
		RABui_Settings.Layout[oldCurrentKey] = nil;
		RAB_Print("Migrated existing profile to 'Default'");
	end

	-- Migrate old global currentProfile to per-character
	if RABui_Settings.currentProfile then
		if not RABui_Settings.currentProfileByChar then
			RABui_Settings.currentProfileByChar = {};
		end
		local charKey = RAB_GetCharKey();
		if not RABui_Settings.currentProfileByChar[charKey] then
			RABui_Settings.currentProfileByChar[charKey] = RABui_Settings.currentProfile;
		end
		RABui_Settings.currentProfile = nil;
	end
end

-- Helper function to serialize a value
function RAB_SerializeValue(val)
	local valType = type(val);
	if valType == "string" then
		return "\"" .. string.gsub(val, "([\"\\])", "\\%1") .. "\"";
	elseif valType == "number" then
		return tostring(val);
	elseif valType == "boolean" then
		return val and "true" or "false";
	elseif valType == "table" then
		local result = "{";
		local first = true;
		for k, v in pairs(val) do
			if not first then
				result = result .. ",";
			end
			first = false;
			if type(k) == "number" then
				result = result .. "[" .. k .. "]=" .. RAB_SerializeValue(v);
			else
				result = result .. "[" .. RAB_SerializeValue(k) .. "]=" .. RAB_SerializeValue(v);
			end
		end
		return result .. "}";
	else
		return "nil";
	end
end

-- Export current profile to a string
function RAB_ExportProfile()
	if not RABui_Bars or table.getn(RABui_Bars) == 0 then
		RAB_Print("Error: No bars to export");
		return nil;
	end

	local serialized = RAB_SerializeValue(RABui_Bars);
	RAB_Print("Profile exported successfully", "ok");
	return serialized;
end

-- Import profile from a string
function RAB_ImportProfile(profileName, profileData)
	if not profileName or profileName == "" then
		RAB_Print("Error: Profile name cannot be empty");
		return false;
	end

	if not profileData or profileData == "" then
		RAB_Print("Error: Profile data cannot be empty");
		return false;
	end

	-- Safety check: ensure Layout table exists
	if not RABui_Settings then
		RABui_Settings = {};
	end
	if not RABui_Settings.Layout then
		RABui_Settings.Layout = {};
	end

	local profileKey = RAB_GetProfileKey(profileName);

	-- Try to deserialize the profile data
	local loadFunc, err = loadstring("return " .. profileData);
	if not loadFunc then
		RAB_Print("Error: Invalid profile data - " .. tostring(err));
		return false;
	end

	local success, bars = pcall(loadFunc);
	if not success or type(bars) ~= "table" then
		RAB_Print("Error: Could not parse profile data");
		return false;
	end

	-- Validate the bars
	for i, bar in ipairs(bars) do
		if not bar.buffKey or not RAB_Buffs[bar.buffKey] then
			RAB_Print("Error: Bar " .. i .. " has invalid buff key: " .. tostring(bar.buffKey));
			return false;
		end
	end

	-- Save the imported profile
	RABui_Settings.Layout[profileKey] = bars;

	RAB_Print("Profile '" .. profileName .. "' imported successfully");
	return true;
end

function RAB_SendMessage(st, target, prefix)
	-- Chunk up at commas.
	if (target == "CONSOLE") then
		RAB_Print(st);
	elseif (strlen(st) < 256) then
		RAB_DoSendMessage(st, target);
	else
		local chunk1 = strsub(st, 1, 250);
		local chunk2 = strsub(st, 251);
		local lcpos = strrpos(chunk1, ",");
		chunk2 = "... " .. strsub(chunk1, lcpos + 1) .. chunk2;
		chunk1 = strsub(chunk1, 1, lcpos) .. " ...";
		RAB_DoSendMessage(chunk1, target);
		RAB_SendMessage((prefix ~= nil and prefix or "") .. chunk2, target);
	end
end

function RAB_DoSendMessage(st, target)
	-- Get a string, send a string
	local autoClearAFK = GetCVar("autoClearAFK");
	SetCVar("autoClearAFK", 0);
	if (target == "RAID" or target == "RAID_WARNING" or target == "GUILD" or target == "OFFICER" or target == "PARTY" or target == "SAY") then
		SendChatMessage(st, target);
	elseif (string.find(target, "CHANNEL:(%w+)") ~= nil) then
		local _, _, chan = string.find(target, "CHANNEL:(%w+)");
		local chanid = GetChannelName(chan);
		if (chanid ~= 0) then
			SendChatMessage(st, "CHANNEL", DEFAULT_CHAT_FRAME.editBox.language, chanid);
		else
			RAB_Print(string.format(sRAB_OutputLayerError_NotInChannel, chan), "warn");
		end
	else
		if (string.find(target, "WHISPER:(.+)") ~= nil) then
			_, _, target = string.find(target, "WHISPER:(.+)");
		end
		SendChatMessage(st, "WHISPER", DEFAULT_CHAT_FRAME.editBox.language, target);
	end
	SetCVar("autoClearAFK", autoClearAFK);
end

function RAB_GroupMembers(userData)
	return RAB_GroupMember, userData, 0
end

function RAB_GroupMember(userData, i)
	local party_prefix, party_max, ok, group, u;
	if (UnitInRaid("player")) then
		party_prefix = "raid";
		party_max = 40;
	else
		party_prefix = "party";
		party_max = 5;
	end
	ok = false;

	while true do
		i = i + 1;
		if (i > party_max) then
			return nil;
		end ;
		u = party_prefix .. i;
		if (u == "party5") then
			u = "player"
		end
		_, _, group = GetRaidRosterInfo(i);
		if (UnitExists(u) and RAB_UnitClass(u) ~= nil) then
			if (userData.groups == "" or string.find(userData.groups, tostring(group)) ~= nil) then
				if (userData.classes == "" or string.find(userData.classes, RAB_ClassShort[RAB_UnitClass(u)]) ~= nil) then
					return i, u, group;
				end
			end
		end
	end
end

-- GENERAL BUFF-QUERY CODELINE.
function RAB_BuffCheckOutput(userData, outputTo, invert)
	-- Check query, output results (Called by the /rab handler (command UI), bar clicks (visual UI)).
	local output = (userData.groups ~= "" and userData.groups ~= "12345678") and ("[G" .. userData.groups .. "] ") or "";
	output = output .. (userData.classes ~= "" and strlen(userData.classes) < 8 and "[" .. userData.classes .. "] " or "");

	if (RAB_Buffs[userData.buffKey] ~= nil) then
		local _, _, _, _, _, _, mtext, htext, invert2 = RAB_CallRaidBuffCheck(userData, true, true);
		if (invert2) then
			invert = not invert;
		end
		if (mtext == nil) then
			return ;
		end
		output = output .. (invert and htext or mtext);
	else
		output = "Unknown buff requested ('" .. userData.buffKey .. "').";
		outputTo = "CONSOLE";
	end
	if (outputTo == "RAID" and not UnitInRaid("player")) then
		outputTo = "PARTY";
	end
	output = sRAB_BuffOutputPrefix .. output;
	RAB_SendMessage(output, outputTo, sRAB_BuffOutputPrefix);
end

function RAB_CallRaidBuffCheck(userData, needraw, needtxt)
	-- Check query, return results (UI)
	local repl;
	if (RAB_Lock == 1) then
		return { total = 0, buffed = 0, txt = sRAB_Error_NotReady, hastxt = sRAB_Error_NotReady };
	end
	local excludeNames = userData.excludeNames or {};

	if RAB_Buffs ~= nil and RAB_Buffs[userData.buffKey] ~= nil then
		if RAB_Buffs[userData.buffKey].queryFunc ~= nil then
			return RAB_Buffs[userData.buffKey].queryFunc(userData, needraw, needtxt);
		else
			return RAB_DefaultQueryHandler(userData, needraw, needtxt);
		end
	else
		return 0, 0, 0, sRAB_Error_NoBuffDataBar, "", "", sRAB_Error_NoBuffData, sRAB_Error_NoBuffData;
	end
end

function RAB_IsEligible(u, userData)
	if not UnitIsConnected(u) then
		return false;
	end

	if userData.buffKey ~= 'pvp' and RAB_UnitIsDead(u) then
		return false;
	end

	if userData.selfLimit and not UnitIsUnit(u, 'player') then
		return false;
	end

	local unitName = UnitName(u);

	-- If unitname matches anything in the excludeNames list case insensitive, return false
	for _, name in ipairs(userData.excludeNames or {}) do
		if string.lower(name) == string.lower(unitName) then
			return false;
		end
	end

	local buff = RAB_Buffs[userData.buffKey];

	-- check for main tank filtering
	if buff.ignoreMTs ~= nil and RAB_CTRA_IsMT(unitName) then
		return false;
	end

	-- check for ignoreClass
	if buff.ignoreClass ~= nil and string.find(buff.ignoreClass, RAB_ClassShort[RAB_UnitClass(u)]) ~= nil then
		return false;
	end

	-- check for class specific spells
	if buff.class ~= nil and RAB_UnitClass(u) ~= buff.class then
		return false;
	end

	return true;
end

function RAB_IsSanePvP(target)
	return (RABui_Settings.stoppvp ~= true or UnitIsPVP("player")) or not UnitIsPVP(target);
end

-- Casting abstraction layer: get rid of errors in a humane way.
function RAB_CastSpell_Start(spellkey, muteobvious, mute)
	local sName = sRAB_SpellNames[spellkey];

	if (not RAB_CastSpell_IsCastable(spellkey, muteobvious, mute)) then
		return false;
	end

	RestorSelfAutoCastTimeOut = 1;
	if (GetCVar("autoSelfCast") == "1") then
		RestorSelfAutoCast = true;
		SetCVar("autoSelfCast", "0");
	end

	RAB_SpellCast_ShouldRetarget = UnitExists("target");
	ClearTarget();

	local ok, reason = pcall(CastSpellByName, sName);
	if (not ok) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastingLayer_NoSpell, sRAB_SpellNames[spellkey]), "warn");
		end
		if (RAB_SpellCast_ShouldRetarget) then
			TargetLastTarget();
		end
		return false;
	end

	local target = "target";
	if UnitName("target") == nil then
		target = "player";
	end

	RABui_LastBuffEvent = GetTime();
	RAB_ClearUnitBuffCache(target)

	if (not SpellIsTargeting()) then
		if (RAB_SpellCast_ShouldRetarget and not SpellIsTargeting()) then
			TargetLastTarget();
		end
		if (not mute) then
			RAB_Print(string.format(sRAB_CastBuff_CouldNotCast, sRAB_SpellNames[spellkey]), "warn");
		end
		return false;
	end
	return true;
end

function RAB_CastSpell_IsCastable(spellkey, mute, muteobvious)
	if (sRAB_SpellNames[spellkey] == nil or sRAB_SpellIDs[spellkey] == nil) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastingLayer_NoEntry, spellkey), "warn");
		end
		return false, "What";
	end
	if (RAB_UnitIsDead("player")) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_Dead, sRAB_SpellNames[spellkey]), "warn");
		end
		return false, "Dead";
	end
	if (UnitMana("player") < RAB_SpellManaCost(sRAB_SpellIDs[spellkey], BOOKTYPE_SPELL)) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_NoMana, sRAB_SpellNames[spellkey]), "warn");
		end
		return false, "Mana";
	end
	if (UnitOnTaxi("player")) then
		if (not muteobvious) then
			RAB_Print(string.format(sRAB_CastingLayer_NoMana, sRAB_SpellNames[spellkey]), "warn");
		end
		return false, "Taxi";
	end
	local start, duration = GetSpellCooldown(sRAB_SpellIDs[spellkey], BOOKTYPE_SPELL);
	if (start ~= 0) then
		if (not mute) then
			RAB_Print(string.format(sRAB_CastingLayer_Cooldown, sRAB_SpellNames[spellkey]), "warn");
		end
		return false, "Cooldown", start + duration - GetTime();
	end
	return true;
end

function RAB_CastSpell_Target(targ)
	RAB_BuffLastUpdated[targ] = nil

	if (SpellIsTargeting()) then
		SpellTargetUnit(targ);
		if (RAB_SpellCast_ShouldRetarget) then
			TargetLastTarget();
			RAB_SpellCast_ShouldRetarget = false;
		end
		if (not UnitIsUnit("player", targ)) then
			RAB_CastLog[targ] = time() + 15;
		end
		return true;
	end
end

function RAB_CastSpell_Abort()
	if (SpellIsTargeting()) then
		SpellStopTargeting();
		if (RAB_SpellCast_ShouldRetarget) then
			TargetLastTarget();
			RAB_SpellCast_ShouldRetarget = false;
		end
		return true;
	end
end

-- BACKGROUND CORE
function RAB_RaidMemberInfo(name)
	-- Is "Marvin" in raid?
	local i, u;
	for i, u in RAB_GroupMembers({ ["groups"] = "", ["classes"] = "", }) do
		if (UnitName(u) == name) then
			local rank = 0;
			if (UnitInRaid("player")) then
				_, rank = GetRaidRosterInfo(i);
			end
			if (UnitIsPartyLeader(u)) then
				rank = 2;
			end
			return true, u, rank;
		end
	end
	return false, "", -1;
end

function RAB_SanitizeTexture(texture)
	-- Santize texture by removing path prefix
	if (strsub(texture, 1, 16) == "Interface\\Icons\\") then
		return strsub(texture, 17);
	end
	return texture;
end

function RAB_TextureToBuff(texture)
	-- Convert texture to buff key, if known.
	texture = RAB_SanitizeTexture(texture);

	for buffKey, buffData in RAB_Buffs do
		-- check for missing identifiers unless it's a special buff
		if buffData.identifiers == nil then
			if buffData.sfunc == nil then
				RAB_Print("Buff " .. buffKey .. " has no identifiers!", "warn")
			end
		else
			for _, identifier in ipairs(buffData.identifiers) do
				if (texture == identifier.texture) then
					return buffKey;
				end
			end
		end
	end
	return nil;
end

function RAB_IsBuffUp(unit, buffKey)
	-- Resolve and check a buff based on its key [Custom stuff doesn't work]
	local key, val, ret;
	if (RAB_Buffs[buffKey].type == "debuff") then
		for _, identifier in ipairs(RAB_Buffs[buffKey].identifiers) do
			if (isUnitDebuffUp(unit, identifier)) then
				return true;
			end
		end
		return false;
	elseif (RAB_Buffs[buffKey].type == "special") then
		return nil;
	else
		for _, identifier in ipairs(RAB_Buffs[buffKey].identifiers) do
			if (isUnitBuffUp(unit, identifier)) then
				return true;
			end
		end
		return false;
	end
end

function RAB_UnitClass(unit)
	-- Localization/nil workaround.
	local _, ec = UnitClass(unit);
	ec = (ec ~= nil) and ec or "Mage";
	return strsub(ec, 1, 1) .. strlower(strsub(ec, 2));
end

function RAB_UnitIsDead(unit)
	-- Still hopelessly bugged.
	return (UnitIsDeadOrGhost(unit) and not isUnitBuffUp(unit, { tooltip = "Feign Death", texture = "Ability_Rogue_FeignDeath", spellId = 5384 }));
end

local function updateSpellTooltip(unit, index, spellId, isBuff)
	local tooltip = nil
	if spellId and SpellInfo then
		tooltip = SpellInfo(spellId)
	elseif UnitName(unit) == UnitName("player") then
		-- get tooltips as well but only for player as it hurts performance
		-- fall back to texture + tooltip comparison, not perfect
		RAB_TooltipScanner:ClearLines()
		if isBuff == true then
			RAB_TooltipScanner:SetUnitBuff(unit, index)
		else
			RAB_TooltipScanner:SetUnitDebuff(unit, index)
		end
		tooltip = RAB_TooltipScannerTextLeft1:GetText()
	end

	return tooltip
end

function RAB_ClearUnitBuffCache(unit)
	RAB_BuffLastUpdated[unit] = nil;

	if unit == "player" or unit == "target" then
		-- clear raid cache
		for i = 1, GetNumRaidMembers() do
			if (UnitIsUnit("raid" .. i, unit)) then
				RAB_BuffLastUpdated["raid" .. i] = nil;
			end
		end
	end
end

function RAB_CacheUnitBuffs(unit)
	if not RAB_BuffCache[unit] then
		RAB_BuffCache[unit] = {};
	end

	if not RAB_NumBuffsCache[unit] then
		RAB_NumBuffsCache[unit] = 0;
	end

	for i = 1, 32 do
		local texture, stacks, spellId = UnitBuff(unit, i);
		if texture then
			if not RAB_BuffCache[unit][i] then
				RAB_BuffCache[unit][i] = {};
			end
			if spellId and spellId < 0 then
				spellId = spellId + 65536 -- correct integer overflow from previous versions of superwow
			end

			if not RAB_BuffCache[unit][i].tooltip or spellId ~= RAB_BuffCache[unit][i].spellId then
				RAB_BuffCache[unit][i].tooltip = updateSpellTooltip(unit, i, spellId, true);
			end
			RAB_BuffCache[unit][i].texture = texture
			RAB_BuffCache[unit][i].stacks = stacks
			RAB_BuffCache[unit][i].spellId = spellId
		else
			RAB_NumBuffsCache[unit] = i - 1;
			break ;
		end
	end
	RAB_BuffLastUpdated[unit] = GetTime();
end

function RAB_CacheUnitDebuffs(unit)
	if not RAB_DebuffCache[unit] then
		RAB_DebuffCache[unit] = {};
	end

	if not RAB_NumDebuffsCache[unit] then
		RAB_NumDebuffsCache[unit] = 0;
	end

	for i = 1, 16 do
		local texture, stacks, spellSchool, spellId = UnitDebuff(unit, i);
		if texture then
			if not RAB_DebuffCache[unit][i] then
				RAB_DebuffCache[unit][i] = {};
			end
			if spellId and spellId < 0 then
				spellId = spellId + 65536 -- correct integer overflow from previous versions of superwow
			end
			if not RAB_DebuffCache[unit][i].tooltip or spellId ~= RAB_DebuffCache[unit][i].spellId then
				RAB_DebuffCache[unit][i].tooltip = updateSpellTooltip(unit, i, spellId, false);
			end
			RAB_DebuffCache[unit][i].texture = texture
			RAB_DebuffCache[unit][i].stacks = stacks
			RAB_DebuffCache[unit][i].spellId = spellId
		else
			RAB_NumDebuffsCache[unit] = i - 1;
			break
		end
	end
	RAB_DebuffLastUpdated[unit] = GetTime();
end

local function checkForMatch(buffData, searchTexture, identifier)
	-- use spellID if available, requires superwow
	if buffData.spellId and identifier.spellId then
		if buffData.spellId == identifier.spellId then
			return true;
		end
	else
		-- fall back to texture scan, not perfect
		if searchTexture and buffData.texture == searchTexture then
			-- check for tooltip if available
			if identifier.tooltip and buffData.tooltip then
				if identifier.tooltip == buffData.tooltip then
					return true;
				end
			else
				-- no tooltip, default to returning true for matching texture
				return true;
			end
		end
	end
	return nil;
end

function isUnitBuffUp(unit, identifier)
	if (unit == nil or not UnitExists(unit) or identifier == nil) then
		return false;
	end

	local cTime = GetTime();

	local recentlyCastBuffUpdate = RABui_LastBuffEvent > 0 and RABui_LastBuffEvent > cTime - 3 -- unless we casted a buff in the last 3 second
	if recentlyCastBuffUpdate and RAB_BuffLastUpdated[unit] and RAB_BuffLastUpdated[unit] > RABui_LastBuffEvent then
		-- unit already updated, don't update again
		recentlyCastBuffUpdate = false;
	end

	if RAB_BuffCache[unit] == nil or
			RAB_BuffLastUpdated[unit] == nil or
			RAB_BuffLastUpdated[unit] < cTime - 5 or -- cache for 5 sec
			recentlyCastBuffUpdate
	then
		RAB_CacheUnitBuffs(unit)
	end

	local unitBuffs = RAB_BuffCache[unit];

	local searchTexture = "";
	if identifier.texture then
		searchTexture = "Interface\\Icons\\" .. identifier.texture
	end

	for i, buffData in pairs(unitBuffs) do
		if i > RAB_NumBuffsCache[unit] then
			break ;
		end

		if checkForMatch(buffData, searchTexture, identifier) then
			return true;
		end
	end
	return false;
end

function isUnitDebuffUp(unit, identifier)
	if (unit == nil or not UnitExists(unit) or identifier == nil) then
		return false;
	end

	if RAB_DebuffCache[unit] == nil or (RAB_DebuffLastUpdated[unit] and RAB_DebuffLastUpdated[unit] < GetTime() - 1) then
		RAB_CacheUnitDebuffs(unit)
	end

	local unitDebuffs = RAB_DebuffCache[unit];

	local searchTexture = "";
	if identifier.texture then
		searchTexture = "Interface\\Icons\\" .. identifier.texture
	end

	for i, debuffData in pairs(unitDebuffs) do
		if i > RAB_NumDebuffsCache[unit] then
			break ;
		end
		if checkForMatch(debuffData, searchTexture, identifier) then
			return true;
		end
	end
	return false;
end

function strrpos(str, chr)
	local start = string.find(str, chr, 1, true);
	while string.find(str, chr, start + 1, true) ~= nil do
		start = string.find(str, chr, start + 1, true);
	end
	return start;
end
