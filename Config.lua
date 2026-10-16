mDPSUptimeOptions = {}
local options = mDPSUptimeOptions
local db, panel, refreshWarnings
local checks = {}
local alertRefresh = {}
local raids = {
    {409, "Molten Core"}, {249, "Onyxia's Lair"}, {469, "Blackwing Lair"},
    {309, "Zul'Gurub"}, {509, "Ruins of Ahn'Qiraj (AQ20)"},
    {531, "Temple of Ahn'Qiraj (AQ40)"}, {533, "Naxxramas"},
}
local dungeons = {
    {389, "Ragefire Chasm"}, {36, "The Deadmines"}, {43, "Wailing Caverns"},
    {33, "Shadowfang Keep"}, {34, "The Stockade"}, {48, "Blackfathom Deeps"},
    {90, "Gnomeregan"}, {47, "Razorfen Kraul"}, {189, "Scarlet Monastery (all wings)"},
    {129, "Razorfen Downs"}, {70, "Uldaman"}, {209, "Zul'Farrak"},
    {349, "Maraudon (all entrances)"}, {109, "The Sunken Temple"},
    {230, "Blackrock Depths"}, {229, "Blackrock Spire (Lower and Upper)"},
    {429, "Dire Maul (all wings)"}, {289, "Scholomance"}, {329, "Stratholme (both sides)"},
}
local known = {}
for _, list in ipairs({raids, dungeons}) do
    for _, entry in ipairs(list) do known[entry[1]] = true end
end

function options.Initialize(settings, callback)
    db, refreshWarnings = settings, callback
    if type(db.instances) ~= "table" then db.instances = {} end
    for id in pairs(known) do
        if type(db.instances[id]) ~= "boolean" then db.instances[id] = true end
    end
    for _, key in ipairs({"outside", "pvp", "otherInstances"}) do
        if type(db[key]) ~= "boolean" then db[key] = true end
    end
end

function options.LocationAllowed()
    local _, instanceType, _, _, _, _, _, id = GetInstanceInfo()
    if instanceType == "none" then return db.outside end
    if instanceType == "pvp" or instanceType == "arena" then return db.pvp end
    if known[id] then return db.instances[id] == true end
    return db.otherInstances
end

local function Refresh()
    for _, check in ipairs(checks) do check:SetChecked(check.read()) end
    for _, update in ipairs(alertRefresh) do update() end
    refreshWarnings()
end

function options.Reset()
    for id in pairs(known) do db.instances[id] = true end
    db.outside, db.pvp, db.otherInstances = true, true, true
    Refresh()
end

function options.Open()
    if not panel then
        panel = CreateFrame("Frame", "mDPSUptimeConfig", UIParent, "BasicFrameTemplateWithInset")
        panel:SetSize(760, 650)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel.TitleText:SetText("mDPS Uptime - Settings")
        tinsert(UISpecialFrames, "mDPSUptimeConfig")

        local function Label(parent, value, x, y, width, font)
            local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", x, y)
            label:SetWidth(width)
            label:SetJustifyH("LEFT")
            label:SetText(value)
            return label
        end
        local function Button(parent, label, x, y, width, action)
            local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            button:SetSize(width, 26)
            button:SetPoint("TOPLEFT", x, y)
            button:SetText(label)
            button:SetScript("OnClick", action)
            return button
        end
        local function Heading(parent, value, x, y, width)
            Label(parent, value, x, y, width, "GameFontNormal")
            local line = parent:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 0.82, 0, 0.18)
            line:SetPoint("TOPLEFT", x, y - 21)
            line:SetSize(width, 1)
        end
        local function Checkbox(parent, label, x, y, width, read, write, tooltip)
            local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", x, y)
            check:SetSize(20, 20)
            Label(check, label, 25, -3, width - 29, "GameFontHighlightSmall")
            check:SetHitRectInsets(0, -(width - 20), 0, 0)
            check.read = read
            check:SetScript("OnClick", function(self)
                write(self:GetChecked() == true)
                refreshWarnings()
            end)
            if tooltip then
                check:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(label)
                    GameTooltip:AddLine(tooltip, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                check:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            checks[#checks + 1] = check
        end
        local function Setting(parent, key, label, x, y, width, tooltip)
            Checkbox(parent, label, x, y, width,
                function() return db[key] end, function(value) db[key] = value end, tooltip)
        end

        local general = CreateFrame("Frame", nil, panel)
        general:SetPoint("TOPLEFT", 24, -112)
        general:SetSize(712, 470)
        local locations = CreateFrame("Frame", nil, panel)
        locations:SetAllPoints(general)
        local alerts = CreateFrame("Frame", nil, panel)
        alerts:SetAllPoints(general)
        local generalTab, locationsTab, alertsTab
        local function SelectPage(which)
            general:SetShown(which == "general")
            locations:SetShown(which == "locations")
            alerts:SetShown(which == "alerts")
            generalTab:SetEnabled(which ~= "general")
            locationsTab:SetEnabled(which ~= "locations")
            alertsTab:SetEnabled(which ~= "alerts")
        end
        generalTab = Button(panel, "General", 24, -40, 130, function() SelectPage("general") end)
        locationsTab = Button(panel, "Locations", 162, -40, 130, function() SelectPage("locations") end)
        alertsTab = Button(panel, "Alerts", 300, -40, 130, function() SelectPage("alerts") end)
        Label(panel, "Changes save immediately. Hover over an option for details.", 26, -80, 700)

        Heading(general, "Combat warnings", 0, 0, 700)
        Setting(general, "enabled", "Enable mDPS Uptime", 0, -32, 650,
            "Master switch for combat warnings and native error suppression.")
        Setting(general, "sound", "Play warning sounds", 0, -64, 650,
            "Play a sound when an addon warning is displayed, at most once every four seconds.")
        Setting(general, "noTarget", "Warn when no target is selected", 0, -96, 650,
            "Show NO TARGET while in combat without a selected target.")

        Heading(general, "Hide built-in error text", 0, -164, 700)
        Label(general, "Keep the large addon warnings while hiding duplicate client text.", 2, -195, 690)
        Setting(general, "suppressFacing", "Hide: You are facing the wrong way", 0, -223, 650,
            "Suppress the native facing error. The addon's large facing warning remains enabled.")
        Setting(general, "suppressRange", "Hide: You are too far away", 0, -255, 650,
            "Suppress native range errors. The addon's large range warning remains enabled.")
        Label(general, "Applies only in combat, with a living hostile target, in an enabled location.\nNative errors can still appear before combat starts.", 2, -293, 690)

        Heading(general, "Display", 0, -360, 700)
        Label(general, "Use Preview below to test the warnings. Move text unlocks the display;\nwhen finished, type /mdps lock. Change text size with /mdps size 36.", 2, -393, 690)

        Heading(alerts, "Warning delays and beep sounds", 0, 0, 700)
        Label(alerts, "Each delay runs independently. Zero means immediate.\nEnable Play warning sounds on General for combat beeps; Listen always previews.", 2, -31, 690)
        local soundNames = {[0] = "Silent", "Low beep", "High beep", "Double beep", "Triple beep"}
        for index, entry in ipairs({{"attack", "Not auto attacking"}, {"range", "Too far away"},
            {"facing", "Facing the wrong way"}, {"target", "No target"}}) do
            local key, title = entry[1], entry[2]
            local y = -91 - (index - 1) * 89
            Label(alerts, title, 2, y, 290, "GameFontNormal")
            local valueText = Label(alerts, "", 2, y - 25, 190)
            local slider = CreateFrame("Slider", nil, alerts, "OptionsSliderTemplate")
            slider:SetPoint("TOPLEFT", 192, y - 25)
            slider:SetSize(240, 18)
            slider:SetMinMaxValues(0, 3)
            slider:SetValueStep(0.1)
            slider:SetObeyStepOnDrag(true)
            if slider.Low then slider.Low:SetText("0 s") end
            if slider.High then slider.High:SetText("3 s") end
            local soundButton
            local function UpdateRow()
                slider:SetValue(db.alertDelays[key])
                valueText:SetText(string.format("Delay: %.1f seconds", db.alertDelays[key]))
                soundButton:SetText(soundNames[db.alertSounds[key]])
            end
            soundButton = Button(alerts, "", 462, y - 20, 142, function()
                db.alertSounds[key] = (db.alertSounds[key] + 1) % 5
                UpdateRow()
            end)
            soundButton:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Click to choose the next beep")
                GameTooltip:AddLine("Silent, low, high, double, or triple beep.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            soundButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
            Button(alerts, "Listen", 612, y - 20, 88, function() mDPSUptimePlayBeep(db.alertSounds[key]) end)
            slider:SetScript("OnValueChanged", function(self, value)
                local rounded = math.floor(value * 10 + 0.5) / 10
                if db.alertDelays[key] ~= rounded then
                    db.alertDelays[key] = rounded
                    refreshWarnings()
                end
                valueText:SetText(string.format("Delay: %.1f seconds", rounded))
            end)
            alertRefresh[#alertRefresh + 1] = UpdateRow
        end
        Label(alerts, "Click a sound name to cycle choices. Active warnings repeat their beep every 4 seconds.\nFacing delay defaults to 0.0 seconds. The game must report a facing error first.", 2, -448, 700)

        local function Preset(mode)
            for id in pairs(known) do db.instances[id] = mode == "all" end
            if mode == "raids" then
                for _, entry in ipairs(raids) do db.instances[entry[1]] = true end
            end
            db.outside, db.pvp, db.otherInstances = mode == "all", mode == "all", mode == "all"
            Refresh()
        end
        Button(locations, "All locations", 0, 0, 130, function() Preset("all") end)
        Button(locations, "No locations", 138, 0, 130, function() Preset("none") end)
        Button(locations, "Raids only", 276, 0, 130, function() Preset("raids") end)
        Heading(locations, "Raids", 0, -46, 338)
        for index, entry in ipairs(raids) do
            local id = entry[1]
            Checkbox(locations, entry[2], 0, -73 - (index - 1) * 22, 338,
                function() return db.instances[id] end, function(value) db.instances[id] = value end)
        end
        Heading(locations, "Other locations", 0, -254, 338)
        Setting(locations, "outside", "Outside instances / world bosses", 0, -281, 338)
        Setting(locations, "pvp", "Battlegrounds and arenas", 0, -307, 338)
        Setting(locations, "otherInstances", "Other / unlisted instances", 0, -333, 338)
        Label(locations, "Checked locations enable combat warnings\nand the selected native error suppression.", 2, -383, 334)

        Heading(locations, "Dungeons", 362, -46, 338)
        for index, entry in ipairs(dungeons) do
            local id = entry[1]
            Checkbox(locations, entry[2], 362, -73 - (index - 1) * 20, 338,
                function() return db.instances[id] end, function(value) db.instances[id] = value end)
        end
        local divider = panel:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(1, 1, 1, 0.12)
        divider:SetPoint("BOTTOMLEFT", 24, 56)
        divider:SetSize(712, 1)
        Label(panel, "mDPS Uptime 1.2.0", 26, -612, 250)
        Button(panel, "Preview", 414, -605, 100, function() SlashCmdList.MDPSUPTIME("test") end)
        Button(panel, "Move text", 522, -605, 100, function()
            panel:Hide()
            SlashCmdList.MDPSUPTIME("unlock")
        end)
        Button(panel, "Done", 630, -605, 106, function() panel:Hide() end)
        SelectPage("general")
    end
    Refresh()
    panel:Show()
end
