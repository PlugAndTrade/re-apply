module Json = struct
  let ( >>| ) v f = match v with Some v -> Some (f v) | None -> None

  let update key f (json : Yojson.Basic.json) =
    let rec update_json_obj = function
      | [] -> ( match f None with None -> [] | Some v -> [(key, v)] )
      | ((k, v) as m) :: tl ->
          if k = key then
            match f (Some v) with
            | None -> update_json_obj tl
            | Some v' -> if v' == v then m :: tl else (k, v') :: tl
          else m :: update_json_obj tl
    in
    match json with `Assoc obj -> `Assoc (update_json_obj obj) | _ -> json

  let rec update_in ~f fields json =
    match fields with
    | [] -> json
    | [h] -> update h (function Some j -> Some (f j) | None -> None) json
    | h :: tl ->
        update h
          (function Some j -> Some (update_in ~f tl j) | None -> None)
          json

  let add k v = update k (fun _ -> Some v)

  let remove k = update k (fun _ -> None)

  let get = Yojson.Basic.Util.member
end
