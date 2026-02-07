--[[
    BuffForge Glow Engine
    Wrapper for LibCustomGlow-1.0 (Pixel, Autocast, Button)
]]

local addonName, addon = ...
addon.GlowEngine = {}
local Engine = addon.GlowEngine

-- Get Library
local LCG = LibStub("LibCustomGlow-1.0", true)

-- Updated Show to accept 'options' table
function Engine:Show(frame, type, options)
    if not frame then return end
    
    options = options or {}
    
    -- SAFETY CLAMP: Frekansı ve hızı sınırla (0 olmasını ve sapıtmayı engeller)
    local safeFreq = math.max(0.1, options.freq or 0.25)
    local safeLines = options.lines or 8
    local safeThick = options.thickness or 2
    local safeScale = options.scale or 1
    local safeLength = options.length or 5
    
    -- CREATE SIGNATURE: Değer bazlı kontrol (Referans yerine içerik kontrolü)
    -- Bu sayede ayarlarla oynarken anlık değişimleri algılar.
    local color = options.color or {1, 1, 0, 1}
    local r, g, b, a = unpack(color)
    local colorSig = string.format("%.2f_%.2f_%.2f_%.2f", r, g, b, a)
    local signature = string.format("%s_%s_%.2f_%d_%d_%.2f_%d", 
        type, colorSig, safeFreq, safeLines, safeLength, safeScale, safeThick)
    
    -- Eğer tamamen aynı ayarlarla zaten çalışıyorsa, dokunma (Loop/Performans koruması)
    if frame._glowSig == signature then
        return
    end

    -- Değişiklik var! Eskiyi durdur, yeniyi başlat.
    self:Stop(frame)
    
    frame._glowSig = signature
    frame._glowType = type
    
    if not LCG then return end

    if type == "pixel" then
        -- Arg: frame, color, lines, freq, length, th, x, y, border, key
        LCG.PixelGlow_Start(frame, {r,g,b,a}, safeLines, safeFreq, safeLength, safeThick)
        
    elseif type == "autocast" then
        -- Arg: frame, color, particles, freq, scale, x, y, key
        LCG.AutoCastGlow_Start(frame, {r,g,b,a}, safeLines, safeFreq, safeScale)
        
    elseif type == "button" then
        -- Arg: frame, color, freq
        LCG.ButtonGlow_Start(frame, {r,g,b,a}, safeFreq)
        
    elseif type == "pulse" then
        -- Custom Alpha Pulse
        self:Pulse(frame, safeFreq) 
    end
end

function Engine:Stop(frame)
    if not frame then return end
    
    frame._glowSig = nil
    frame._glowType = nil
    
    if LCG then
        LCG.PixelGlow_Stop(frame)
        LCG.AutoCastGlow_Stop(frame)
        LCG.ButtonGlow_Stop(frame)
    end

    -- Stop Custom Pulse (Alpha)
    if frame.PulseAnimGroup then
        frame.PulseAnimGroup:Stop()
    end
    
    -- Reset Alpha
    frame:SetAlpha(1)
end

-- Custom Pulse (Alpha/Breathing Effect)
function Engine:Pulse(frame, duration)
    if not frame then return end
    
    if frame.GetObjectType and frame:GetObjectType() == "Texture" then
        frame = frame:GetParent()
    end

    if not frame.PulseAnimGroup then
        local ag = frame:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetOrder(1)
        a1:SetFromAlpha(1)
        a1:SetToAlpha(0.4) 
        a1:SetSmoothing("IN_OUT")
        
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetOrder(2)
        a2:SetFromAlpha(0.4)
        a2:SetToAlpha(1)
        a2:SetSmoothing("IN_OUT")
        
        frame.PulseAnimGroup = ag
        frame.PulseAnim1 = a1
        frame.PulseAnim2 = a2
    end
    
    -- Update Duration dynamically
    duration = math.max(0.2, duration or 1) -- Safety clamp
    local halfDur = duration / 2
    frame.PulseAnim1:SetDuration(halfDur)
    frame.PulseAnim2:SetDuration(halfDur)
    
    if not frame.PulseAnimGroup:IsPlaying() then
        frame.PulseAnimGroup:Play()
    end
end