module R = Rresult.R
module OS = Lib.Os

let () =
  let open Lib.Ast in
  let open Lib.Ast.Resource in
  let open Lib.Ast.Resource in
  let open R in
  (* let rd = Fpath.of_string "./"
   * >>| OS.read_dir
   * >>| List.map (fun p -> Fpath.to_string p)
   * >>| List.fold_left (fun acc p -> print_endline p) ()
   * in
   * let recd = Fpath.of_string "./"
   * >>| OS.read_dir_rec ~fn: (fun p -> (Fpath.get_ext p ) = ".ml")
   * >>| List.map (fun p -> Fpath.to_string p)
   * >>| List.fold_left (fun acc p -> print_endline p) ()
   * in *)
  let t =
    match Lib.Ast.of_yaml "./.simon/template.yaml" with
    | Ok ast ->
        let dos = List.map (fun a -> a.do_) ast.resources in
        let foo = List.flatten dos in
        let tr =
          List.map
            (fun op ->
              Lib.Interpreter.Shell.to_kube Lib.Command.Kubectl.Deployment op
              )
            foo
        in
        Lwt.join tr
    | Error _e -> Lwt.return ()
  in
  (* ignore (print_endline tost); *)
  ignore (Lib.Modifier.Json.test ()) ;
  (* (ignore rd);
   * (ignore recd); *)
  Lwt_main.run t
