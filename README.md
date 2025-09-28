# Pratt Parsing Visualization
Visualizing the pratt parsing abstract syntax tree generation in real time with a GUI.

Powered by Zig + Raylib.

## Dependencies
* *Zig 0.15.1*

## Building and Running
```sh
zig build run
```

## Operators
Currently, the following operators are available:

* **Special**: `';' (end of statement)` `'()' (precedence forcing)` `'{}' (expressions)`

* **Assignment**: `'=' (assignment)`

* **Basic arithmetic**: `'+' (sum)` `'-' (subtraction)` `'-' (negation)` `'*' (multiplication)` `'/' (division)`

* **Increment and Decrement**: `'++' (pre-increment)` `'++' (post-increment)` `'--' (pre-decrement)` `'--' (post-decrement)`

* **Boolean logic**: `'and' (boolean and)` `'or' (boolean or)` `'!' (boolean not)`

## Examples
`foo = 42;`

`foo = bar = -(!a + (42 * 1337));`

`{foo = 1; bar = 2; baz = foo + bar;};`
