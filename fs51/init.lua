--
-- Partially backport Minetest 5.1.0's real_coordinates[].
--
-- Copyright © 2019 by luk3yx.
--

fs51 = {}

local padding, spacing = 3/8, 5/4

-- Random offsets
local random_offsets = {
    -- box = {{0, 0}, {0.2, 0.125}},
    label = {{0, 0.3}},
    field = {{-padding, -0.33}, {-0.25, -0.2}},
    pwdfield = {{-padding, -0.33}, {-0.25, 0}},
    -- textarea = {{-0.3, -0.33}, {-0.2, 0}},
    textarea = {{-padding, 0}, {-0.25, -padding}},
    dropdown = {{0, 0}, {-0.25, 0}},
    checkbox = {{0, 0.5}},
}

local fixers = {}

-- This function feels rather brute forced
local function fix_pos(elem, random_offset)
    if type(elem.x) == 'number' and type(elem.y) == 'number' then
        if random_offset then
            elem.x = elem.x - random_offset[1][1]
            elem.y = elem.y - random_offset[1][2]
        end

        elem.x = (elem.x - padding) / spacing -- - 1
        elem.y = (elem.y - padding) / (spacing - 0.0965)
    end
end

local function default_fixer(elem)
    local random_offset = random_offsets[elem.type]
    fix_pos(elem, random_offset)

    if type(elem.w) == 'number' then
        if random_offset and random_offset[2] then
            elem.w = elem.w - random_offset[2][1]
        end
        elem.w = elem.w / spacing
    end

    if type(elem.h) == 'number' then
        if random_offset and random_offset[2] then
            elem.h = elem.h - random_offset[2][2]
        end
        elem.h = elem.h / (spacing - 0.0975)
    end
end

-- Other fixers
function fixers.image_button(elem)
    fix_pos(elem, random_offsets[elem.type])
    elem.w = elem.w * 0.8 + 0.205
    elem.h = elem.h * 0.866 + 0.134
end
fixers.item_image_button = fixers.image_button
fixers.image_button_exit = fixers.image_button

function fixers.textarea(elem)
    local h = elem.h
    default_fixer(elem)
    elem.h = h + 0.15
end

fixers.image = fix_pos
fixers.item_image = fixers.image

function fixers.button(elem)
    elem.type = 'image_' .. elem.type
    elem.texture_name = 'blank.png'
    return fixers.image_button(elem)
end
fixers.button_exit = fixers.button

function fixers.size(elem)
    elem.w = elem.w / spacing - padding * 2 + 0.36
    elem.h = elem.h / (spacing - 0.0975) - padding * 2
end

function fixers.list(elem, next_elem)
    fix_pos(elem)
    if elem.h < 2 then return end

    -- Split the list[] into multiple list[]s.
    local start = math.max(elem.starting_item_index or 0, 0)
    for row = 1, elem.h do
        local r = row - 1
        elem[row] = {
            type = 'list',
            inventory_location = elem.inventory_location,
            list_name = elem.list_name,
            x = 0,
            y = (r * 1.25) / (spacing - 0.0965),
            w = elem.w,
            h = 1,
            starting_item_index = start + (elem.w * r),
        }

        -- Swap the second element and any listring[]
        if row == 2 and next_elem and next_elem.type == 'listring' and
                not next_elem.inventory_location then
            for k, v in pairs(elem[2]) do
                next_elem[k] = v
            end
            next_elem.x = elem.x
            next_elem.y = elem.y + next_elem.y
            elem[2] = {type = 'listring'}
        end
    end

    -- Convert the base element to a container
    for k, v in pairs(elem) do
        if type(k) ~= 'number' and k ~= 'x' and k ~= 'y' then
            elem[k] = nil
        end
    end
    elem.type = 'container'
end

-- Remove the "height" attribute on dropdowns.
function fixers.dropdown(elem)
    elem.h = nil
    return default_fixer(elem)
end

--
local pre_types = {size = true, position = true, anchor = true,
                   no_prepend = true}
function fs51.backport(tree)
    -- Flatten the tree (this will also copy it).
    tree = formspec_ast.flatten(tree)
    local real_coordinates = type(tree.formspec_version) == 'number' and
        tree.formspec_version >= 2
    tree.formspec_version = 1

    -- Check for an initial real_coordinates[].
    if not real_coordinates then
        for _, elem in ipairs(tree) do
            if elem.type == 'real_coordinates' then
                real_coordinates = elem.bool
                break
            elseif not pre_types[elem.type] then
                break
            end
        end
    end

    -- Allow deletion of real_coordinates[]
    local i = 1
    while tree[i] ~= nil do
        local elem = tree[i]
        if elem.type == 'real_coordinates' then
            real_coordinates = elem.bool
            table.remove(tree, i)
            i = i - 1
        elseif elem.type == 'list' then
            fixers.list(elem, tree[i + 1])

            -- Flatten containers
            if elem.type == 'container' and elem[1] then
                formspec_ast.apply_offset(elem, elem.x, elem.y)
                tree[i] = elem[1]
                for j = 2, #elem do
                    i = i + 1
                    table.insert(tree, i, elem[j])
                end
            end
        elseif real_coordinates then
            (fixers[elem.type] or default_fixer)(elem)
        end
        i = i + 1
    end

    return tree
end

function fs51.backport_string(formspec)
    local fs, err = formspec_ast.parse(formspec)
    if not fs then
        minetest.log('warning', '[fs51] Error parsing formspec: ' ..
            tostring(err))
        return nil, err
    end
    return formspec_ast.unparse(fs51.backport(fs))
end

-- DEBUG
if not minetest then
    function b(fs)
        local tree, err = formspec_ast.parse(fs)
        if not tree then return tree, err end
        return formspec_ast.unparse(formspec_ast.backport(tree))
    end
end
