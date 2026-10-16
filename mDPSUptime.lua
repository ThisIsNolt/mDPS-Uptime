local addon = CreateFrame("Frame")
local defaults = { x = 0, y = 110, size = 36, delay = 0.6, sound = false, enabled = true, noTarget = true, suppressFacing = true, suppressRange = true }
local db, playerGUID, rangeSpell
local elapsed, pending, pendingSince, lastSound = 0, "", 0, 0
local facingUntil, facingGUID, testUntil = 0, nil, 0
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

local function Warning(now)
    if not db.enabled or not locationAllowed or UnitIsDeadOrGhost("player") or not UnitAffectingCombat("player") then
        facingUntil, facingGUID = 0, nil
        return ""
    end
    if not UnitExists("target") then
        return db.noTarget and "|cffffcc00NO TARGET|r" or ""
    end
    if not ValidTarget() then return "" end
    local lines = {}
    if not IsCurrentSpell(6603) then
        lines[#lines + 1] = "|cffff4444NOT AUTO ATTACKING|r"
    end
    if rangeSpell then
        local inRange = IsSpellInRange(rangeSpell, BOOKTYPE_SPELL, "target")
        -- Unknown range is not evidence that the target is out of range.
        if inRange == 0 then
            lines[#lines + 1] = "|cffff4444TOO FAR AWAY|r"
        end
    end
    return table.concat(lines, "\n")
end

local function UpdateWarnings()
    if not db then return end
    local now = GetTime()
    if unlocked then
        text:SetText("|cffff4444NOT AUTO ATTACKING|r\n|cffffaa00Drag to move - /mdps lock|r")
        return
    end
    if now < testUntil then
        text:SetText("|cffff4444NOT AUTO ATTACKING|r\n|cffff4444TOO FAR AWAY|r\n|cffffaa00FACING THE WRONG WAY|r")
        return
    end
    local message = Warning(now)
    if message ~= pending then
        pending, pendingSince = message, now
    end
    local shown = ""
    if message == "" or now - pendingSince < db.delay then
        shown = ""
    else
        shown = message
    end
    -- Facing is event driven and bypasses the delay for other warnings.
    if now < facingUntil and facingGUID == UnitGUID("target") and ValidTarget() then
        if shown ~= "" then shown = shown .. "\n" end
        shown = shown .. "|cffffaa00FACING THE WRONG WAY|r"
    end
    text:SetText(shown)
    if shown ~= "" and db.sound and now - lastSound >= 4 then
        PlaySound(8959, "Master")
        lastSound = now
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
        mDPSUptimeOptions.Initialize(db, function()
            locationAllowed = mDPSUptimeOptions.LocationAllowed()
            pending, pendingSince, facingUntil, facingGUID = "", GetTime(), 0, nil
            if not unlocked and GetTime() >= testUntil then text:SetText("") end
        end)
        locationAllowed = mDPSUptimeOptions.LocationAllowed()
        Apply()
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
        pending, pendingSince, facingUntil, facingGUID = "", GetTime(), 0, nil
        if not unlocked and GetTime() >= testUntil then text:SetText("") end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        facingUntil, facingGUID, pending = 0, nil, ""
        pendingSince = GetTime()
        if db and not unlocked and GetTime() >= testUntil then text:SetText("") end
    elseif event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        if db and db.enabled and locationAllowed and message == ERR_BADATTACKFACING
            and UnitAffectingCombat("player") and ValidTarget() then
            facingUntil, facingGUID = GetTime() + 2.5, UnitGUID("target")
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
        Print("Warning delay: " .. db.delay .. " seconds.")
    elseif cmd == "sound" then
        db.sound = not db.sound
        Print("Sound " .. (db.sound and "on." or "off."))
    elseif cmd == "target" then
        db.noTarget = not db.noTarget
        Print("No target warning " .. (db.noTarget and "on." or "off."))
    elseif cmd == "on" or cmd == "off" then
        db.enabled = cmd == "on"
        Print(db.enabled and "Enabled." or "Disabled.")
    elseif cmd == "reset" then
        for key, value in pairs(defaults) do db[key] = value end
        mDPSUptimeOptions.Reset()
        Apply(); Print("Settings reset.")
    else
        Print("/mdps config | test | unlock | lock | size 36 | delay 0.6 | sound | target | on | off | reset")
    end
end

