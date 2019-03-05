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

  let assign k v = update k (function Some v' -> Some v' | None -> Some v)

  let remove k = update k (fun _ -> None)

  let get = Yojson.Basic.Util.member
end

module JsonPatch = struct
  type path = string

  type v = Yojson.Safe.json

  type patch =
    {op: string; path: string; from: string option; value: v option}
  [@@deriving yojson {strict= false}]

  let make_p ?(from = None) ?(value = None) op path = {op; path; from; value}

  type t =
    | Add of (path * v)
    | Remove of path
    | Move of (path * path)
    | Replace of (path * v)
    | Test of path

  let from_patch ({op; path; from; value} : patch) =
    match (op, from, value) with
    | "add", _, Some v -> Some (Add (path, v))
    | "add", _, _ -> None
    | "remove", _, _ -> Some (Remove path)
    | "move", Some p, _ -> Some (Move (path, p))
    | "move", _, _ -> None
    | "replace", _, Some v -> Some (Replace (path, v))
    | "replace", _, _ -> None
    | "test", _, _ -> Some (Test path)
    | _, _, _ -> None

  module JQ = Json_query.Make (Json_repr.Yojson)

  let patch t json =
    match t with
    | Add (path, v) ->
        let p = Json_query.path_of_json_pointer path in
        JQ.insert p v json
    | Replace (path, v) ->
        let p = Json_query.path_of_json_pointer path in
        JQ.replace p v json
    | _ -> json
end
