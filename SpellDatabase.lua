-- BuffForge SpellDatabase.lua
-- WoW Midnight (12.0) - ULTIMATE DATABASE
-- Includes:
--  • All Major & Minor Bursts
--  • Interrupts, Stuns, Hard CC
--  • Defensives, Immunities, Raid Utility
--  • NEW: Demon Hunter 'Devourer' Spec (Void/Ranged)
--
-- Types: BURST, OFFENSIVE_MINOR, DEFENSIVE, IMMUNITY, RAID_CD, HEAL_CD, INTERRUPT, STUN, CC

local DB = {

-- ==================================================
-- DEATH KNIGHT
-- ==================================================
-- [Interrupts & CC]
[47528] = { 
    class = "DEATHKNIGHT", spec = "ALL", type = "INTERRUPT", name = "Mind Freeze",
    talents = {{name = "Coldthirst", effect = "Successfully interrupting generates Runic Power."}}
},
[108194] = { class = "DEATHKNIGHT", spec = "ALL", type = "STUN", name = "Asphyxiate" },
[49576] = { class = "DEATHKNIGHT", spec = "ALL", type = "CC", name = "Death Grip" },
[207167] = { class = "DEATHKNIGHT", spec = "FROST", type = "CC", name = "Blinding Sleet" },
-- [Defensive & Utility]
[48707] = { class = "DEATHKNIGHT", spec = "ALL", buff_duration = 5, type = "DEFENSIVE", name = "Anti-Magic Shell" },
[48792] = { 
    class = "DEATHKNIGHT", spec = "ALL", buff_duration = 8, type = "DEFENSIVE", name = "Icebound Fortitude",
    talents = {
        -- {name = "Bloody Fortitude", effect = "Reduces CD by 3 sec on kill."}
    }
},
[51052] = { class = "DEATHKNIGHT", spec = "ALL", buff_duration = 10, type = "RAID_CD", name = "Anti-Magic Zone" },
[55233] = { class = "DEATHKNIGHT", spec = "BLOOD", buff_duration = 10, type = "DEFENSIVE", name = "Vampiric Blood" },
[49039] = { class = "DEATHKNIGHT", spec = "ALL", buff_duration = 10, type = "UTILITY", name = "Lichborne" },
-- [Offensive / Burst]
[51271] = { 
    class = "DEATHKNIGHT", spec = "FROST", buff_duration = 12, type = "BURST", name = "Pillar of Frost",
    talents = {
        {name = "The Long Winter", spell_id = 379056, effect = "Increases duration by 6 sec.", duration_bonus = 6},
        {name = "Icecap", effect = "Critical strikes reduce CD by 2 sec."},
        {name = "Rider of the Apocalypse", effect = "Summons Horsemen."}
    }
},
[47568] = { 
    class = "DEATHKNIGHT", spec = "FROST", buff_duration = 0, type = "BURST", name = "Empower Rune Weapon",
    talents = {{name = "Empower Rune Weapon", effect = "Grants 2 charges. cooldown 30 sec."}}
},
[49028] = { 
    class = "DEATHKNIGHT", spec = "BLOOD", buff_duration = 8, type = "BURST", name = "Dancing Rune Weapon",
    talents = {{name = "Crimson Rune Weapon", effect = "Bone Shield charges reduce CD by 5 sec."}}
},
[42650] = { 
    class = "DEATHKNIGHT", spec = "UNHOLY", buff_duration = 30, type = "BURST", name = "Army of the Dead",
    talents = {{name = "Army of the Damned", effect = "Death Coil reduces CD by 5 sec."}}
},
[275699] = { class = "DEATHKNIGHT", spec = "UNHOLY", buff_duration = 20, type = "BURST", name = "Apocalypse" },
[63560] = { class = "DEATHKNIGHT", spec = "UNHOLY", buff_duration = 20, type = "BURST", name = "Dark Transformation" },

-- ==================================================
-- DEMON HUNTER (Updated for Midnight 12.0)
-- ==================================================
-- [Interrupts & CC]
[183752] = { class = "DEMONHUNTER", spec = "ALL", type = "INTERRUPT", name = "Disrupt" },
[179057] = { class = "DEMONHUNTER", spec = "ALL", type = "STUN", name = "Chaos Nova" },
[217832] = { class = "DEMONHUNTER", spec = "ALL", type = "CC", name = "Imprison" },
[207684] = { class = "DEMONHUNTER", spec = "VENGEANCE", type = "CC", name = "Sigil of Misery" },
[202137] = { class = "DEMONHUNTER", spec = "VENGEANCE", type = "CC", name = "Sigil of Silence" },
-- [Defensive]
[198589] = { class = "DEMONHUNTER", spec = "HAVOC,DEVOURER", buff_duration = 10, type = "DEFENSIVE", name = "Blur" },
[196555] = { class = "DEMONHUNTER", spec = "HAVOC", buff_duration = 5, type = "IMMUNITY", name = "Netherwalk" },
[196718] = { class = "DEMONHUNTER", spec = "ALL", buff_duration = 8, type = "RAID_CD", name = "Darkness" },
[204021] = { class = "DEMONHUNTER", spec = "VENGEANCE", buff_duration = 8, type = "DEFENSIVE", name = "Fiery Brand" },
-- [Offensive / Burst]
[191427] = { 
    class = "DEMONHUNTER", spec = "HAVOC", buff_duration = 30, type = "BURST", name = "Metamorphosis",
    talents = {
        {name = "Chaotic Transformation", effect = "Resets Eye Beam/Blade Dance."},
        {name = "Cycle of Hatred", effect = "Blade Dance reduces CD by 3 sec."}
    }
},
[370965] = { class = "DEMONHUNTER", spec = "HAVOC", buff_duration = 6, type = "BURST", name = "The Hunt" },
[187827] = { 
    class = "DEMONHUNTER", spec = "VENGEANCE", buff_duration = 15, type = "BURST", name = "Metamorphosis (Tank)",
    talents = {{name = "Last Resort", effect = "Triggers automatically on death."}}
},
-- [NEW: DEVOURER SPEC - Void/Ranged]
[401000] = { 
    class = "DEMONHUNTER", spec = "DEVOURER", buff_duration = 20, type = "BURST", name = "Void Metamorphosis",
    talents = {{name = "Soul Glutton", effect = "Consuming souls extends duration."}}
},
[401005] = { 
    class = "DEMONHUNTER", spec = "DEVOURER", buff_duration = 5, type = "OFFENSIVE_MINOR", name = "Void Ray",
    talents = {{name = "Moment of Craving", effect = "Resets Reap cooldown."}}
},

-- ==================================================
-- DRUID
-- ==================================================
-- [Interrupts & CC]
[106839] = { class = "DRUID", spec = "FERAL,GUARDIAN,BALANCE", type = "INTERRUPT", name = "Skull Bash" },
[78675] = { class = "DRUID", spec = "BALANCE", type = "INTERRUPT", name = "Solar Beam" },
[5211] = { class = "DRUID", spec = "ALL", type = "STUN", name = "Mighty Bash" },
[33786] = { class = "DRUID", spec = "ALL", type = "CC", name = "Cyclone" },
[99] = { class = "DRUID", spec = "ALL", type = "CC", name = "Incapacitating Roar" },
-- [Defensive]
[22812] = { class = "DRUID", spec = "ALL", buff_duration = 12, type = "DEFENSIVE", name = "Barkskin" },
[61336] = { class = "DRUID", spec = "FERAL,GUARDIAN", buff_duration = 6, type = "DEFENSIVE", name = "Survival Instincts" },
[102342] = { class = "DRUID", spec = "RESTORATION", buff_duration = 12, type = "DEFENSIVE", name = "Ironbark" },
-- [Offensive / Burst]
[102543] = { class = "DRUID", spec = "FERAL", buff_duration = 30, type = "BURST", name = "Incarnation: King of the Jungle" },
[106951] = { class = "DRUID", spec = "FERAL", buff_duration = 15, type = "BURST", name = "Berserk" },
[102560] = { class = "DRUID", spec = "BALANCE", buff_duration = 30, type = "BURST", name = "Incarnation: Chosen of Elune" },
[194223] = { class = "DRUID", spec = "BALANCE", buff_duration = 20, type = "BURST", name = "Celestial Alignment" },
[391528] = { class = "DRUID", spec = "ALL", buff_duration = 4, type = "BURST", name = "Convoke the Spirits" },
[33891] = { class = "DRUID", spec = "RESTORATION", buff_duration = 30, type = "HEAL_CD", name = "Incarnation: Tree of Life" },
[740] = { class = "DRUID", spec = "RESTORATION", buff_duration = 8, type = "HEAL_CD", name = "Tranquility" },

-- ==================================================
-- EVOKER
-- ==================================================
-- [Interrupts & CC]
[351338] = { class = "EVOKER", spec = "ALL", type = "INTERRUPT", name = "Quell" },
[360806] = { class = "EVOKER", spec = "ALL", type = "CC", name = "Sleep Walk" },
[357214] = { class = "EVOKER", spec = "ALL", type = "CC", name = "Landslide" },
-- [Defensive]
[363916] = { class = "EVOKER", spec = "ALL", buff_duration = 12, type = "DEFENSIVE", name = "Obsidian Scales" },
[374227] = { class = "EVOKER", spec = "ALL", buff_duration = 8, type = "RAID_CD", name = "Zephyr" },
[358267] = { class = "EVOKER", spec = "ALL", buff_duration = 0, type = "UTILITY", name = "Hover" },
-- [Offensive / Burst]
[375087] = { 
    class = "EVOKER", spec = "DEVASTATION", buff_duration = 14, type = "BURST", name = "Dragonrage",
    talents = {{name = "Animosity", effect = "Empower spells extend duration."}}
},
[357210] = { class = "EVOKER", spec = "AUGMENTATION", buff_duration = 10, type = "BURST", name = "Prescience" },
[403631] = { 
    class = "EVOKER", spec = "AUGMENTATION", buff_duration = 10, type = "BURST", name = "Breath of Eons",
    talents = {{name = "Interconnected Threads", effect = "Spending Essence reduces CD."}}
},
[363534] = { class = "EVOKER", spec = "PRESERVATION", buff_duration = 0, type = "HEAL_CD", name = "Rewind" },

-- ==================================================
-- HUNTER
-- ==================================================
-- [Interrupts & CC]
[147362] = { class = "HUNTER", spec = "MARKSMANSHIP,BEASTMASTERY", type = "INTERRUPT", name = "Counter Shot" },
[187707] = { class = "HUNTER", spec = "SURVIVAL", type = "INTERRUPT", name = "Muzzle" },
[19577] = { class = "HUNTER", spec = "ALL", type = "STUN", name = "Intimidation" },
[187650] = { class = "HUNTER", spec = "ALL", type = "CC", name = "Freezing Trap" },
-- [Defensive]
[186265] = { class = "HUNTER", spec = "ALL", buff_duration = 8, type = "IMMUNITY", name = "Aspect of the Turtle" },
[109304] = { class = "HUNTER", spec = "ALL", buff_duration = 0, type = "DEFENSIVE", name = "Exhilaration" },
[53480] = { class = "HUNTER", spec = "ALL", buff_duration = 10, type = "DEFENSIVE", name = "Roar of Sacrifice" },
-- [Offensive / Burst]
[288613] = { 
    class = "HUNTER", spec = "MARKSMANSHIP", buff_duration = 15, type = "BURST", name = "Trueshot",
    talents = {{name = "Calling the Shots", effect = "Aimed Shot reduces CD by 2.5 sec."}}
},
[19574] = { 
    class = "HUNTER", spec = "BEASTMASTERY", buff_duration = 15, type = "BURST", name = "Bestial Wrath",
    talents = {{name = "Pack Leader", effect = "Kill Command reduces CD by 1 sec."}}
},
[360966] = { class = "HUNTER", spec = "SURVIVAL", buff_duration = 20, type = "BURST", name = "Coordinated Assault" },

-- ==================================================
-- MAGE
-- ==================================================
-- [Interrupts & CC]
[2139] = { class = "MAGE", spec = "ALL", type = "INTERRUPT", name = "Counterspell" },
[118] = { class = "MAGE", spec = "ALL", type = "CC", name = "Polymorph" },
[122] = { class = "MAGE", spec = "ALL", type = "CC", name = "Frost Nova" },
[31661] = { class = "MAGE", spec = "FIRE", type = "CC", name = "Dragon's Breath" },
-- [Defensive]
[45438] = { class = "MAGE", spec = "ALL", buff_duration = 10, type = "IMMUNITY", name = "Ice Block" },
[11426] = { class = "MAGE", spec = "ALL", buff_duration = 60, type = "DEFENSIVE", name = "Ice Barrier" },
[342245] = { class = "MAGE", spec = "ALL", buff_duration = 10, type = "UTILITY", name = "Alter Time" },
[80353] = { class = "MAGE", spec = "ALL", buff_duration = 40, type = "RAID_CD", name = "Time Warp" },
-- [Offensive / Burst]
[190319] = { 
    class = "MAGE", spec = "FIRE", buff_duration = 12, type = "BURST", name = "Combustion",
    talents = {
        {name = "Kindling", effect = "Reduces CD by flat 60 seconds."},
        {name = "Sunfury", effect = "Summons Phoenix."}
    }
},
[12472] = { 
    class = "MAGE", spec = "FROST", buff_duration = 20, type = "BURST", name = "Icy Veins",
    talents = {
        {name = "Thermal Void", spell_id = 155149, effect = "Increases duration by 5 sec.", duration_bonus = 5},
        {name = "Spellslinger", effect = "Splinters reduce CD by 0.5 sec."}
    }
},
[365350] = { class = "MAGE", spec = "ARCANE", buff_duration = 15, type = "BURST", name = "Arcane Surge" },
[321507] = { class = "MAGE", spec = "ARCANE", buff_duration = 12, type = "BURST", name = "Touch of the Magi" },

-- ==================================================
-- MONK
-- ==================================================
-- [Interrupts & CC]
[116705] = { class = "MONK", spec = "WINDWALKER,BREWMASTER", type = "INTERRUPT", name = "Spear Hand Strike" },
[119381] = { class = "MONK", spec = "ALL", type = "STUN", name = "Leg Sweep" },
[115078] = { class = "MONK", spec = "ALL", type = "CC", name = "Paralysis" },
[116844] = { class = "MONK", spec = "ALL", type = "CC", name = "Ring of Peace" },
-- [Defensive]
[115203] = { class = "MONK", spec = "ALL", buff_duration = 15, type = "DEFENSIVE", name = "Fortifying Brew" },
[122783] = { class = "MONK", spec = "ALL", buff_duration = 6, type = "DEFENSIVE", name = "Diffuse Magic" },
[122278] = { class = "MONK", spec = "ALL", buff_duration = 0, type = "DEFENSIVE", name = "Dampen Harm" },
[122470] = { class = "MONK", spec = "WINDWALKER", buff_duration = 10, type = "DEFENSIVE", name = "Touch of Karma" },
[116849] = { class = "MONK", spec = "MISTWEAVER", buff_duration = 12, type = "DEFENSIVE", name = "Life Cocoon" },
-- [Offensive / Burst]
[123904] = { class = "MONK", spec = "WINDWALKER", buff_duration = 24, type = "BURST", name = "Invoke Xuen, the White Tiger" },
[137639] = { class = "MONK", spec = "WINDWALKER", buff_duration = 15, type = "BURST", name = "Storm, Earth, and Fire" },
[152173] = { class = "MONK", spec = "WINDWALKER", buff_duration = 12, type = "BURST", name = "Serenity" },
[322118] = { class = "MONK", spec = "MISTWEAVER", buff_duration = 25, type = "HEAL_CD", name = "Invoke Yu'lon" },
[115310] = { class = "MONK", spec = "MISTWEAVER", buff_duration = 0, type = "HEAL_CD", name = "Revival" },

-- ==================================================
-- PALADIN
-- ==================================================
-- [Interrupts & CC]
[96231] = { class = "PALADIN", spec = "RETRIBUTION,PROTECTION", type = "INTERRUPT", name = "Rebuke" },
[853] = { class = "PALADIN", spec = "ALL", type = "STUN", name = "Hammer of Justice" },
[20066] = { class = "PALADIN", spec = "ALL", type = "CC", name = "Repentance" },
[115750] = { class = "PALADIN", spec = "ALL", type = "CC", name = "Blinding Light" },
-- [Defensive]
[642] = { 
    class = "PALADIN", spec = "ALL", buff_duration = 8, type = "IMMUNITY", name = "Divine Shield",
    talents = {{name = "Unbreakable Spirit", effect = "Reduces CD by 30%."}}
},
[1022] = { class = "PALADIN", spec = "ALL", buff_duration = 10, type = "IMMUNITY", name = "Blessing of Protection" },
[498] = { class = "PALADIN", spec = "RETRIBUTION,HOLY", buff_duration = 8, type = "DEFENSIVE", name = "Divine Protection" },
[31850] = { class = "PALADIN", spec = "PROTECTION", buff_duration = 8, type = "DEFENSIVE", name = "Ardent Defender" },
[86659] = { class = "PALADIN", spec = "PROTECTION", buff_duration = 8, type = "DEFENSIVE", name = "Guardian of Ancient Kings" },
[6940] = { class = "PALADIN", spec = "ALL", buff_duration = 12, type = "RAID_CD", name = "Blessing of Sacrifice" },
[31821] = { class = "PALADIN", spec = "HOLY", buff_duration = 8, type = "RAID_CD", name = "Aura Mastery" },
-- [Offensive / Burst]
[31884] = { 
    class = "PALADIN", spec = "ALL", buff_duration = 20, type = "BURST", name = "Avenging Wrath",
    talents = {
        {name = "Divine Wrath", spell_id = 455437, effect = "Increases duration by 3 sec.", duration_bonus = 3},
        {name = "Sanctified Wrath", effect = "Extends duration."}
    }
},
[231895] = { class = "PALADIN", spec = "RETRIBUTION", buff_duration = 25, type = "BURST", name = "Crusade" },
[304971] = { class = "PALADIN", spec = "ALL", buff_duration = 0, type = "BURST", name = "Divine Toll" },
[255937] = { class = "PALADIN", spec = "RETRIBUTION", buff_duration = 0, type = "BURST", name = "Wake of Ashes" },

-- ==================================================
-- PRIEST
-- ==================================================
-- [Interrupts & CC]
[15487] = { class = "PRIEST", spec = "SHADOW", type = "INTERRUPT", name = "Silence" },
[8122] = { class = "PRIEST", spec = "ALL", type = "CC", name = "Psychic Scream" },
[205369] = { class = "PRIEST", spec = "SHADOW", type = "STUN", name = "Mind Bomb" },
-- [Defensive]
[33206] = { class = "PRIEST", spec = "DISCIPLINE", buff_duration = 8, type = "DEFENSIVE", name = "Pain Suppression" },
[62618] = { class = "PRIEST", spec = "DISCIPLINE", buff_duration = 10, type = "RAID_CD", name = "Power Word: Barrier" },
[47788] = { class = "PRIEST", spec = "HOLY", buff_duration = 10, type = "DEFENSIVE", name = "Guardian Spirit" },
[64843] = { class = "PRIEST", spec = "HOLY", buff_duration = 8, type = "RAID_CD", name = "Divine Hymn" },
[19236] = { class = "PRIEST", spec = "ALL", buff_duration = 0, type = "DEFENSIVE", name = "Desperate Prayer" },
[47585] = { class = "PRIEST", spec = "SHADOW", buff_duration = 6, type = "DEFENSIVE", name = "Dispersion" },
-- [Offensive / Burst]
[10060] = { class = "PRIEST", spec = "ALL", buff_duration = 20, type = "BURST", name = "Power Infusion" },
[228260] = { class = "PRIEST", spec = "SHADOW", buff_duration = 15, type = "BURST", name = "Void Eruption" },
[391109] = { class = "PRIEST", spec = "SHADOW", buff_duration = 20, type = "BURST", name = "Dark Ascension" },
[200183] = { 
    class = "PRIEST", spec = "HOLY", buff_duration = 20, type = "HEAL_CD", name = "Apotheosis",
    talents = {{name = "Light of the Naaru", effect = "Holy Words reduce CD."}}
},
[47536] = { class = "PRIEST", spec = "DISCIPLINE", buff_duration = 8, type = "HEAL_CD", name = "Rapture" },

-- ==================================================
-- ROGUE
-- ==================================================
-- [Interrupts & CC]
[1766] = { class = "ROGUE", spec = "ALL", type = "INTERRUPT", name = "Kick" },
[408] = { class = "ROGUE", spec = "ALL", type = "STUN", name = "Kidney Shot" },
[1833] = { class = "ROGUE", spec = "ALL", type = "STUN", name = "Cheap Shot" },
[2094] = { class = "ROGUE", spec = "ALL", type = "CC", name = "Blind" },
[6770] = { class = "ROGUE", spec = "ALL", type = "CC", name = "Sap" },
-- [Defensive]
[31224] = { class = "ROGUE", spec = "ALL", buff_duration = 5, type = "IMMUNITY", name = "Cloak of Shadows" },
[5277] = { class = "ROGUE", spec = "ALL", buff_duration = 10, type = "DEFENSIVE", name = "Evasion" },
[1966] = { class = "ROGUE", spec = "ALL", buff_duration = 6, type = "DEFENSIVE", name = "Feint" },
[1856] = { class = "ROGUE", spec = "ALL", buff_duration = 0, type = "DEFENSIVE", name = "Vanish" },
[185311] = { class = "ROGUE", spec = "ALL", buff_duration = 0, type = "DEFENSIVE", name = "Crimson Vial" },
-- [Offensive / Burst]
[360194] = { 
    class = "ROGUE", spec = "ASSASSINATION", buff_duration = 16, type = "BURST", name = "Deathmark",
    talents = {{name = "Deathstalker", effect = "Explodes on expiration."}}
},
[13750] = { 
    class = "ROGUE", spec = "OUTLAW", buff_duration = 20, type = "BURST", name = "Adrenaline Rush",
    talents = {{name = "Restless Blades", effect = "Finishers reduce CD by 1s per CP."}}
},
[121471] = { 
    class = "ROGUE", spec = "SUBTLETY", buff_duration = 20, type = "BURST", name = "Shadow Blades",
    talents = {{name = "Deepening Shadows", effect = "Finishers reduce CD by 1s per CP."}}
},
[185422] = { class = "ROGUE", spec = "SUBTLETY", buff_duration = 0, type = "BURST", name = "Shadow Dance" },

-- ==================================================
-- SHAMAN
-- ==================================================
-- [Interrupts & CC]
[57994] = { class = "SHAMAN", spec = "ALL", type = "INTERRUPT", name = "Wind Shear" },
[118905] = { class = "SHAMAN", spec = "ALL", type = "STUN", name = "Capacitor Totem" },
[51514] = { class = "SHAMAN", spec = "ALL", type = "CC", name = "Hex" },
-- [Defensive]
[108271] = { class = "SHAMAN", spec = "ALL", buff_duration = 8, type = "DEFENSIVE", name = "Astral Shift" },
[98008] = { class = "SHAMAN", spec = "RESTORATION", buff_duration = 6, type = "RAID_CD", name = "Spirit Link Totem" },
[8143] = { class = "SHAMAN", spec = "ALL", buff_duration = 10, type = "UTILITY", name = "Tremor Totem" },
[2825] = { class = "SHAMAN", spec = "ALL", buff_duration = 40, type = "RAID_CD", name = "Bloodlust" },
-- [Offensive / Burst]
[114050] = { 
    class = "SHAMAN", spec = "ALL", buff_duration = 15, type = "BURST", name = "Ascendance",
    talents = {
        {name = "Preeminence", spell_id = 443450, effect = "Increases duration by 3 sec.", duration_bonus = 3},
        {name = "Deeply Rooted Elements", effect = "Chance to trigger randomly."}
    }
},
[375982] = { class = "SHAMAN", spec = "ELEMENTAL", buff_duration = 15, type = "BURST", name = "Primordial Wave" },
[198067] = { 
    class = "SHAMAN", spec = "ELEMENTAL", buff_duration = 30, type = "BURST", name = "Fire Elemental",
    talents = {{name = "Skybreaker's Fiery Demise", effect = "Flame Shock crits reduce CD."}}
},
[51533] = { class = "SHAMAN", spec = "ENHANCEMENT", buff_duration = 15, type = "BURST", name = "Feral Spirit" },

-- ==================================================
-- WARLOCK
-- ==================================================
-- [Interrupts & CC]
[19647] = { class = "WARLOCK", spec = "ALL", type = "INTERRUPT", name = "Spell Lock" },
[6789] = { class = "WARLOCK", spec = "ALL", type = "CC", name = "Mortal Coil" },
[30283] = { class = "WARLOCK", spec = "ALL", type = "STUN", name = "Shadowfury" },
[5782] = { class = "WARLOCK", spec = "ALL", type = "CC", name = "Fear" },
[710] = { class = "WARLOCK", spec = "ALL", type = "CC", name = "Banish" },
-- [Defensive]
[104773] = { class = "WARLOCK", spec = "ALL", buff_duration = 8, type = "DEFENSIVE", name = "Unending Resolve" },
[108416] = { class = "WARLOCK", spec = "ALL", buff_duration = 20, type = "DEFENSIVE", name = "Dark Pact" },
-- [Offensive / Burst]
[265187] = { class = "WARLOCK", spec = "DEMONOLOGY", buff_duration = 15, type = "BURST", name = "Summon Demonic Tyrant" },
[1122] = { 
    class = "WARLOCK", spec = "DESTRUCTION", buff_duration = 30, type = "BURST", name = "Summon Infernal",
    talents = {{name = "Rain of Chaos", effect = "Spawns extra Infernals."}}
},
[205180] = { class = "WARLOCK", spec = "AFFLICTION", buff_duration = 20, type = "BURST", name = "Summon Darkglare" },

-- ==================================================
-- WARRIOR
-- ==================================================
-- [Interrupts & CC]
[6552] = { class = "WARRIOR", spec = "ALL", type = "INTERRUPT", name = "Pummel" },
[107570] = { class = "WARRIOR", spec = "ALL", type = "STUN", name = "Storm Bolt" },
[46968] = { class = "WARRIOR", spec = "PROTECTION", type = "STUN", name = "Shockwave" },
[5246] = { class = "WARRIOR", spec = "ALL", type = "CC", name = "Intimidating Shout" },
-- [Defensive]
[871] = { class = "WARRIOR", spec = "PROTECTION", buff_duration = 8, type = "DEFENSIVE", name = "Shield Wall" },
[12975] = { class = "WARRIOR", spec = "PROTECTION", buff_duration = 20, type = "DEFENSIVE", name = "Last Stand" },
[118038] = { class = "WARRIOR", spec = "ARMS", buff_duration = 8, type = "DEFENSIVE", name = "Die by the Sword" },
[184364] = { class = "WARRIOR", spec = "FURY", buff_duration = 8, type = "DEFENSIVE", name = "Enraged Regeneration" },
[97462] = { class = "WARRIOR", spec = "ALL", buff_duration = 10, type = "RAID_CD", name = "Rallying Cry" },
[23920] = { class = "WARRIOR", spec = "ALL", buff_duration = 5, type = "DEFENSIVE", name = "Spell Reflection" },
-- [Offensive / Burst]
[1719] = { 
    class = "WARRIOR", spec = "FURY", buff_duration = 12, type = "BURST", name = "Recklessness",
    talents = {{name = "Anger Management", effect = "Every 20 Rage spent reduces CD by 1 sec."}}
},
[107574] = { 
    class = "WARRIOR", spec = "PROTECTION,ARMS,FURY", buff_duration = 20, type = "BURST", name = "Avatar",
    talents = {
        {name = "Anger Management", effect = "Every 20 Rage spent reduces CD by 1 sec."},
        {name = "Mountain Thane", effect = "Thunder Clap reduces CD by 1 sec."}
    }
},
[227847] = { class = "WARRIOR", spec = "ARMS", buff_duration = 6, type = "BURST", name = "Bladestorm" },

}

-- ==================================================
-- GLOBAL API
-- ==================================================
BuffForge_SpellDB = {}

function BuffForge_SpellDB:GetSpell(spellID)
    return DB[spellID]
end

function BuffForge_SpellDB:GetClassSpells(className)
    local result = {}
    for id, data in pairs(DB) do
        if data.class == className then
            result[id] = data
        end
    end
    return result
end

function BuffForge_SpellDB:GetSpecSpells(className, specName)
    local result = {}
    for id, data in pairs(DB) do
        if data.class == className then
            -- Check if spec matches or is "ALL"
            if data.spec == "ALL" or (specName and data.spec:find(specName)) then
                result[id] = data
            end
        end
    end
    return result
end

function BuffForge_SpellDB:GetSpellsByType(spellType)
    local result = {}
    for id, data in pairs(DB) do
        if data.type == spellType then
            result[id] = data
        end
    end
    return result
end

function BuffForge_SpellDB:GetAll()
    return DB
end

function BuffForge_SpellDB:PrintAll()
    print("BuffForge Ultimate Spell Database (Midnight 12.0):")
    for id, data in pairs(DB) do
        local buffText = data.buff_duration and string.format(" | Buff: %ds", data.buff_duration) or ""
        print(string.format("[%d] %s (%s)%s - %s", 
            id, data.name, data.class, buffText, data.type))
    end
end

print("|cff00ff00BuffForge:|r Ultimate SpellDatabase loaded (Midnight 12.0)")
