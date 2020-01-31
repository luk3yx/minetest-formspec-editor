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

-- Load formspec_ast
FORMSPEC_AST_PATH = 'formspec_ast'
dofile(FORMSPEC_AST_PATH .. '/init.lua')
local formspec_escape = formspec_ast.formspec_escape

-- Load fs51 to allow formspec_version[1] exports
FS51_PATH = 'fs51'
dofile(FS51_PATH .. '/init.lua')

-- Load the JSON interoperability code
dofile('json.lua')

local js = require 'js'
local window = js.global
local document = window.document

renderer = {}

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
            local k = k
            formspec = formspec .. 'label[0.25,' .. y - 0.2 .. ';' ..
                formspec_escape(k) .. ' (list)]'
            y = y + 0.1
            for i, item in ipairs(v) do
                formspec = formspec .. 'label[0.4,' .. y + 0.3 .. ';•]' ..
                    'field[0.7,' .. y .. ';4.25,0.6;' ..
                    formspec_escape('list[' .. i .. ']' .. k) .. ';;' ..
                    formspec_escape(tostring(item)) .. ']' ..
                    'button[5.15,' .. y .. ';0.6,0.6;' ..
                    formspec_escape('list-' .. i .. ':' .. k) .. ';X]'
                y = y + 0.8

                local i = i
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
            formspec_escape(k .. ' (' .. value_type .. ')') .. ';' ..
            formspec_escape(tostring(v)) .. ']'
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
        'button[0.25,' .. y.. ';5.5,1;save;' ..
        (node._transient and 'Create element' or 'Save changes') .. ']'

    function callbacks.delete()
        if js.global:confirm('Are you sure?') then
            elem.parentNode:removeChild(elem)
            properties_elem.innerHTML = ''
            local base = elem.parentNode.parentNode
            assert(base.className == 'formspec_ast-base')
            renderer.redraw_formspec(base)
        end
    end

    function callbacks.reset()
        show_properties(elem)
    end

    function callbacks.save()
        local elems = properties_elem.firstChild.firstChild.children
        for i = 0, elems.length - 1 do
            local elem = elems[i]
            local name = elem:getAttribute('data-formspec_ast-name')
            local prefix = type(name) == 'string' and name:sub(1, 5)
            if prefix == 'prop_' then
                local k = name:sub(6)
                if type(node[k]) == 'string' then
                    node[k] = elem.lastChild.value
                elseif type(node[k]) == 'number' then
                    node[k] = tonumber(elem.lastChild.value) or node[k]
                elseif type(node[k]) == 'boolean' then
                    node[k] = elem:getAttribute('data-checked') == 'true'
                end
            elseif prefix == 'list[' then
                local s, e = name:find(']', nil, true)
                local k = name:sub(e + 1)
                node[k][tonumber(name:sub(6, s - 1))] = elem.lastChild.value
            end
        end
        node._transient = nil
        elem:setAttribute('data-formspec_ast', json.dumps(node))
        properties_elem.innerHTML = ''
        local base = elem.parentNode.parentNode
        assert(base.className == 'formspec_ast-base')
        renderer.redraw_formspec(base)
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

    local n = assert(renderer.render_formspec(formspec, callbacks, false))
    properties_elem:appendChild(n)
end

-- Render formspecs to HTML
local elems = {}

local function update(src, dest)
    for k, v in pairs(src) do
        if type(v) == 'table' and dest[k] then
            update(dest[k], v)
        else
            dest[k] = v
        end
    end
end

local function make(elem_type, props, attrs)
    local elem = document:createElement(elem_type)
    if props then
        update(props, elem)
    end
    if attrs then
        for k, v in pairs(attrs) do
            elem:setAttribute(k:gsub('_', '-'), v)
        end
    end
    return elem
end

function elems.label(node)
    return make('span', {
        textContent = node.label,
    }, {
        data_text = node.label,
    })
end

function elems.button(node)
    return make('div', {
        textContent = node.label,
    })
end
elems.button_exit = elems.button

function elems.image_button(node)
    local res = make('div', nil, {
        data_drawborder = tostring(node.drawborder ~= false),
    })
    res:appendChild(renderer.make_image(node.texture_name, true))
    res:appendChild(make('span', {textContent = node.label}))
    return res
end
elems.image_button_exit = elems.image_button

function elems.field(node, base, default_callbacks)
    local res = make('div')
    res:appendChild(make('span', {textContent = node.label}))
    local input = make('input', nil, {
        type = 'text',
        value = node.default or '',
    })
    if default_callbacks then
        input:setAttribute('readonly', 'readonly')
    end
    res:appendChild(input)
    return res
end

function elems.textarea(node, base, default_callbacks)
    local res = make('div')
    res:appendChild(make('span', {textContent = node.label}))
    local textarea = make('textarea', nil, {
        type = 'text',
    })
    textarea.textContent = node.default or ''
    if default_callbacks then
        textarea:setAttribute('readonly', 'readonly')
    end
    res:appendChild(textarea)
    return res
end

function elems.size(node, base, default_callbacks, scale)
    base.style.width = (node.w * scale) .. 'px'
    base.style.height = (node.h * scale) .. 'px'

    base:setAttribute('data-w', tostring(node.w))
    base:setAttribute('data-h', tostring(node.h))
end

function elems.image(node)
    return renderer.make_image(node.texture_name)
end

function elems.checkbox(node, base, default_callbacks)
    local checked = node.selected
    local div = make('div', nil, {data_checked = tostring(checked)})
    div:appendChild(make('div'))
    div:appendChild(make('span', {textContent = node.label}))
    if not default_callbacks then
        div:addEventListener('click', function()
            checked = not checked
            div:setAttribute('data-checked', tostring(checked))
        end)
    end
    return div
end

function elems.list(node, base, default_callbacks)
    local w, h = math.floor(node.w), math.floor(node.h)
    local res = make('table')
    for y = 1, h do
        local tr = make('tr')
        for x = 1, w do
            tr:appendChild(make('td'))
        end
        res:appendChild(tr)
    end
    res.style.left = node.x .. 'em'
    res.style.top = node.y .. 'em'
    res.style.width = (node.w * 1.25) .. 'em'
    res.style.height = (node.h * 1.25) .. 'em'
    return res, true
end

function elems.box(node)
    local res = make('div')
    res.style.backgroundColor = node.color
    if node.color:find('^ *rgb[^a]') or
            node.color:find('^ *#..[^ ] *$') or
            node.color:find('^ *#.....[^ ] *$') then
        res.style.opacity = '0.55'
    end
    return res
end

function elems.textlist(node)
    local res = make('div')
    for i, item in ipairs(node.listelem) do
        local elem = make('div')
        if item:sub(1, 1) ~= '#' then
            elem.textContent = item
        elseif item:sub(2, 2) == '#' then
            elem.textContent = item:sub(2)
        else
            elem.style.color = item:sub(1, 7)
            elem.textContent = item:sub(8)
        end
        if i == node.selected_idx then
            elem.style.background = '#467832';
        end
        res:appendChild(elem)
    end
    if node.transparent then
        res.style.background = 'none'
        res.style.borderColor = 'transparent'
    end
    return res
end

-- Make images - This uses HDX to simplify things
local image_baseurl = 'https://gitlab.com/VanessaE/hdx-128/raw/master/'
function renderer.make_image(name, allow_empty)
    -- Remove extension
    local real_name = name:match('^(.*)%.[^%.]+$') or ''

    -- Make an <img> element
    local img = document:createElement('img')
    local mode = 'png'
    img:setAttribute('ondragstart', 'return false')
    if name == '' and allow_empty then
        img.style.opacity = '0'
        return img
    end
    img:addEventListener('error', function()
        if mode == 'png' then
            mode = 'jpg'
        elseif mode == nil then
            return
        else
            mode = nil
            img.src = image_baseurl .. 'unknown_node.png'
            return
        end
        img.src = image_baseurl .. real_name .. '.' .. mode
    end)
    img.src = image_baseurl .. real_name .. '.' .. mode
    return img
end

function renderer.render_ast(tree, callbacks, store_json, scale)
    scale = 50 * (scale or 1)
    local base = document:createElement('div')
    base.className = 'formspec_ast-base'
    base.style.fontSize = scale .. 'px'
    local container = document:createElement('div')
    base:appendChild(container)

    for _, node in ipairs(formspec_ast.flatten(tree)) do
        if not elems[node.type] then
            return nil, 'Unknown formspec element: ' .. node.type
        end
        local e, ignore_pos = elems[node.type](node, base, callbacks == nil,
            scale)
        if e then
            if node.x and node.y and not ignore_pos then
                e.style.left = (node.x * scale) .. 'px'
                e.style.top = (node.y * scale) .. 'px'
                if node.w and node.h then
                    e.style.width = (node.w * scale) .. 'px'
                    e.style.height = (node.h * scale) .. 'px'
                end
            end
            e.className = 'formspec_ast-element formspec_ast-' .. node.type
            if store_json or store_json == nil then
                e:setAttribute('data-formspec_ast', json.dumps(node))
            end
            if node.name then
                e:setAttribute('data-formspec_ast-name', node.name)
            end
            local func
            if type(callbacks) == 'table' then
                func = callbacks[node.name or '']
            elseif callbacks == nil then
                func = show_properties
            end
            if func then
                e:addEventListener('click', func)
                e.className = e.className .. ' formspec_ast-clickable'
            end
            container:appendChild(e)
        end
    end
    container.style.width = base.style.width
    container.style.height = base.style.height
    return base
end

function renderer.render_formspec(formspec, ...)
    local tree, err = formspec_ast.parse(formspec)
    if err then
        return nil, err
    end
    return renderer.render_ast(tree, ...)
end

function renderer.elem_to_ast(elem)
    assert(elem.children.length == 1)
    local elems = elem.firstChild.children

    local w = tonumber(elem:getAttribute('data-w'))
    local h = tonumber(elem:getAttribute('data-h'))
    local res = {
        formspec_version = 2,
        {
            type = 'size',
            w = w or 0,
            h = h or 0,
        }
    }
    for i = 0, elems.length - 1 do
        local data = elems[i]:getAttribute('data-formspec_ast')
        local node = assert(json.loads(data), 'Error loading data!')

        if not node._transient then
            if node.name == 'size' then
                -- A hack to replace the existing size[] with any new one
                res[2] = node
            else
                res[#res + 1] = node
            end
        end
    end
    return res
end

local element_dialog_base
local function replace_formspec(elem, tree)
    local new_elem = renderer.render_ast(tree)
    elem:replaceWith(new_elem)
    if element_dialog_base == elem then
        element_dialog_base = new_elem
    end
end

function renderer.redraw_formspec(elem)
    replace_formspec(elem, renderer.elem_to_ast(elem))
end

-- Templates for new elements
do
    local templates = assert(formspec_ast.parse([[
        size[10.5,11]
        box[0,0;1,1;]
        button[0,0;3,0.75;;]
        button_exit[0,0;3,0.75;;]
        checkbox[0,0.2;;;false]
        field[0,0;3,0.75;;;]
        image[0,0;1,1;]
        image_button[0,0;2,2;;;;false;true;]
        image_button_exit[0,0;2,2;;;]
        label[0,0.2;]
        list[current_player;main;0,0;8,4;0]
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
        elem = make('div')
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

function renderer.unrender_formspec(elem)
    local res = renderer.elem_to_ast(elem)
    return formspec_ast.unparse(res)
end

local load = rawget(_G, 'loadstring') or load
local function deserialize(code)
    if code:byte(1) == 0x1b then return nil, 'Cannot load bytecode' end
    code = 'return ' .. code
    local f
    if rawget(_G, 'loadstring') and rawget(_G, 'setfenv') then
        f = loadstring(code)
        setfenv(f, {})
    else
        f = load(code, nil, nil, {})
    end
    local ok, res = pcall(f)
    if ok then
        return res, nil
    else
        return nil, res
    end
end

function renderer.import(fs, opts)
    if opts.format then
        fs = fs:gsub('" %.%. minetest.formspec_escape%(tostring%(' ..
            '%-%-%[%[${%]%]([^}]*)%-%-%[%[}%]%]%)%) %.%. "', function(s)
            return '${' .. ('%q'):format(s):sub(2, -2) .. '}'
        end)
        local err
        local fs2 = fs
        fs, err = deserialize(fs)
        if type(fs) ~= 'string' then
            return nil, err or 'That was valid Lua but not a valid formspec!'
        end
    elseif fs:sub(1, 1) == '"' then
        return nil, 'Did you mean to enable ${...} conversion?'
    end
    local tree, err = formspec_ast.parse(fs)
    if tree and tree.formspec_version < 2 then
        return nil, 'Only formspec versions >= 2 can be loaded!'
    end
    return tree, err
end

function renderer.export(tree, opts)
    if opts.use_v1 then
        tree = fs51.backport(tree)
    end
    local fs, err = formspec_ast.unparse(tree)
    if not fs then return nil, err end
    if opts.format then
        fs = ('%q'):format(fs)
        local ok, msg = true, ''
        fs = fs:gsub('${([^}]*)}', function(code)
            code = assert(deserialize('"' .. code .. '"'))
            if code:byte(1) == 0x1b then
                ok, msg = false, 'Bytecode not permitted in format strings'
            elseif ok then
                ok, msg = load('return ' .. code)
            end
            -- This adds markers before and after the code so it can be
            -- extracted easily in renderer.import().
            return '" .. minetest.formspec_escape(tostring(--[[${]]' .. code ..
                '--[[}]])) .. "'
        end)
        if not ok then
            return nil, msg
        end
    end
    return fs, nil
end

local element_dialog
local load_save_opts = {}
local function show_load_save_dialog()
    element_dialog.innerHTML = ''
    local callbacks = {}
    local fs = [[
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
        return opts
    end

    function callbacks.back()
        get_options()
        renderer.show_element_dialog(element_dialog_base)
    end

    function callbacks.load()
        local fs = window:prompt('Paste formspec here')
        get_options()
        local tree, err = renderer.import(fs, load_save_opts)
        if not tree then
            window:alert('Error loading formspec:\n' .. err)
        end
        replace_formspec(element_dialog_base, tree)
        renderer.show_element_dialog(element_dialog_base)
    end

    function callbacks.save()
        get_options()
        local tree = renderer.elem_to_ast(element_dialog_base)
        local res, err = renderer.export(tree, load_save_opts)
        element_dialog.innerHTML = ''
        local fs = 'formspec_version[2]size[6,9.5]button[0,0;1,0.6;back;←]' ..
            'label[1.25,0.3;Save formspec]textarea[0.25,1.25;5.5,8;;'
        if res then
            fs = fs ..
                'Formspec exported successfully.;' .. formspec_escape(res)
        else
            fs = fs ..
                'Error exporting formspec!;' .. formspec_escape(err)
        end
        fs = fs .. ']'
        element_dialog.innerHTML = ''
        element_dialog:appendChild(assert(renderer.render_formspec(fs, {
            back = show_load_save_dialog,
        })))
    end

    element_dialog:appendChild(assert(renderer.render_formspec(fs, callbacks,
        false)))
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
    fs = fs .. 'button[0.25,' .. y .. ';5.5,0.75;load;Load / save formspec]'
    callbacks.load = show_load_save_dialog
    y = y + 1
    fs = 'formspec_version[2]size[6,' .. y .. ']' .. fs
    element_dialog:appendChild(assert(renderer.render_formspec(fs, callbacks,
        false)))
end

-- A JS API for testing
function window:render_formspec(fs, callbacks)
    local tree = assert(formspec_ast.parse(fs))
    local elem = assert(renderer.render_ast(tree, callbacks))
    local e = assert(document:getElementById('formspec_output'))
    e.innerHTML = ''
    e:appendChild(elem)
    renderer.show_element_dialog(elem)
    return 'OK'
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
