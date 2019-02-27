module F = Bos.OS.File
module D = Bos.OS.Dir

let unpack a b = match a with Ok x -> x | _ -> b

module Infix = struct
  let ( <|> ) = unpack
end

open Infix

let f_exists p = F.exists p <|> false

let read_file p = F.read p <|> ""

let is_dir p = D.exists p <|> false

let read_dir ?(rel = false) p =
  D.contents ~rel p <|> [] |> List.map Fpath.normalize

let read_dir_rec ~fn dir =
  let rec traverse result = function
    | f :: fs when is_dir f -> read_dir f |> List.append fs |> traverse result
    | f :: fs when fn f -> traverse (f :: result) fs
    | _f :: fs -> traverse result fs
    | [] -> result
  in
  traverse [] [dir]

module Git = struct
  open Bos.Cmd
  let git = Bos.Cmd.v "git"

  let run cmd =
    Bos.OS.Cmd.(run_out cmd |> to_lines)

  let user () =
    run (git % "config" % "user.name")

  let current_branch () =
    run (git % "symbolic-ref" % "--short" % "-q" % "HEAD")

  let current_commit () =
    run (git % "rev-parse" % "HEAD")

end
