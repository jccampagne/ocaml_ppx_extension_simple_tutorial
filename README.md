# Simple ppx tutorial

This is really simple tutorial on [PPX extension node rewriters](https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#sec248). In this example, the extension will have no payload in order to keep the example very simple.

# Files

The files in the project:

1. `ppx_test_simple.ml` defines an abstract syntax tree preprocessor that replaces `[%simple_tag]` extension with the integer `1234567890` in source code.
1. `sample_input.ml` will be used to demonstrated the PPX rewriter
1. `Makefile` contains the all the commands to run the example

You can compile the example by just typing:

```
make
```	

It will:

1. compile the PPX rewriter source file `ppx_test_simple.ml` and output the executable `ppx_test_simple`;
1. show the original source, for comparison;
1. run the PPX rewriter on `sample_input.ml` and print the modified source code to standard output;
1. compile `sample_input.ml` with the rewriter and build `test` executable;
1. finally, run the final program `test`.

You should see this ouput:

```
# Create the executable ppx_test_simple
ocamlc -I +compiler-libs ocamlcommon.cma ppx_test_simple.ml -o ppx_test_simple
# Output the original source
cat sample_input.ml
let _ = Printf.printf "%d" [%simple_tag]
# Output the modified source
ocamlc -dsource -ppx ./ppx_test_simple sample_input.ml
let _ = Printf.printf "%d" 1234567890
# Compile with ppx extension
ocamlc -ppx ./ppx_test_simple sample_input.ml -o test
# Run the program
./test
1234567890
```

# Detailed explanation

## PPX rewriter

Writing a PPX rewriter consists in defining an [`AST mapper`](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Ast_mapper.html) that will be applied to the abstract syntax tree of a source code.

An AST mapper is basically a [record containing a set of callbacks](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Ast_mapper.html#TYPEmapper) specifying what to do for every node types. Instead of defining every callbacks - 40 at the time of writing - it is common to base the new mapper on [the default AST mapper called `Ast_mapper.default_mapper`](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Ast_mapper.html#VALdefault_mapper) which is the identity, by default all callbacks return the same unmodified.

## Extention

In our case, we want to recognize the syntax `[%simple_tag]` as an [extension node](https://caml.inria.fr/pub/docs/manual-ocaml/extn.html#sec248) of [expression type](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Parsetree.html#TYPEexpression) in our code and replace it with an integer. This will be achieved with the use of [PPX extension](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Parsetree.html#TYPEextension). In this simple case, the extension node identifier is `simple_tag` and has no payload.

In order to help us write the pattern matching code, we can use `dumpast` PPX tools on the string `[%simple_tag]` as such:

```
$ ocamlfind ppx_tools/dumpast -e "[%simple_tag]"
```

The `-e` option means that the string argument is an *expression*. `ocamlfind` is just here to find the executable `dumpast` (it maybe somewhere like `~/.opam/system/lib/ppx_tools/dumpast` depending on your installation, which you could call directly).

The output is:

```
[%simple_tag]
==>
{pexp_desc = Pexp_extension ({txt = "simple_tag"}, PStr [])}
=========
```

This tells us that the string `[%simple_tag]` is an expression containing an extension whose identifier is `simple_tag`, and no payload (`PStr []`). The type definition is:

```
type expression_desc = 
 | ...
 | Pexp_extension of extension
```

In turn, an extension is defined as such:

```
type extension = string Asttypes.loc * payload 
```

with

```
type 'a loc = 'a Location.loc = {
  	txt : 'a;
  	loc : Location.t;
}
```

and 

```
type payload = 
 |	PStr of structure
 | ...
```

We'll stop drilling in the types for now as `payload` is an empty structure `PStr []` in this case.

These types are defined in [ParseTree Module](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Parsetree.html).


So in order to write our PPX rewriter, we will pattern match on this value:

```
                                   a 2-tuple
                              ________|___________________
                             /                            \
{pexp_desc = Pexp_extension ({txt = "simple_tag"}, PStr [])}
                              \________________/   \_____/
                                      |               |
                                 1st element       2nd elt.
                                  location         payload
                                "simple_tag"        empty
```


The function that will look something like this:

```
(* val my_expression_mapper : Ast_mapper.mapper -> Parsetree.expression -> Parsetree.expression *)

let my_expression_mapper mapper expr =
  match expr with
  | {pexp_desc = Pexp_extension ({txt = "simple_tag"}, PStr [])} -> ...
  | other -> default_mapper.expr mapper other
```


Note the ellipsis. What do we replace it with? Again, we can use `dumpast` to find out how to write the integer `1234567890`:

```
$  ocamlfind ppx_tools/dumpast -e "1234567890"
1234567890
==>
{pexp_desc = Pexp_constant (Pconst_integer ("1234567890", None))}
=========
```

So our function will look like:

```
let my_expression_mapper mapper expr =
  match expr with
  | {pexp_desc = Pexp_extension ({txt = "simple_tag"}, PStr [])} ->
     Ast_helper.Exp.constant (Pconst_integer ("1234567890", None))
  | other -> default_mapper.expr mapper other
```


It will match only expressions we are looking for and replace them with the integer `1234567890`, other expressions will just be left untouched.

The actual definition of the mapper will look like this:

```
(* val mapper_test_simple : 'a -> Ast_mapper.mapper *)

let mapper_test_simple argv =
  { default_mapper with expr = my_expression_mapper }
```


It is the default mapper [Ast\_mapper.default_mapper](https://caml.inria.fr/pub/docs/manual-ocaml/libref/Ast_mapper.html#VALdefault_mapper) with just the `expr` attribute replaced by our function `my_expression_mapper`.

Finally we register the PPX rewriter.


## Compiling the PPX rewriter

To compile the PPX rewrite you can do:

```
$ ocamlc -I +compiler-libs ocamlcommon.cma ppx_test_simple.ml -o ppx_test_simple
```

Let's understand what it does:

```
ocamlc -I +compiler-libs ocamlcommon.cma ppx_test_simple.ml -o ppx_test_simple
       \_______________/ \_____________/ \________________/    \_____________/
           search for      library file      input file            output 
          compiler-libs                                          executable 
          in standard
             paths
```

You need to link against `ocamlcommon.cma` which is in `.../ocaml/4.03.0/lib/ocaml/compiler-libs/ocamlcommon.cma`. The output is an executable indeed.

When you run it:
```
$ ./ppx_test_simple
Usage: ./ppx_test_simple [extra_args] <infile> <outfile>
```

But the common way to use it is with the compiler as shown in the next section.

## Running the PPX rewriter

If you want to view the transformed code, you can type:

```
ocamlc -dsource -ppx ./ppx_test_simple sample_input.ml
```


To actually compile the code and produce the final executable:

```
ocamlc -ppx ./ppx_test_simple sample_input.ml -o test
```

You can then run the executable:

```
$ ./test
1234567890
```

## Some errors

### `Uninterpreted extension` error

```
$ ocamlc sample_input.ml
File "sample_input.ml", line 1, characters 29-39:
Uninterpreted extension 'simple_tag'.
```

The PPX extension was not specified. Fix:

```
$ ocamlc -dsource -ppx ./ppx_test_simple sample_input.ml 
```

### `Error: External preprocessor does not produce a valid file`

```
$ ocamlc -dsource -ppx ./ppx_test_simple sample_input.ml
File "sample_input.ml", line 1:
Error: External preprocessor does not produce a valid file
Command line: ./ppx_test_simple '/var/folders/41/w5q9lk3j6xn4krfpglf5b_l80000gp/T/camlppx75184a' '/var/folders/41/w5q9lk3j6xn4krfpglf5b_l80000gp/T/camlppxe10080'
```

You may have forgotten to register the mapper, be sure you did so:

```
let () =
  register "ppx_test_simple" mapper_test_simple
```

## Whole AST tree

It is possible to dump the whole parse tree of a program with ocamlc:

```
$ ocamlc -dparsetree -ppx ./ppx_test_simple sample_input.ml
[
  structure_item (sample_input.ml[1,0+0]..[1,0+45])
    Pstr_value Nonrec
    [
      <def>
        pattern (sample_input.ml[1,0+4]..[1,0+5])
          Ppat_any
        expression (sample_input.ml[1,0+8]..[1,0+45])
          Pexp_apply
          expression (sample_input.ml[1,0+8]..[1,0+21])
            Pexp_ident "Printf.printf" (sample_input.ml[1,0+8]..[1,0+21])
          [
            <arg>
            Nolabel
              expression (sample_input.ml[1,0+22]..[1,0+26])
                Pexp_constant PConst_string("%d",None)
            <arg>
            Nolabel
              expression (_none_[1,0+-1]..[1,0+-1]) ghost
                Pexp_constant PConst_int (1234567890,None)
          ]
    ]
]
```

# Next

Now let's define a PPX extension with a payload, that will be more interesting.

# References:

[The compiler front-end](https://caml.inria.fr/pub/docs/manual-ocaml/parsing.html)
