local addon = CreateFrame("Frame")
local defaults = { x = 0, y = 110, size = 36, delay = 0.6, sound = false, enabled = true, noTarget = true, suppressFacing = true, suppressRange = true, showMinimap = true, minimapAngle = 225 }
local db, playerGUID, rangeSpell
local elapsed, pending, pendingSince, lastSound = 0, "", 0, 0
local facingUntil, facingGUID, testUntil = 0, nil, 0
local activeSince, soundTimes = {}, {}
local nextSoundAt = 0
local unlocked = false
local locationAllowed = true

local display = CreateFrame("Frame", "mDPSUptimeDisplay", UIParent)
display:SetSize(650, 130)
display:SetFrameStrata("HIGH")
display:SetClampedToScreen(true)
display:SetMovable(true)
display:RegisterForDrag("LeftButton")
display:EnableMouse(false)
local text = display:CreateFontString(nil, "OVERLAY")
text:SetAllPoints()
text:SetJustifyH("CENTER")
text:SetJustifyV("MIDDLE")
text:SetShadowOffset(2, -2)
local background = display:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0, 0, 0, 0.6)
background:Hide()

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffmDPS Uptime:|r " .. message)
end

local function Apply()
    display:ClearAllPoints()
    display:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    text:SetFont(STANDARD_TEXT_FONT, db.size, "OUTLINE")
end

display:SetScript("OnDragStart", function(self) self:StartMoving() end)
display:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local px, py = UIParent:GetCenter()
    db.x, db.y = x - px, y - py
    Apply()
end)

local function FindRangeSpell()
    rangeSpell = nil
    -- Prefer Hamstring; Rend and Sunder Armor work for lower level warriors.
    for _, id in ipairs({1715, 772, 7386}) do
        local name = GetSpellInfo(id)
        if name then
            local index = 1
            while true do
                local known = GetSpellBookItemName(index, BOOKTYPE_SPELL)
                if not known then break end
                if known == name then rangeSpell = index; return end
                index = index + 1
            end
        end
    end
end

local function ValidTarget()
    return UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDeadOrGhost("target")
end

local warningOrder = {"facing", "attack", "range", "target"}
local warningText = {
    attack = "|cffff4444NOT AUTO ATTACKING|r",
    range = "|cffff4444TOO FAR AWAY|r",
    facing = "|cffffaa00FACING THE WRONG WAY|r",
    target = "|cffffcc00NO TARGET|r",
}
local function InitializeAlerts(reset)
    if reset or type(db.alertEnabled) ~= "table" then db.alertEnabled = {} end
    if reset or type(db.alertDelays) ~= "table" then db.alertDelays = {} end
    if reset or type(db.alertSounds) ~= "table" then db.alertSounds = {} end
    for index, key in ipairs({"attack", "range", "facing", "target"}) do
        if type(db.alertEnabled[key]) ~= "boolean" then
            db.alertEnabled[key] = key ~= "target" or db.noTarget
        end
        if type(db.alertDelays[key]) ~= "number" then
            db.alertDelays[key] = key == "facing" and 0 or db.delay
        end
        db.alertDelays[key] = math.max(0, math.min(3, db.alertDelays[key]))
        if type(db.alertSounds[key]) ~= "number" or db.alertSounds[key] < 0
            or db.alertSounds[key] > #mDPSUptimeSounds or db.alertSounds[key] % 1 ~= 0
            or not mDPSUptimeSoundAllowed(db.alertSounds[key], key) then
            db.alertSounds[key] = index
        end
    end
end
function mDPSUptimePlayBeep(choice)
    local sound = mDPSUptimeSounds[choice]
    if sound then
        PlaySoundFile("Interface\\AddOns\\mDPSUptime\\Sounds\\" .. sound.file, "Master")
        return sound.duration
    end
    return 0
end
local function ClearAlertTimers()
    activeSince, soundTimes = {}, {}
    nextSoundAt = 0
end
local function UpdateWarnings()
    if not db then return end
    local now = GetTime()
    if unlocked then
        text:SetText("|cffff4444NOT AUTO ATTACKING|r\n|cffffaa00Drag to move - /mdps lock|r")
        return
    end
    if now < testUntil then
        text:SetText(warningText.attack .. "\n" .. warningText.range .. "\n" .. warningText.facing)
        return
    end
    local active = {}
    if db.enabled and locationAllowed and not UnitIsDeadOrGhost("player") and UnitAffectingCombat("player") then
        if not UnitExists("target") then
            active.target = db.noTarget
        elseif ValidTarget() then
            active.attack = not IsCurrentSpell(6603)
            active.range = rangeSpell and IsSpellInRange(rangeSpell, BOOKTYPE_SPELL, "target") == 0
            active.facing = now < facingUntil and facingGUID == UnitGUID("target")
        end
    else
        facingUntil, facingGUID = 0, nil
    end
    local lines = {}
    local beepKey
    for _, key in ipairs(warningOrder) do
        if active[key] and db.alertEnabled[key] then
            activeSince[key] = activeSince[key] or now
            if now - activeSince[key] >= db.alertDelays[key] then
                lines[#lines + 1] = warningText[key]
                if db.sound and db.alertSounds[key] > 0 and now >= nextSoundAt
                    and (not soundTimes[key] or now - soundTimes[key] >= 4) then
                    -- Oldest waiting warning gets the next sound slot.
                    if not beepKey or (soundTimes[key] or -math.huge) < (soundTimes[beepKey] or -math.huge) then
                        beepKey = key
                    end
                end
            end
        else
            activeSince[key], soundTimes[key] = nil, nil
        end
    end
    text:SetText(table.concat(lines, "\n"))
    if beepKey then
        local duration = mDPSUptimePlayBeep(db.alertSounds[beepKey])
        soundTimes[beepKey], nextSoundAt = now, now + math.max(0.65, duration + 0.1)
    end
end

addon:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    UpdateWarnings()
end)

addon:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= "mDPSUptime" then return end
        if type(NoltUptimeDB) ~= "table" then NoltUptimeDB = {} end
        db = NoltUptimeDB
        for key, value in pairs(defaults) do
            if type(db[key]) ~= type(value) then db[key] = value end
        end
        db.size = math.max(16, math.min(72, db.size))
        db.delay = math.max(0, math.min(3, db.delay))
        InitializeAlerts()
        mDPSUptimeOptions.Initialize(db, function()
            ClearAlertTimers()
            locationAllowed = mDPSUptimeOptions.LocationAllowed()
            mDPSUptimeMinimap.Refresh()
            pending, pendingSince, facingUntil, facingGUID = "", GetTime(), 0, nil
            if not unlocked and GetTime() >= testUntil then text:SetText("") end
        end)
        locationAllowed = mDPSUptimeOptions.LocationAllowed()
        Apply()
        mDPSUptimeMinimap.Initialize(db)
    elseif event == "PLAYER_LOGIN" then
        -- v1.1.3 native event filter, extended to include range errors.
        -- Keep our independent UI_ERROR_MESSAGE listener for addon warnings.
        if UIErrorsFrame then
            local originalOnEvent = UIErrorsFrame:GetScript("OnEvent")
            if originalOnEvent then
                UIErrorsFrame:SetScript("OnEvent", function(self, nativeEvent, ...)
                    if nativeEvent == "UI_ERROR_MESSAGE" then
                        local _, message = ...
                        local facing = ERR_BADATTACKFACING and message == ERR_BADATTACKFACING
                        local range = (ERR_BADATTACKPOS and message == ERR_BADATTACKPOS)
                            or (ERR_OUT_OF_RANGE and message == ERR_OUT_OF_RANGE)
                            or (SPELL_FAILED_OUT_OF_RANGE and message == SPELL_FAILED_OUT_OF_RANGE)
                            or message == "You are too far away!"
                            or message == "You are too far away."
                            or message == "You are too far away"
                        if db and db.enabled and locationAllowed
                            and not UnitIsDeadOrGhost("player")
                            and UnitAffectingCombat("player") and ValidTarget()
                            and ((db.suppressFacing and facing) or (db.suppressRange and range)) then
                            return
                        end
                    end
                    return originalOnEvent(self, nativeEvent, ...)
                end)
            end
        end
        playerGUID = UnitGUID("player")
        FindRangeSpell()
        Print("Loaded. /mdps config opens settings; /mdps test previews warnings.")
        if not rangeSpell then Print("No known melee range spell found; range warnings are unavailable.") end
    elseif event == "SPELLS_CHANGED" then
        FindRangeSpell()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        FindRangeSpell()
        if db then locationAllowed = mDPSUptimeOptions.LocationAllowed() end
        ClearAlertTimers()
        pending, pendingSince, facingUntil, facingGUID = "", GetTime(), 0, nil
        if not unlocked and GetTime() >= testUntil then text:SetText("") end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        ClearAlertTimers()
        facingUntil, facingGUID, pending = 0, nil, ""
        pendingSince = GetTime()
        if db and not unlocked and GetTime() >= testUntil then text:SetText("") end
    elseif event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        if db and db.enabled and locationAllowed and message == ERR_BADATTACKFACING
            and UnitAffectingCombat("player") and ValidTarget() then
            facingUntil, facingGUID = GetTime() + math.max(2.5, db.alertDelays.facing + 1.5), UnitGUID("target")
            UpdateWarnings()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if facingGUID and sourceGUID == playerGUID and destGUID == facingGUID
            and (subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" or subevent == "SPELL_DAMAGE") then
            facingUntil, facingGUID = 0, nil
            UpdateWarnings()
        end
    end
end)

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED", "UI_ERROR_MESSAGE", "COMBAT_LOG_EVENT_UNFILTERED",
    "ZONE_CHANGED_NEW_AREA"}) do
    addon:RegisterEvent(event)
end

SLASH_MDPSUPTIME1 = "/mdps"
SLASH_MDPSUPTIME2 = "/mdpsuptime"
SLASH_MDPSUPTIME3 = "/nu"
SlashCmdList.MDPSUPTIME = function(input)
    if not db then return end
    local cmd, value = input:lower():match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "config" then
        mDPSUptimeOptions.Open()
    elseif cmd == "minimap" then
        db.showMinimap = not db.showMinimap
        mDPSUptimeMinimap.Refresh()
        Print(db.showMinimap and "Minimap button shown." or "Minimap button hidden.")
    elseif cmd == "test" then
        testUntil = GetTime() + 10
    elseif cmd == "unlock" or cmd == "lock" then
        unlocked = cmd == "unlock"
        display:EnableMouse(unlocked)
        background:SetShown(unlocked)
        if not unlocked then display:StopMovingOrSizing() end
        Print(unlocked and "Drag the preview, then /mdps lock." or "Position locked.")
    elseif cmd == "size" and tonumber(value) then
        db.size = math.max(16, math.min(72, tonumber(value)))
        Apply(); testUntil = GetTime() + 10
    elseif cmd == "delay" and tonumber(value) then
        db.delay = math.max(0, math.min(3, tonumber(value)))
        for _, key in ipairs({"attack", "range", "target"}) do db.alertDelays[key] = db.delay end
        ClearAlertTimers()
        Print("Attack, range, and no target delays: " .. db.delay .. " seconds. Facing uses its own slider.")
    elseif cmd == "sound" then
        db.sound = not db.sound
        Print("Sound " .. (db.sound and "on." or "off."))
    elseif cmd == "target" then
        db.noTarget = not db.noTarget
        db.alertEnabled.target = db.noTarget
        Print("No target warning " .. (db.noTarget and "on." or "off."))
    elseif cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        Print(db.enabled and "Enabled." or "Disabled.")
    elseif cmd == "reset" then
        for key, value in pairs(defaults) do db[key] = value end
        InitializeAlerts(true)
        ClearAlertTimers()
        mDPSUptimeOptions.Reset()
        Apply(); Print("Settings reset.")
    else
        Print("/mdps config | minimap | test | unlock | lock | size 36 | delay 0.6 | sound | target | on | off | reset")
    end
end

