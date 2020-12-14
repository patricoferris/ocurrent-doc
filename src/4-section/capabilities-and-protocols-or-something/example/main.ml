module Schema = Schema.Make (Capnp.BytesMessage)

let () =
  let s = Schema.Builder.Config.init_root () in
  print_endline (Schema.Builder.Config.id_get s)
