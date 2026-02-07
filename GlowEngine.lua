--[[
    BuffForge Glow Engine
    Wrapper for LibCustomGlow-1.0 (Pixel, Autocast, Button)
]]

local addonName, addon = ...
addon.GlowEngine = {}
local Engine = addon.GlowEngine

-- Get Library
local LCG = LibStub("LibCustomGlow-1.0", true)

function Engine:Show(frame, type, color, freq)
    if not frame then return end
    
    -- Prevent redundant calls (Fixes stuttering/resetting animations)
    if frame._glowType == type then
        return
    end

    -- Clean existing glows if type changed
    self:Stop(frame)
    frame._glowType = type
    
    -- Default Color (Yellow/Gold)
    local r, g, b, a = 1, 1, 0, 1
    if color then
        r = color.r or color[1] or 1
        g = color.g or color[2] or 1
        b = color.b or color[3] or 0
        a = color.a or color[4] or 1
    end
    
    if not LCG then
        -- Library missing! Fallback to stop
        return
    end

    if type == "pixel" then
        -- color, N(8), freq(0.25=4s), length(nil), th(2), x, y
        LCG.PixelGlow_Start(frame, {r,g,b,a}, 8, 0.25, nil, 2)
    elseif type == "autocast" then
        -- color, N(4), freq(0.25=4s), scale(1)
        LCG.AutoCastGlow_Start(frame, {r,g,b,a}, 4, 0.25, 1)
    elseif type == "button" then
        -- color, freq(0.5=2s)
        LCG.ButtonGlow_Start(frame, {r,g,b,a}, 0.5)
    elseif type == "pulse" then
        self:Pulse(frame, 1.0, 1.2) -- Custom Pulse must stay custom
    end
end

function Engine:Stop(frame)
    if not frame then return end
    
    frame._glowType = nil
    
    if LCG then
        LCG.PixelGlow_Stop(frame)
        LCG.AutoCastGlow_Stop(frame)
        LCG.ButtonGlow_Stop(frame)
    end
-- Stop Custom Pulse
    if frame._pulseAnim then
        frame._pulseAnim:Stop()
        frame._pulseAnim = nil
    end
    
    -- Stop Manual Pulse Updater
    if frame._pulseUpdater then
        frame._pulseUpdater:SetScript("OnUpdate", nil)
        frame._pulseUpdater = nil
    end
    
    -- Reset Scale if Pulse modified it
    if frame._origScale then
        frame:SetScale(frame._origScale)
        frame._origScale = nil
    end
    
    -- Cleanup separate border anim if it exists (legacy fix cleanup)
    if frame.borderOverlay and frame.borderOverlay._pulseAnim then
        frame.borderOverlay._pulseAnim:Stop()
        frame.borderOverlay._pulseAnim = nil
    end
end

-- Custom Pulse (Library doesn't have this)
-- Using OnUpdate + SetScale to enforce inheritance on all children (Fixes border issues)
function Engine:Pulse(icon, duration, scale)
    if not icon then return end
    
    -- Ensure we target the Frame, not the Texture (fixes border/icon desync)
    if icon.GetObjectType and icon:GetObjectType() == "Texture" then
        icon = icon:GetParent()
    end

    if not duration then duration = 1 end
    if not scale then scale = 1.2 end
    
    -- Stop existing
    self:Stop(icon) 
    
    icon._origScale = icon:GetScale()
    local baseScale = icon._origScale
    local targetScale = baseScale * scale
    local startTime = GetTime()
    
    -- Create Animation Frame (Updater)
    local updater = CreateFrame("Frame", nil, icon)
    icon._pulseUpdater = updater
    
    updater:SetScript("OnUpdate", function(self, elapsed)
        if not icon or not icon:IsVisible() then
            Engine:Stop(icon)
            return
        end
        
        local now = GetTime()
        local timePassed = now - startTime
        
        -- Triangle Wave Calculation: 0 -> 1 -> 0 over duration
        -- Phase goes from 0 to 1
        local phase = (timePassed % duration) / duration
        
        -- Factor goes 0 -> 1 -> 0
        local factor = 0
        if phase < 0.5 then
            factor = phase * 2 -- 0 to 0.5 becomes 0to1
        else
            factor = (1 - phase) * 2 -- 0.5 to 1 becomes 1to0
        end
        
        -- Smooth interpolation (Quadratic Ease In/Out)
        -- factor = factor * factor * (3 - 2 * factor) 
        
        local currentScale = baseScale + (targetScale - baseScale) * factor
        icon:SetScale(currentScale)
    end)
end
