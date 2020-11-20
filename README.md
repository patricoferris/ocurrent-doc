OCurrent Pipeline Documentation
-------------------------------

A centralised and thorough set of documents for OCurrent including: 

   - Basic incremental building using the eDSL
   - Understanding of pipelines 
   - Building plugins from scratch 
   - Non-trivial case studies 

Happy OCaml pipeline building :) 

### Running Locally 

To run the documentation locally you will need to pin the package and install the dependencies: 

```
opam pin . -ny 
opam install --deps-only . 
```

From here you can start the development server from the root of directory and go to `localhost:8000`. 

```
sesame-doc dev
```