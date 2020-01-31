# fs51 - WIP formspec backport thing

Attempts to backport `real_coordinates[true]` formspecs.

## Dependencies

This mod depends on my [formspec_ast] library.

## API functions:

 - `fs51.backport(tree)`: Applies backports to a [formspec_ast] tree and
    returns the modified tree. This does not modify the existing tree in place.
 - `fs51.backport_string(formspec)`: Similar to
    `formspec_ast.unparse(fs51.backport(formspec_ast.parse(formspec)))`.


 [formspec_ast]: https://git.minetest.land/luk3yx/formspec_ast
