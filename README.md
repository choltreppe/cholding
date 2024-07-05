## Cholding

`Cholding` is a web app for creating/editing layouts for chorded keyboards.  
The created layouts can be turned into arduino code.  
Cholding also includes a typing trainer to practice typing with any custom layout.

### Use online

[here](https://chol.foo/cholding)

### build yourself

You can build the project yourself and just open `build/index.html` in your browser

To build cholding need the [nim compiler](https://nim-lang.org/install.html)  
and some package:
```sh
nimble install nake fusion karax jsony
```

To build just do:
```sh
nake build
```
for debug build  
or
```sh
nake release
```
for optimised build
