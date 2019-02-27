let to_yojson (ezjson : Yaml.value) : Yojson.Safe.json =
  let rec fn = function
    | `Null -> `Null
    | `Bool b -> `Bool b
    | `Float f -> `Float f
    | `String value -> `String value
    | `A l -> `List (List.map fn l)
    | `O l -> `Assoc (List.map (fun (k, v) -> (k, fn v)) l)
  in
  fn ezjson

let to_yaml (json : Yojson.Basic.json) : Yaml.value =
  let rec fn = function
    | `Null -> `String "null"
    | `Bool b -> `Bool b
    | `Float f -> `Float f
    | `Int i -> `String (string_of_int i)
    | `String value -> `String value
    | `List l -> `A (List.map fn l)
    | `Assoc l -> `O (List.map (fun (k, v) -> (k, fn v)) l)
  in
  fn json
