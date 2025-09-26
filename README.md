# Pratt Parsing Visualization
Visualizing the pratt parsing abstract syntax tree with a GUI.

Powered by Zig + Raylib.

## Dependencies
Just **Zig 0.15.1**

## Building and Running
```sh
zig build run
```

## Operators
Currently, the following operators are available:

* **Special**: `';'(end of statement)` `parentheses(for precedence forcing)` `curly brackets(for expressions)`

* **Assignment**: `'='(assignment)`

* **Basic arithmetic**: `'+'(sum)` `'-'(subtraction)` `'-'(negation)` `'*'(multiplication)` `'/'(division)`

* **Boolean logic**: `'and'(boolean and)` `'or'(boolean or)` `'!'(boolean not)`

## Examples

`foo = 42;`

`foo = bar = -(!a + (42 * 1337));`

`{foo = 1; bar = 2; baz = foo + bar;};`
