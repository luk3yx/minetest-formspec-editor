# Web-based formspec edtior

Really actually removing the pains of formspec design.

[Try it online](https://luk3yx.gitlab.io/minetest-formspec-editor/)

Uses [Fengari](https://fengari.io/) to run my
[formspec_ast](https://content.minetest.net/packages/luk3yx/formspec_ast/) and
[fs51](https://content.minetest.net/packages/luk3yx/fs51/) mods on
web browsers.

`image[]` elements use [HDX](https://github.com/mt-historical/hdx-128) textures
by default (dynamically loaded when required).

## Major features

 - Web-based (no waiting for MT to load)
 - Dragging and resizing elements.
 - Property editor
 - `${lua code}` substitution in text values.
   - Don't remove the weird comments generated when exporting these formspecs
    if you plan to import them again.
 - The ability to load existing formspecs (provided they are version 2 or
     above).
 - The ability to export to (but not import from) digistuff touchscreen
    formspecs.

## Limitations

 - Although it can save formspecs in the version 1 format, it cannot load them
    in this format. Co-ordinates are backported with help from my `fs51` mod.
 - The properties editor is slow when manipulating lots of properties.
 - Malicious formspecs imported with the `${...}` substitution option enabled
    can freeze the webpage.
 - Element alignment might not be perfect.
 - I haven't tested this thoroughly in many browsers, if you find any bugs
    please report them.
 - Texture modifiers in `image[]` will not be displayed in the preview.

## Copyright / License

Copyright © 2020 by luk3yx

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
