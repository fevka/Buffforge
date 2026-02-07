-- =========================================================================
--  ForgeSerializer
--  A robust, zero-dependency serialization library for WoW Addons.
--  Safe string escaping and sandboxed deserialization.
-- =========================================================================

ForgeSerializer = {}

-- --- SERIALIZATION ---

local function SerializeValue(v)
    local t = type(v)
    if t == "number" then
        return tostring(v)
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "string" then
        return string.format("%q", v) -- Safely quotes string, handles escaping
    elseif t == "table" then
        return ForgeSerializer:Serialize(v)
    else
        return "nil"
    end
end

function ForgeSerializer:Serialize(tbl)
    local parts = {}
    table.insert(parts, "{")
    
    local first = true
    for k, v in pairs(tbl) do
        if not first then table.insert(parts, ",") end
        first = false
        
        -- Key
        if type(k) == "string" and string.match(k, "^[_%a][_%w]*$") then
            -- Simple key (e.g. name = "val")
            table.insert(parts, k .. "=")
        else
            -- Complex key (e.g. ["key space"] = "val", [1] = "val")
            table.insert(parts, "[" .. SerializeValue(k) .. "]=")
        end
        
        -- Value
        table.insert(parts, SerializeValue(v))
    end
    
    table.insert(parts, "}")
    return table.concat(parts)
end

-- --- DESERIALIZATION ---

function ForgeSerializer:Deserialize(str)
    if not str or str == "" then return nil end
    
    -- 1. Create a loadable chunk
    local f, err = loadstring("return " .. str)
    if not f then 
        return nil, "Syntax Error: " .. (err or "Unknown")
    end
    
    -- 2. Sandbox the environment for safety
    -- Create an empty environment so no globals (print, plain calls) can be accessed.
    local env = {} 
    setfenv(f, env)
    
    -- 3. Execute with protection
    local success, result = pcall(f)
    if not success then
        return nil, "Execution Error: " .. (result or "Unknown")
    end
    
    return result
end
