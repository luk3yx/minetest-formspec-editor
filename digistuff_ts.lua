--
-- Formspec AST to digistuff touchscreen converter
--
-- Copyright © 2020 by luk3yx.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--

local basic_types = {}
for _, t in ipairs({'image', 'field', 'pwdfield', 'textarea', 'label',
        'vertlabel', 'button', 'button_exit'}) do
    basic_types[t] = true
end

local function export(tree, backport_func)
    tree = formspec_ast.flatten(tree)

    -- Modify box nodes before calling backport_func() to fix alignment
    for node in formspec_ast.find(tree, 'box') do
        -- Boxes can be partially emulated with images.
        node.type = 'image'
        node.texture_name = 'halo.png^[colorize:' .. node.color
        node.color = nil
    end

    if backport_func then
        tree = backport_func(tree)
    end

    local fs_v2 = (tree.formspec_version or 1) >= 2
    tree.formspec_version = nil
    if tree[1] and tree[1].type == 'size' then
        table.remove(tree, 1)
    end
    for _, node in ipairs(tree) do
        if node.type == 'dropdown' or node.type == 'textlist' then
            node.selected_id, node.selected_idx = node.selected_idx, nil
            node.choices, node.item = node.item, nil
            -- Later versions of the digustuff mod require a height field even
            -- for formspec version 1.
            node.h = node.h or 0.81
        elseif node.type == 'image_button' or
                node.type == 'image_button_exit' then
            node.image, node.texture_name = node.texture_name, nil
        elseif not basic_types[node.type] then
            return nil, 'Unsupported node type: ' .. node.type
        end

        if not node.command then
            node.command = 'add' .. node.type
        end
        node.type = nil
        for _, i in ipairs({"x", "y", "w", "h"}) do
            if node[i] then
                node[i:upper()] = node[i]
                node[i] = nil
            end
        end
    end
    table.insert(tree, 1, {command = 'clear'})
    table.insert(tree, 2, {command = 'realcoordinates', enabled = fs_v2})
    return tree
end

local function very_basic_dump(obj)
    local obj_type = type(obj)
    if obj_type == 'string' then
        return ('%q'):format(obj)
    elseif obj_type ~= 'table' then
        return tostring(obj)
    end

    local t = {}
    for k, v in pairs(obj) do
        if type(k) ~= 'string' or not k:match('^[A-Za-z_]+$') then
            k = '[' .. very_basic_dump(k) .. ']'
        end
        local line = k .. ' = ' .. very_basic_dump(v)
        if k == 'command' then
            table.insert(t, 1, line)
        else
            table.insert(t, line)
        end
    end

    return '{' .. table.concat(t, ', ') .. '}'
end

local function export_string(...)
    local res, err = export(...)
    if not res then
        return nil, err
    end
    for k, v in ipairs(res) do
        res[k] = very_basic_dump(v)
    end
    return '{' .. table.concat(res, ',\n') .. '}'
end

return export, export_string
