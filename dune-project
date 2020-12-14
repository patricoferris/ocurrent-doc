(lang dune 2.7)

(name ocurrent-doc)

(using mdx 0.1)

(formatting disabled)

(generate_opam_files true)

(source
 (github patricoferris/ocurrent-doc))

(authors "pf341@patricoferris.com")

(maintainers "pf341@patricoferris.com")

(documentation "https://ocurrent-doc.netlify.app")

(package
 (name ocurrent-doc)
 (synopsis "Documentation for all things OCurrent")
 (description
   "Powered by Mdx and Sesame-doc to make sure the documentation works\nand to provide an easy interface to develop and share the docs.")
 (depends
  "current"
  "sesame-doc"
  "capnp"
  ("mdx" :with-test)))
