local js = require 'js'
local JSON = js.global.JSON
local null = js.null
json = {}

-- Recursively convert JavaScript objects to tables.
local function object_to_table(obj, nullvalue)
    if obj == null then
        return nullvalue
    elseif type(obj) == 'number' then
        -- Cast to integer if possible
        local i = math.floor(obj)
        if i == obj then return i end
        return obj
    elseif type(obj) ~= 'userdata' then
        return obj
    end

    local res = {}
    local array = js.global.Array:isArray(obj)
    if array then obj:unshift(null) end
    for k, v in (array and ipairs or pairs)(obj) do
        res[k] = object_to_table(v, nullvalue)
    end
    return res
end

local function table_to_object(table)
    local array = true
    for k, v in pairs(table) do
        if type(k) ~= 'number' then
            array = false
            break
        end
    end

    if array then
        local res = js.global:Array()
        for _, elem in ipairs(table) do
            if type(elem) == 'table' then
                elem = table_to_object(elem)
            end
            res:push(elem)
        end
        return res
    else
        local res = js.global:Object()
        for k, v in pairs(table) do
            if type(v) == 'table' then
                v = table_to_object(v)
            end
            res[k] = v
        end
        return res
    end
end

-- Alias for JSON:parse so pcall can call it.
local function raw_parse(json, nullvalue)
    local obj = JSON:parse(json)
    return object_to_table(obj, nullvalue)
end

function json.loads(json, nullvalue)
    local success, result = pcall(raw_parse, json, nullvalue)
    if success then
        return result, nil
    else
        return nil, result
    end
end

json.loads = raw_parse

-- Another alias
local function raw_write(data, styled)
    if styled then styled = 4 else styled = nil end
    return JSON:stringify(data, nil, styled)
end

-- The un-parsing is was going to be done entirely in JavaScript, but lua.
function json.dumps(data, styled)
    if type(data) == 'table' then
        data = table_to_object(data)
    end

    local success, result = pcall(raw_write, data, styled)
    if success then
        return result, nil
    else
        return nil, result
    end
end
