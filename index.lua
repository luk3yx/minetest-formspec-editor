--
-- Web-based formspec editor
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

-- Load the renderer
dofile('renderer.lua?rev=10')
local formspec_escape = formspec_ast.formspec_escape

local _, digistuff_ts_export = dofile('digistuff_ts.lua?rev=4')

-- Show the properties list
local properties_elem
local function get_properties_list(list_name)
    local res = {}
    local elems = properties_elem.firstChild.firstChild.children
    for i = 0, elems.length - 1 do
        local elem = elems[i]
        local name = elem:getAttribute('data-formspec_ast-name')
        if type(name) == 'string' and name:sub(1, 5) == 'list[' then
            local s, e = name:find(']', nil, true)
            local n = name:sub(e + 1)
            if n == list_name then
                res[tonumber(name:sub(6, s - 1))] = elem.lastChild.value
            end
        end
    end
    return res
end

local function get_properties_map(list_name)
    local keys = {}
    local values = {}
    local elems = properties_elem.firstChild.firstChild.children
    for i = 0, elems.length - 1 do
        local elem = elems[i]
        local name = elem:getAttribute('data-formspec_ast-name')
        if type(name) == 'string' then
            if name:sub(1, 5) == 'map1[' then
                local s, e = name:find(']', nil, true)
                local n = name:sub(e + 1)
                if n == list_name then
                    keys[tonumber(name:sub(6, s - 1))] = elem.lastChild.value
                end
            elseif name:sub(1, 5) == 'map2[' then
                local s, e = name:find(']', nil, true)
                local n = name:sub(e + 1)
                if n == list_name then
                    values[tonumber(name:sub(6, s - 1))] = elem.lastChild.value
                end
            end
        end
    end
    local res = {}
    for i, key in ipairs(keys) do
        res[key] = assert(values[i])
    end
    return res
end

local property_names = {
    h = 'Height',
    w = 'Width',
    drawborder = 'Draw border',
    listelems = 'Items',
    selected_idx = 'Selected item',
    props = 'Properties',
    opt = 'Options',
}
local function get_property_name(n)
    return property_names[n] or n:sub(1, 1):upper() .. n:sub(2):gsub('_', ' ')
end

local function draw_elements_list(selected_element)
    local formspec = 'label[0.25,0.5;Selected element]' ..
                     'dropdown[0.25,1;5.5,0.75;selected_element;'
    local selected = 0
    local elems = selected_element.parentElement.children
    local rendered_elems = 0
    for i = 0, elems.length - 1 do
        local elem = elems[i]
        if elem:getAttribute('data-transient') == 'true' then
            goto continue
        end
        if rendered_elems > 0 then
            formspec = formspec .. ','
        end
        rendered_elems = rendered_elems + 1
        formspec = formspec .. formspec_escape(elem:getAttribute('data-type'))
        if elem == selected_element then
            selected = rendered_elems
        end
        ::continue::
    end
    if selected == 0 then
        selected = rendered_elems + 1
        if rendered_elems > 0 then
            formspec = formspec .. ','
        end
        formspec = formspec .. '(New element)'
    end
    return formspec .. ';' .. selected .. ']'
end

local SCALE = 50
local function round_pos(pos)
    return math.floor(pos * 10 + 0.5) / 10
end

local function show_properties(elem, node)
    if not properties_elem then
        properties_elem = document:createElement('div')
        properties_elem.id = 'formspec_ast-properties'
        document.body:appendChild(properties_elem)
    end
    properties_elem.innerHTML = ''
    if type(node) ~= 'table' then
        node = nil
    end
    node = node or json.loads(elem:getAttribute('data-formspec_ast'))

    -- Why not do this as a formspec?
    local callbacks = {}
    local formspec = draw_elements_list(elem) ..
        'label[0.25,2.5;Properties for ' .. formspec_escape(node.type) .. ']'
    local y = 3.5
    for k_, v in pairs(node) do
        if k_ == 'type' or k_ == '_transient' then goto continue end

        local k = k_
        local value_type = type(v)
        if k == 'opt' or k == 'props' then
            assert(value_type == 'table')
            formspec = formspec .. 'label[0.25,' .. y - 0.2 .. ';' ..
                formspec_escape(get_property_name(k)) .. ' (map)]'
            y = y + 0.1
            local i = 0
            for prop_, value in pairs(v) do
                local prop = prop_
                i = i + 1
                formspec = formspec .. 'label[0.4,' .. y + 0.3 .. ';•]' ..
                    'field[0.7,' .. y .. ';1.95,0.6;' ..
                    formspec_escape('map1[' .. i .. ']' .. k) .. ';;' ..
                    formspec_escape(tostring(prop)) .. ']' ..
                    'label[2.7,' .. y + 0.3 .. ';=]' ..
                    'field[2.95,' .. y .. ';2,0.6;' ..
                    formspec_escape('map2[' .. i .. ']' .. k) .. ';;' ..
                    formspec_escape(tostring(value)) .. ']' ..
                    'button[5.15,' .. y .. ';0.6,0.6;' ..
                    formspec_escape('map-' .. i .. ':' .. k) .. ';X]'
                y = y + 0.8

                callbacks['map-' .. i .. ':' .. k] = function()
                    node[k] = get_properties_map(k)
                    node[k][prop] = nil
                    show_properties(elem, node)
                end
            end
            formspec = formspec .. 'button[0.25,' .. y .. ';5.5,0.6;' ..
                formspec_escape('props+' .. k) .. ';Add item]'
            callbacks['props+' .. k] = function()
                node[k] = get_properties_map(k)
                node[k][''] = ''
                show_properties(elem, node)
            end
            y = y + 1.3
            goto continue
        elseif value_type == 'table' then
            -- This table generation code is bad, the entire properties
            -- formspec is redrawn when a table element is deleted/created,
            -- however the "reset" button works.
            formspec = formspec .. 'label[0.25,' .. y - 0.2 .. ';' ..
                formspec_escape(get_property_name(k)) .. ' (list)]'
            y = y + 0.1
            for i, item in ipairs(v) do
                formspec = formspec .. 'label[0.4,' .. y + 0.3 .. ';•]' ..
                    'field[0.7,' .. y .. ';4.25,0.6;' ..
                    formspec_escape('list[' .. i .. ']' .. k) .. ';;' ..
                    formspec_escape(tostring(item)) .. ']' ..
                    'button[5.15,' .. y .. ';0.6,0.6;' ..
                    formspec_escape('list-' .. i .. ':' .. k) .. ';X]'
                y = y + 0.8
                callbacks['list-' .. i .. ':' .. k] = function()
                    node[k] = get_properties_list(k)
                    table.remove(node[k], i)
                    show_properties(elem, node)
                end
            end
            formspec = formspec .. 'button[0.25,' .. y .. ';5.5,0.6;' ..
                formspec_escape('list+' .. k) .. ';Add item]'
            callbacks['list+' .. k] = function()
                node[k] = get_properties_list(k)
                table.insert(node[k], '')
                show_properties(elem, node)
            end
            y = y + 1.3
            goto continue
        end

        if value_type == 'boolean' then
            formspec = formspec .. 'checkbox[0.25,' .. y
            y = y + 0.8
        else
            formspec = formspec .. 'field[0.25,' .. y .. ';5.5,0.6'
            y = y + 1.1
        end
        formspec = formspec .. ';' .. formspec_escape('prop_' .. k) .. ';' ..
            formspec_escape(get_property_name(k) .. ' (' .. value_type .. ')')
            .. ';' .. formspec_escape(tostring(v)) .. ']'
        ::continue::
    end

    if node._transient then
        formspec = formspec ..
            'button[0.25,' .. y .. ';2.7,0.75;delete;Cancel]' ..
            'button[3.05,' .. y .. ';2.7,0.75;reset;Reset]'
        y = y + 0.85
    else
        formspec = formspec ..
            'button[0.25,' .. y .. ';2.7,0.75;send_to_back;Send to back]' ..
            'button[3.05,' .. y .. ';2.7,0.75;bring_to_front;Bring to front]' ..
            'button[0.25,' .. y + 0.85 .. ';2.7,0.75;delete;Delete element]' ..
            'button[3.05,' .. y + 0.85 .. ';2.7,0.75;reset;Reset]'
        y = y + 1.7
    end

    formspec = 'formspec_version[2]size[6,' .. y + 1.25 .. ']' .. formspec ..
        'button[0.25,' .. y.. ';5.5,1;save;'
    if node.type == 'size' then
        formspec = formspec .. 'Resize formspec'
    elseif node._transient then
        formspec = formspec .. 'Create element'
    else
        formspec = formspec .. 'Save changes'
    end
    formspec = formspec .. ']'

    function callbacks.delete()
        if js.global:confirm('Are you sure?') then
            elem.parentNode:removeChild(elem)
            properties_elem.innerHTML = ''
        end
    end

    function callbacks.reset()
        show_properties(elem)
    end

    function callbacks.save()
        local elems = properties_elem.firstChild.firstChild.children
        local keys = {}
        for i = 0, elems.length - 1 do
            local e = elems[i]
            local name = e:getAttribute('data-formspec_ast-name')
            local prefix = type(name) == 'string' and name:sub(1, 5)
            if prefix == 'prop_' then
                local k = name:sub(6)
                if type(node[k]) == 'string' then
                    node[k] = e.lastChild.value
                elseif type(node[k]) == 'number' then
                    -- Allow commas to be used as decimal points.
                    local raw = e.lastChild.value:gsub(',', '.')
                    node[k] = tonumber(raw) or node[k]
                elseif type(node[k]) == 'boolean' then
                    node[k] = e:getAttribute('data-checked') == 'true'
                end
            elseif prefix == 'list[' then
                local s = name:find(']', nil, true)
                local k = name:sub(s + 1)
                node[k][tonumber(name:sub(6, s - 1))] = e.lastChild.value
            elseif prefix == 'map1[' then
                local s = name:find(']', nil, true)
                local k = name:sub(s + 1)
                if not keys[k] then
                    keys[k] = {}
                    node[k] = {}
                end
                keys[k][tonumber(name:sub(6, s - 1))] = e.lastChild.value
            elseif prefix == 'map2[' then
                local s = name:find(']', nil, true)
                local k = name:sub(s + 1)
                local key = keys[k][tonumber(name:sub(6, s - 1))]
                node[k][key] = e.lastChild.value
            end
        end

        if node.type == 'image_button' and node.texture_name == '' then
            node.texture_name = 'blank.png'
        end

        node._transient = nil
        elem:setAttribute('data-formspec_ast', json.dumps(node))
        properties_elem.innerHTML = ''
        local base = elem.parentNode.parentNode
        assert(base.classList:contains('formspec_ast-base'))
        local idx = window.Array.prototype.indexOf(elem.parentNode.children,
            elem)
        base = renderer.redraw_formspec(base)
        if node.type == 'size' then
            renderer.add_element(base, 'size')
        elseif idx >= 0 then
            show_properties(base.firstChild.children[idx])
        end
    end

    function callbacks.send_to_back()
        local parent = elem.parentNode
        parent:removeChild(elem)
        parent:prepend(elem)
        show_properties(elem, node)
    end

    function callbacks.bring_to_front()
        local parent = elem.parentNode
        parent:removeChild(elem)
        parent:appendChild(elem)
        show_properties(elem, node)
    end

    local n = assert(renderer.render_formspec(formspec, callbacks,
        {store_json = false}))

    local elems = n.firstChild.children
    for i = 0, elems.length - 1 do
        local elem2 = elems[i]
        local name = elem2:getAttribute('data-formspec_ast-name')
        if name == 'selected_element' then
            elem2:addEventListener('change', function()
                local idx = elem2.firstChild.selectedIndex
                show_properties(elem.parentElement.children[idx])
            end)
            break
        end
    end

    properties_elem:appendChild(n)
end

-- Set up drag+drop. This is mostly done in JavaScript for performance.
function renderer.default_elem_hook(node, elem, scale)
    local basic_interact = js.global.basic_interact
    if not basic_interact then return show_properties end

    local draggable = node.x ~= nil and node.y ~= nil
    local resizable = node.w ~= nil and node.h ~= nil and node.type ~= "list"

    local small_resize_margin = false
    if resizable and (node.w * scale < 60 or node.h * scale < 60) then
        small_resize_margin = true
    end

    local orig_x, orig_y = node.x, node.y
    basic_interact:add(elem, draggable, resizable, function(_, x, y, w, h)
        local modified
        if draggable and x then
            node.x = round_pos(orig_x + x / SCALE)
            node.y = round_pos(orig_y + y / SCALE)
            modified = true
        end
        if resizable and w then
            node.w = round_pos(math.max(w / SCALE, 0.1))
            node.h = round_pos(math.max(h / SCALE, 0.1))
            modified = true
        end

        if modified then
            elem:setAttribute('data-formspec_ast', json.dumps(node))
            local idx = window.Array.prototype.indexOf(
                elem.parentNode.children, elem)
            local base = renderer.redraw_formspec(elem.parentNode.parentNode)
            if idx >= 0 then
                show_properties(base.firstChild.children[idx])
            end
        else
            show_properties(elem)
        end
    end, small_resize_margin)

    return true
end

-- Templates for new elements
do
    local templates = assert(formspec_ast.parse([[
        size[10.5,11]
        box[0,0;1,1;]
        button[0,0;3,0.8;;]
        button_exit[0,0;3,0.8;;]
        checkbox[0,0.2;;;false]
        dropdown[0,0;3,0.8;;;1;false]
        field[0,0;3,0.8;;;]
        image[0,0;1,1;]
        image_button[0,0;2,2;;;;false;true;]
        image_button_exit[0,0;2,2;;;]
        label[0,0.2;]
        list[current_player;main;0,0;8,4;0]
        pwdfield[0,0;3,0.8;;]
        textarea[0,0;3,2;;;]
        textlist[0,0;5,3;;;1;false]
    ]]))
    renderer.templates = {}
    for _, node in ipairs(templates) do
        renderer.templates[node.type] = node
    end
end

function renderer.add_element(base, node_type)
    local elem = base.firstChild.lastChild
    if elem == js.null or elem:getAttribute('data-transient') ~= 'true' then
        elem = renderer.make('div')
        elem.style.display = 'none'
        base.firstChild:appendChild(elem)
    end
    local template
    if node_type == 'size' then
        template = {
            type = 'size',
            w = tonumber(base:getAttribute('data-w')) or 0,
            h = tonumber(base:getAttribute('data-h')) or 0,
        }
    else
        template = assert(renderer.templates[node_type], 'Unknown node!')
    end
    template._transient = true
    elem:setAttribute('data-formspec_ast', json.dumps(template))
    elem:setAttribute('data-transient', 'true')
    show_properties(elem)
end

local element_dialog_base
do
    local replace_formspec = renderer.replace_formspec
    function renderer.replace_formspec(elem, ...)
        local new_elem, err = replace_formspec(elem, ...)
        if new_elem and element_dialog_base == elem then
            element_dialog_base = new_elem
        end
        return new_elem, err
    end
end

local function render_into(base, formspec, callbacks)
    base.innerHTML = ''
    base:appendChild(assert(renderer.render_formspec(formspec, callbacks,
        {store_json = false})))
end

local element_dialog
local load_save_opts = {multiline = true}
local function show_load_save_dialog()
    local callbacks = {}
    local formspec = [[
        formspec_version[4]size[6,12]button[0,0;1,0.6;back;←]
        label[1.25,0.3;Load / save formspec]
        checkbox[0.25,1.3;use_v1;Use formspec version 1;]] ..
            (load_save_opts.use_v1 and 'true' or 'false') .. [[]
        label[0.75,1.9;Use this if you need compatibility]
        label[0.75,2.3;with Minetest 5.0.1 or earlier.]
        label[0.75,3;This only works when saving.]
        checkbox[0.25,4;format;Convert ${...} to lua expressions;]] ..
            (load_save_opts.format and 'true' or 'false') .. [[]
        label[0.75,4.6;When this is enabled\, lua]
        label[0.75,5;expressions can be used inside]
        label[0.75,5.4;${...}. Formspec escaping is]
        label[0.75,5.8;handled automatically.]
        checkbox[0.25,6.8;multiline;One element per line;]] ..
            (load_save_opts.multiline and 'true' or 'false') .. [[]
        button[0.25,7.75;5.5,1;load;Load formspec]
        button[0.25,9;5.5,1;save;Save formspec]
        box[0,10.369;6,0.02;#aaa]
        button[0.25,10.75;5.5,1;digistuff_ts;WIP]] .. '\n' ..
            [[Export to digistuff touchscreen]
    ]]
    local function get_options()
        local elems = element_dialog.firstChild.firstChild.children
        for i = 0, #elems - 1 do
            local elem = elems[i]
            local name = elem:getAttribute('data-formspec_ast-name')
            local checked = elem:getAttribute('data-checked')
            if type(name) == 'string' and type(checked) == 'string' then
                load_save_opts[name] = checked == 'true'
            end
        end
    end

    function callbacks.back()
        get_options()
        renderer.show_element_dialog(element_dialog_base)
    end

    local function load()
        local textarea = element_dialog.firstChild.firstChild.lastChild
        local fs = textarea.lastChild.value
        local tree, err = renderer.import(fs, load_save_opts)
        if not tree then
            window:alert('Error loading formspec:\n' .. err)
            return
        end
        local elem
        elem, err = renderer.replace_formspec(element_dialog_base, tree)
        if not elem then
            window:alert('Error loading formspec:\n' .. err)
            return
        end
        renderer.show_element_dialog(element_dialog_base)
        if properties_elem then
            properties_elem.innerHTML = ''
        end
    end

    function callbacks.load()
        get_options()
        local fs = 'formspec_version[2]size[6,9.5]button[0,0;1,0.6;back;←]' ..
            'label[1.25,0.3;Load formspec]' ..
            'button[0.25,8.25;5.5,1;load;Load formspec]' ..
            'textarea[0.25,1.25;5.5,6.75;formspec;Paste your formspec here.;]'
        render_into(element_dialog, fs, {
            back = show_load_save_dialog,
            load = load
        })
    end

    local function save_dialog(name, res, err)
        element_dialog.innerHTML = ''
        local label, msg
        if res then
            label, msg = 'Formspec exported successfully.', res
        else
            label, msg = 'Error exporting formspec!', err
        end
        local fs = 'formspec_version[2]size[6,9.5]button[0,0;1,0.6;back;←]' ..
            'label[1.25,0.3;' .. name .. ']textarea[0.25,1.25;5.5,8;result;' ..
            label .. ';' .. formspec_escape(msg) .. ']'
        render_into(element_dialog, fs, {
            back = show_load_save_dialog,
        })
    end

    function callbacks.save()
        get_options()
        local tree = renderer.elem_to_ast(element_dialog_base)
        save_dialog('Save formspec', renderer.export(tree, load_save_opts))
    end

    function callbacks.digistuff_ts()
        get_options()
        local tree = renderer.elem_to_ast(element_dialog_base)
        local f = load_save_opts.use_v1 and renderer.fs51_backport or nil
        save_dialog('Export formspec', digistuff_ts_export(tree, f))
    end

    render_into(element_dialog, formspec, callbacks)
end

function renderer.show_element_dialog(base)
    element_dialog_base = base
    if not element_dialog then
        element_dialog = document:createElement('div')
        element_dialog.id = 'formspec_ast-new'
        document.body:appendChild(element_dialog)
    end
    element_dialog.innerHTML = ''

    local fs = 'label[0.25,0.5;Add elements]'
    local callbacks = {}
    local y = 1.25

    for name, def in pairs(renderer.templates) do
        fs = fs .. 'button[0.25,' .. y .. ';5.5,0.75;' ..
            formspec_escape('add_' .. name) .. ';' ..
            formspec_escape(formspec_ast.unparse({def})) .. ']'
        y = y + 1
        local node_type = name
        callbacks['add_' .. name] = function()
            renderer.add_element(element_dialog_base, node_type)
        end
    end
    y = y + 0.5
    fs = fs .. 'button[0.25,' .. y .. ';5.5,0.75;grid;Toggle grid]'
    y = y + 1
    fs = fs .. 'button[0.25,' .. y .. ';5.5,0.75;load;Load / save formspec]'
    function callbacks.grid()
        local raw = element_dialog_base:getAttribute('data-render-options')
        if raw == js.null then raw = '{}' end
        local options = json.loads(raw)
        options.grid = not options.grid
        raw = assert(json.dumps(options))
        element_dialog_base:setAttribute('data-render-options', raw)
        renderer.redraw_formspec(element_dialog_base)
        if properties_elem then
            properties_elem.innerHTML = ''
        end
    end
    callbacks.load = show_load_save_dialog

    if js.global.basic_interact then
        y = y + 1
        fs = fs .. 'button[0.25,' .. y ..
             ';5.5,0.75;drag_drop;Disable drag+drop]'
        function callbacks.drag_drop()
            window.location.search = '?no-drag-drop'
        end
    end

    fs = 'formspec_version[3]size[6,' .. y + 1 .. ']' .. fs
    element_dialog:appendChild(assert(renderer.render_formspec(fs, callbacks,
        {store_json = false})))
end

-- A JS API for testing
function window:render_formspec(fs, callbacks, options)
    local tree = assert(formspec_ast.parse(fs))
    local elem = assert(renderer.render_ast(tree, callbacks, options))
    local e = document:getElementById('formspec_output')
    if not e or e == js.null then
        window:addEventListener('load', function()
            window:render_formspec(fs, callbacks)
        end)
        return
    end
    e.innerHTML = ''
    e:appendChild(elem)
    renderer.show_element_dialog(elem)
end

function window:copy_formspec()
    local e = assert(document:getElementById('formspec_output')).firstChild
    window:alert(formspec_ast.unparse(renderer.elem_to_ast(e)))
end

function window:unrender_formspec(elem)
    return renderer.unrender_formspec(elem)
end

function window:redraw_formspec(elem)
    return renderer.redraw_formspec(elem)
end

function window:add_element(node_type)
    local e = assert(document:getElementById('formspec_output')).firstChild
    renderer.add_element(e, node_type)
end

function window:make_image(...)
    return renderer.make_image(...)
end

window:render_formspec('formspec_version[2]size[10.5,11]')
