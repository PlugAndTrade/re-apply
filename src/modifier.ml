module Json = struct
  let (>>|) v f =
    match v with
    | Some v -> Some (f v)
    | None -> None

  let update key f (json : Yojson.Basic.json) =
    let rec update_json_obj = function
        | [] ->
            begin match f None with
                | None -> []
                | Some v -> [(key, v)]
            end
        | ((k, v) as m) :: tl ->
            if k = key then
                match f (Some v) with
                | None -> update_json_obj tl
                | Some v' ->
                    if v' == v then m :: tl
                    else (k, v') :: tl
            else m :: (update_json_obj tl)
    in

    match json with
    | `Assoc obj -> `Assoc (update_json_obj obj)
    | _ -> json

  let add k v = update k (fun _ -> Some v)
  let remove k = update k (fun _ -> None)

  let get = Yojson.Basic.Util.member

  let test () =
    let json = (Yojson.Basic.from_string "{\"kind\": \"deployment\", \"metadata\": {\"namespace\": \"foo\"}}") in
    let j = update "metadata" (
      function
        | Some m -> Some (update "namespace" (fun _ -> Some (`String "test")) m)
        | None -> Some (`Assoc [])
    ) json in
    print_endline (Yojson.Basic.pretty_to_string j)

  let test2 () =
    let json = (Yojson.Basic.from_string "{}") in
    let j = update "metadata" (
      function
        | Some m -> Some (update "namespace" (fun _ -> Some (`String "test")) m)
        | None -> Some (`Assoc [])
    ) json in
    print_endline (Yojson.Basic.pretty_to_string j)
end
