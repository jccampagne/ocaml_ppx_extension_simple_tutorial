all:
	# Create the executable ppx_test_simple
	ocamlc -I +compiler-libs ocamlcommon.cma ppx_test_simple.ml -o ppx_test_simple
	# Output the original source
	cat sample_input.ml
	# Output the modified source
	ocamlc -dsource -ppx ./ppx_test_simple sample_input.ml -c
	# Compile with ppx extension
	ocamlc -ppx ./ppx_test_simple sample_input.ml -o test
	# Run the program
	./test

clean:
	rm -f *cmo *cmi test ppx_test_simple
