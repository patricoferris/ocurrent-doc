[@@@part "0"]

module Schema = Schema.Make (Capnp.BytesMessage)

let () =
  let s = Schema.Builder.Config.init_root () in
  print_endline (Schema.Builder.Config.id_get s);
  Schema.Builder.Config.id_set s "new_id";
  print_endline (Schema.Builder.Config.id_get s)
