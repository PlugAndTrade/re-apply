module F = Bos.OS.File
module D = Bos.OS.Dir

let (<|>) a b =
  match a with
  | Ok x -> x
  | _ -> b

let f_exists p = (F.exists p) <|> false

let is_dir p = (D.exists p) <|> false

let read_dir ?(rel=false) p =
  (D.contents ~rel p) <|> [] |> List.map Fpath.normalize

let read_dir_rec ~fn dir =
  let rec traverse result = function
    | f :: fs when is_dir f ->
        (read_dir f)
        |> List.append fs
        |> traverse result
    | f :: fs when (fn f) -> traverse (f :: result) fs
    | _f :: fs -> traverse result fs
    | [] -> result
  in
  traverse [] [dir]
