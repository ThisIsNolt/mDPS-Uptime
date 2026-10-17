mDPSUptimeMinimap = {}
local api = mDPSUptimeMinimap
local db, button
local dragging = false
local function Position()
    if not db or not button then return end
    local radians = math.rad(db.minimapAngle)
    local x, y = math.cos(radians), math.sin(radians)
    local halfWidth, halfHeight = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
    -- Square minimap replacements need an edge rather than a circular orbit.
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape ~= "ROUND" then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * (halfWidth + 8), y * (halfHeight + 8))
end
function api.Refresh()
    if not button or not db then return end
    button:SetShown(db.showMinimap)
    Position()
end
function api.Initialize(settings)
    db = settings
    if button then api.Refresh(); return end
    button = CreateFrame("Button", "mDPSUptimeMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetClampedToScreen(true)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("CENTER")
    icon:SetSize(23, 23)
    icon:SetTexture("Interface\\AddOns\\mDPSUptime\\Media\\Icon.tga")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            SlashCmdList.MDPSUPTIME("test")
        else
            mDPSUptimeOptions.Open()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("mDPS Uptime")
        GameTooltip:AddLine(db.enabled and "Enabled" or "Disabled", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: preview warnings", 1, 1, 1)
        GameTooltip:AddLine("Drag: move around the minimap", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function(self)
        dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
            Position()
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        dragging = false
        self:SetScript("OnUpdate", nil)
        Position()
    end)
    Minimap:HookScript("OnSizeChanged", Position)
    api.Refresh()
end
