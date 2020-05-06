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
dofile('renderer.lua?rev=1')
local formspec_escape = formspec_ast.formspec_escape

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

local property_names = {
    h = 'Height',
    w = 'Width',
    drawborder = 'Draw border',
    item = 'Items',
    listelem = 'Items',
    selected_idx = 'Selected item',
}
local function get_property_name(n)
    return property_names[n] or n:sub(1, 1):upper() .. n:sub(2):gsub('_', ' ')
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
    local formspec = 'label[0.25,0.5;Properties for ' ..
        formspec_escape(node.type) .. ']'
    local y = 1.5
    for k, v in pairs(node) do
        if k == 'type' or k == '_transient' then goto continue end

        local value_type = type(v)
        if value_type == 'table' then
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
    end

    function callbacks.bring_to_front()
        local parent = elem.parentNode
        parent:removeChild(elem)
        parent:appendChild(elem)
    end

    local n = assert(renderer.render_formspec(formspec, callbacks,
        {store_json = false}))
    properties_elem:appendChild(n)
end
renderer.default_callback = show_properties

-- Templates for new elements
do
    local templates = assert(formspec_ast.parse([[
        size[10.5,11]
        box[0,0;1,1;]
        button[0,0;3,0.75;;]
        button_exit[0,0;3,0.75;;]
        checkbox[0,0.2;;;false]
        dropdown[0,0;3,0.75;;;1]
        field[0,0;3,0.75;;;]
        image[0,0;1,1;]
        image_button[0,0;2,2;;;;false;true;]
        image_button_exit[0,0;2,2;;;]
        label[0,0.2;]
        list[current_player;main;0,0;8,4;0]
        pwdfield[0,0;3,0.75;;]
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
local load_save_opts = {}
local function show_load_save_dialog()
    local callbacks = {}
    local formspec = [[
        formspec_version[2]size[6,9.5]button[0,0;1,0.6;back;←]
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
        button[0.25,7;5.5,1;load;Load formspec]
        button[0.25,8.25;5.5,1;save;Save formspec]
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

    function callbacks.save()
        get_options()
        local tree = renderer.elem_to_ast(element_dialog_base)
        local res, err = renderer.export(tree, load_save_opts)
        element_dialog.innerHTML = ''
        local fs = 'formspec_version[2]size[6,9.5]button[0,0;1,0.6;back;←]' ..
            'label[1.25,0.3;Save formspec]textarea[0.25,1.25;5.5,8;result;'
        if res then
            fs = fs ..
                'Formspec exported successfully.;' .. formspec_escape(res)
        else
            fs = fs ..
                'Error exporting formspec!;' .. formspec_escape(err)
        end
        fs = fs .. ']'
        render_into(element_dialog, fs, {
            back = show_load_save_dialog,
        })
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
    fs = fs .. 'button[0.25,' .. y + 1 .. ';5.5,0.75;load;Load / save formspec]'
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
    y = y + 2
    fs = 'formspec_version[2]size[6,' .. y .. ']' .. fs
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
