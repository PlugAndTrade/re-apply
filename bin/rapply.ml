open Cmdliner

let help =
  [ `S Manpage.s_common_options
  ; `P "These options are common to all commands."
  ; `S "MORE HELP"
  ; `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command."
  ; `Noblank
  ; `S Manpage.s_bugs
  ; `P "Check bug reports at https://github.com/plugandtrade/re-apply." ]

let default_cmd =
  let doc = "Template driven k8s manifest modifications" in
  let sdocs = Manpage.s_common_options in
  let exits = Term.default_exits in
  let man = help in
  ( (let open Term in
    ret (const (`Help (`Pager, None))))
  , Term.info "rapply" ~version:"0.0" ~doc ~sdocs ~exits ~man )

let run path envs =
  let p =
    match Lib.Rapply.run path envs with
    | Ok p -> p
    | Error (`Msg e) -> Lwt_io.print (Format.sprintf "Failed with %s" e)
  in
  Lwt_main.run p

let cmd =
  let envs =
    let doc = "envs" in
    Arg.(value & opt (list string) [] & info ["e"; "envs"] ~docv:"ENV" ~doc)
  in
  let path =
    let doc = "template path" in
    Arg.(value & pos 0 file "./" & info [] ~docv:"DIR" ~doc)
  in
  ( Term.(const run $ path $ envs)
  , Term.info "patch" ~doc:"Uses the template to patch the specified resources"
      ~sdocs:Manpage.s_common_options ~exits:Term.default_exits ~man:help )

let cmds = [cmd]

let () = Term.(exit @@ eval_choice default_cmd cmds)
