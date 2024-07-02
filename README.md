## Cholding

`Cholding` is a browser app for creating/editing layouts for chorded keyboards.  
The created layouts can be turned into arduino code.  
Cholding also includes a typing trainer to practice typing with any custom layout.

### Use online

[here](https://chol.foo/cholding)

### build yourself

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