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

js = require 'js'
window = js.global
document = window.document

renderer = {}

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
renderer.make = make

function elems.label(node)
    return make('span', {
        textContent = node.label,
    }, {
        data_text = node.label,
    })
end

function elems.vertlabel(node)
    return make('span', {
        textContent = node.label:gsub('', '\n'):sub(2, -2),
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
    if node.texture_name ~= 'blank.png' then
        res:appendChild(renderer.make_image(node.texture_name, true))
    end
    res:appendChild(make('span', {textContent = node.label}))
    return res
end
elems.image_button_exit = elems.image_button

local function make_field(input_type, node, base, default_callbacks)
    local res = make('div')
    res:appendChild(make('span', {textContent = node.label}))
    local input = make('input', nil, {
        type = input_type,
        value = node.default or '',
    })
    if default_callbacks then
        input:setAttribute('readonly', 'readonly')
    end
    res:appendChild(input)
    return res
end

function elems.field(...)
    return make_field('text', ...)
end

function elems.pwdfield(...)
    return make_field('password', ...)
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
            elem.textContent = item:sub(3)
        else
            elem.style.color = item:sub(1, 7)
            elem.textContent = item:sub(8)
        end
        if elem.textContent == '' then
            elem.innerHTML = '&nbsp;'
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

function elems.dropdown(node, base, default_callbacks, scale)
    local res = make('div')
    if not node.h then
        res.style.width = (node.w * scale) .. 'px'
        res.style.height = (2 * 15/13 * 0.35 * scale) .. 'px'
    end
    local select = make('select')
    for i, item in ipairs(node.item) do
        local e = make('option', {textContent = item}, {name = i})
        if i == node.selected_idx then
            e:setAttribute('selected', 'selected')
        end
        select:appendChild(e)
    end
    window:setTimeout(function()
        if res.classList:contains('formspec_ast-clickable') then
            select:setAttribute('disabled', 'disabled')
        end
    end, 0)
    res:appendChild(select)

    local btn = make('div')
    btn:appendChild(make('div'))
    res:appendChild(btn)
    return res
end

local function generic_render(node)
    window.console:warn('Formspec element type ' .. node.type ..
        ' not implemented.')
    if node.x and node.y then
        return renderer.make_image('unknown_object.png')
    else
        window.console:error('Formspec element type ' .. node.type ..
            ' is not implemented and there is no reliable way to render it.')
        local res = make('div')
        res.style.display = 'none'
        return res
    end
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

local default_options = {}
function renderer.render_ast(tree, callbacks, options)
    options = options or default_options
    local scale = 50 * (options.scale or 1)
    local store_json = options.store_json or options.store_json == nil
    local base = document:createElement('div')
    base.className = 'formspec_ast-base'
    base:setAttribute('data-render-options', json.dumps(options))
    base.style.fontSize = scale .. 'px'
    local container = document:createElement('div')
    base:appendChild(container)
    if options.grid then
        base.firstChild.className = 'grid'
    end

    for _, node in ipairs(formspec_ast.flatten(tree)) do
        if node.type == 'real_coordinates' then
            return nil, 'Unsupported element: real_coordinates[]'
        end

        -- Attempt to use a generic renderer
        local render_func = elems[node.type] or generic_render

        local e, ignore_pos = render_func(node, base, callbacks == nil, scale)
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
                e:setAttribute('data-type', node.type)
            end
            if node.name then
                e:setAttribute('data-formspec_ast-name', node.name)
            end
            local func
            if type(callbacks) == 'table' then
                func = callbacks[node.name or '']
            elseif callbacks == nil then
                func = renderer.default_callback
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
    local html_elems = elem.firstChild.children

    local w = tonumber(elem:getAttribute('data-w'))
    local h = tonumber(elem:getAttribute('data-h'))
    local res = {
        formspec_version = 3,
        {
            type = 'size',
            w = w or 0,
            h = h or 0,
        }
    }
    for i = 0, html_elems.length - 1 do
        local data = html_elems[i]:getAttribute('data-formspec_ast')
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

function renderer.replace_formspec(elem, ...)
    local new_elem, err = renderer.render_ast(...)
    if not new_elem then return nil, err end
    elem:replaceWith(new_elem)
    return new_elem, nil
end

function renderer.redraw_formspec(elem)
    local tree = renderer.elem_to_ast(elem)
    local options = elem:getAttribute('data-render-options')
    if type(options) == 'string' then
        options = json.loads(options)
    else
        options = nil
    end
    return renderer.replace_formspec(elem, tree, nil, options)
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
            return '${' .. ('%q'):format(formspec_escape(s)):sub(2, -2) .. '}'
        end)
        local err
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

function renderer.fs51_backport(tree)
    tree = fs51.backport(tree)

    -- Round numbers to 2 decimal places
    local c = {'x', 'y', 'w', 'h'}
    for node in formspec_ast.walk(tree) do
        for _, k in ipairs(c) do
            if type(node[k]) == 'number' then
                node[k] = math.floor((node[k] * 100) + 0.5) / 100
            end
        end
    end
    return tree
end

function renderer.export(tree, opts)
    if opts.use_v1 then
        tree = renderer.fs51_backport(tree)
    end

    local fs, err = formspec_ast.unparse(tree)
    if not fs then return nil, err end
    if opts.format then
        fs = ('%q'):format(fs):gsub('\\\n', '\\n')
        local ok, msg = true, ''
        fs = fs:gsub('${([^}]*)}', function(code)
            code = assert(deserialize('"' .. code .. '"')):gsub('\\(.)', '%1')
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
