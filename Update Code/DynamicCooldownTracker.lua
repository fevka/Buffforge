--[[
    DynamicCooldownTracker.lua
    
    This script implements "Smart Cooldown Tracking" for World of Warcraft.
    
    What makes it "Smart"?
    1. Event-Driven: Updates primarily on events (SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES) 
       rather than polling every frame, saving CPU.
    2. Dynamic Reduction: Automatically detects cooldown reductions (e.g., from talents/procs) 
       and resets instant resets (e.g., Preparation) by re-querying state immediately.
    3. Charge Awareness: Distinguishes between "On Cooldown" and "Recharging". 
       - If a spell has charges, it shows the recharge progress sweep even if the spell is usable.
       - Displays current charge count.
    
    Usage:
    local tracker = DynamicCooldownTracker:CreateTracker(parent, spellID)
]]

local addonName, addonTable = ...
local DynamicCooldownTracker = {}
_G.DynamicCooldownTracker = DynamicCooldownTracker

-- Modern API aliases
local GetTime = GetTime
local C_Spell = C_Spell

--[[
    Creates a frame that tracks the cooldown and charges of a specific spell.
]]
function DynamicCooldownTracker:CreateTracker(parent, spellID, size)
    size = size or 36

    -- Create the main button frame
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size, size)
    
    -- Icon texture
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    local iconTexture = spellInfo and spellInfo.iconID or 134400 -- Default "question mark"
    
    frame.icon = frame:CreateTexture(nil, "BACKGROUND")
    frame.icon:SetAllPoints()
    frame.icon:SetTexture(iconTexture)

    -- Cooldown Frame (swipe animation)
    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    
    -- Charge Count Text
    frame.count = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    frame.count:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.count:SetJustifyH("RIGHT")

    frame.spellID = spellID

    --[[
        Update Logic:
        Handles both standard cooldowns and charge-based cooldowns.
    ]]
    frame.isForced = false

    function frame:ForceCooldown(enable)
        self.isForced = enable
        if not enable then
            self:UpdateCooldown()
        end
    end

    --[[
        Update Logic:
        Handles both standard cooldowns and charge-based cooldowns.
    ]]
    function frame:UpdateCooldown()
        if self.isForced then return end

        local spellID = self.spellID
        local chargeInfo = C_Spell.GetSpellCharges(spellID)
        
        if chargeInfo then
            -- Spell has charges
            local currentCharges = chargeInfo.currentCharges
            local maxCharges = chargeInfo.maxCharges
            local cooldownStart = chargeInfo.cooldownStartTime
            local cooldownDuration = chargeInfo.cooldownDuration
            
            -- Update Charge Count Display
            local showCharges = false
            if maxCharges then
                -- Wrap comparison in pcall to handle potential "secret" values from C_Spell
                local success, result = pcall(function() return maxCharges > 1 end)
                if success then
                    showCharges = result
                else
                    -- If check fails (secret value), default to showing to ensure 2+ stacks are seen
                    showCharges = true 
                end
            end

            if showCharges then
                -- Protect SetText in case currentCharges is also secret
                local success = pcall(function() self.count:SetText(currentCharges) end)
                if not success then
                    self.count:SetText("")
                end
            else
                self.count:SetText("")
            end

            -- Update Swipe
            -- If we have charges left, the swipe shows the RECHARGE time for the next rune/charge.
            -- If we have 0 charges, it shows the time until 1 is available.
            -- API returns 0 start/duration if at max charges.
            pcall(function() self.cooldown:SetCooldown(cooldownStart, cooldownDuration) end)
            
        else
            -- Standard Spell (No charges)
            self.count:SetText("")
            local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
            
            if cooldownInfo then
                pcall(function() self.cooldown:SetCooldown(cooldownInfo.startTime, cooldownInfo.duration) end)
            end
        end
    end

    -- Event Handling
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("SPELL_UPDATE_CHARGES")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(self, event, ...)
        -- We update on any of these events.
        -- SPELL_UPDATE_CHARGES handles charge consumption/regen cases.
        -- SPELL_UPDATE_COOLDOWN handles standard CDs and resets.
        self:UpdateCooldown()
    end)
    
    -- Initial update
    frame:UpdateCooldown()

    return frame
end
