-- BuffForge ProcDatabase.lua
-- This is a standalone database for "Popup Buffs" (Procs) across various classes.
-- It maps the core ability/spell to its associated proc/aura.

local ProcDB = {
    -- ==================================================
    -- DEATH KNIGHT
    -- ==================================================
    ["DEATHKNIGHT"] = {
        { name = "Killing Machine", abilityID = 49020, procID = 51124, spec = "Frost" },
        { name = "Rime", abilityID = 49184, procID = 59052, spec = "Frost" },
        { name = "Sudden Doom", abilityID = 47541, procID = 81340, spec = "Unholy" },
        { name = "Crimson Scourge", abilityID = 50842, procID = 81141, spec = "Blood" }, -- Blood Boil free/reset
        { name = "Will of the Necropolis", abilityID = 49039, procID = 50138, spec = "Blood" }, -- Below 30% reduction
    },

    -- ==================================================
    -- PALADIN
    -- ==================================================
    ["PALADIN"] = {
        { name = "The Art of War", abilityID = 184575, procID = 59578, spec = "Retribution" },
        { name = "Shining Light", abilityID = 85673, procID = 327510, spec = "Protection" },
        { name = "Empyrean Power", abilityID = 53385, procID = 326719, spec = "Retribution" }, -- Free Divine Storm
        { name = "Grand Crusader", abilityID = 31935, procID = 85416, spec = "Protection" }, -- Shield of the Righteous resets Avenger's Shield
        { name = "Infusion of Light", abilityID = 19750, procID = 54149, spec = "Holy" }, -- Flash of Light / Judgement buff
    },

    -- ==================================================
    -- WARRIOR
    -- ==================================================
    ["WARRIOR"] = {
        { name = "Sudden Death", abilityID = 280735, procID = 52437, spec = "Arms, Fury" },
        { name = "Shield Slam Reset", abilityID = 23922, procID = 132404, spec = "Protection" }, -- Shield Block/etc resets Shield Slam
        { name = "Ultimatum", abilityID = 57755, procID = 122510, spec = "Protection" }, -- Next Heroic Strike free
    },

    -- ==================================================
    -- MAGE
    -- ==================================================
    ["MAGE"] = {
        { name = "Brain Freeze", abilityID = 190356, procID = 190447, spec = "Frost" },
        { name = "Fingers of Frost", abilityID = 30455, procID = 44544, spec = "Frost" },
        { name = "Hot Streak", abilityID = 11366, procID = 48108, spec = "Fire" }, -- Instant Pyroblast
        { name = "Heating Up", abilityID = 11366, procID = 48107, spec = "Fire" }, -- 1/2 crit for Pyroblast
        { name = "Clearcasting", abilityID = 5143, procID = 263725, spec = "Arcane" }, -- Arcane Missiles free
    },

    -- ==================================================
    -- SHAMAN
    -- ==================================================
    ["SHAMAN"] = {
        { name = "Lava Surge", abilityID = 51505, procID = 77762, spec = "Elemental" }, -- Lava Burst reset
        { name = "Maelstrom Weapon", abilityID = 187880, procID = 344179, spec = "Enhancement" }, -- Instant casts
        { name = "Stormbringer", abilityID = 17364, procID = 201846, spec = "Enhancement" }, -- Stormstrike reset
        { name = "Tidal Waves", abilityID = 1064, procID = 61295, spec = "Restoration" }, -- Faster Healing Wave/Surge
    },

    -- ==================================================
    -- DRUID
    -- ==================================================
    ["DRUID"] = {
        { name = "Owlkin Frenzy", abilityID = 190984, procID = 157302, spec = "Balance" }, -- Instant Starfire/Wrath
        { name = "Predator's Swiftness", abilityID = 5185, procID = 69369, spec = "Feral" }, -- Instant regrowth
        { name = "Clearcasting", abilityID = 1822, procID = 16870, spec = "Feral" }, -- Omen of Clarity
        { name = "Eclipse (Solar)", abilityID = 190984, procID = 48517, spec = "Balance" },
        { name = "Eclipse (Lunar)", abilityID = 197814, procID = 48518, spec = "Balance" },
    },

    -- ==================================================
    -- ROGUE
    -- ==================================================
    ["ROGUE"] = {
        { name = "Blindside", abilityID = 111240, procID = 121153, spec = "Assassination" }, -- Ambush useable
        { name = "Shadow Dance", abilityID = 185313, procID = 185422, spec = "Subtlety" }, -- Free cast mode
        { name = "Ace Up Your Sleeve", abilityID = 193315, procID = 271896, spec = "Outlaw" }, -- Free CP
    },

    -- ==================================================
    -- WARLOCK
    -- ==================================================
    ["WARLOCK"] = {
        { name = "Nightfall", abilityID = 686, procID = 108558, spec = "Affliction" }, -- Instant Shadow Bolt
        { name = "Molten Core", abilityID = 104312, procID = 122037, spec = "Demonology" }, -- Fast Demonbolt
        { name = "Backdraft", abilityID = 29722, procID = 117828, spec = "Destruction" }, -- Fast Bolt/Incinerate
    },

    -- ==================================================
    -- PRIEST
    -- ==================================================
    ["PRIEST"] = {
        { name = "Surge of Light", abilityID = 2061, procID = 114255, spec = "Holy" }, -- Flash of Light free
        { name = "Dark Thoughts", abilityID = 15407, procID = 344445, spec = "Shadow" }, -- Mind Blast while Mind Flay
    },

    -- ==================================================
    -- MONK
    -- ==================================================
    ["MONK"] = {
        { name = "Blackout Combo", abilityID = 10078, procID = 228563, spec = "Brewmaster" },
        { name = "Dance of Chi-Ji", abilityID = 101546, procID = 325201, spec = "Windwalker" }, -- Free Spinning Crane Kick
    }
}

-- Registry to make it accessible in the global environment
BuffForge_ProcDB = {}

function BuffForge_ProcDB:GetClassProcs(className)
    return ProcDB[className] or {}
end

function BuffForge_ProcDB:GetAll()
    return ProcDB
end

print("|cff00ffffBuffForge:|r Proc/Popup Database initialized (Standalone).")
