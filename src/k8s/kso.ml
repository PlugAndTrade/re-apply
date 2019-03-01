open Base.Modifier.Json

let name n json =
  update "metadata"
    (function
      | Some m -> Some (update "name" (fun _ -> Some (`String n)) m)
      | None -> Some (`Assoc []))
    json

let prefix_name prefix json =
  update "metadata"
    (function
      | Some m ->
          Some
            (update "name"
               (function
                 | Some (`String name) -> Some (`String (prefix ^ name))
                 | Some s -> Some s
                 | None -> None)
               m)
      | None -> Some (`Assoc []))
    json

let namespace ns json =
  update "metadata"
    (function
      | Some m -> Some (update "namespace" (fun _ -> Some (`String ns)) m)
      | None -> Some (`Assoc []))
    json

let map_items ~f json =
  let open Yojson.Basic in
  json |> get "items" |> Util.map f |> Util.to_list

let remove_fields path fields json =
  List.fold_left
    (fun acc field -> update_in ~f:(remove field) path acc)
    json fields

let add_fields path fields json =
  List.fold_left
    (fun acc (k, v) -> update_in ~f:(add k v) path acc)
    json fields

let normalize json =
  List.fold_left (fun j field -> remove field j) json ["status"]
  |> remove_fields ["metadata"]
       ["selfLink"; "uid"; "creationTimestamp"; "resourceVersion"; "generation"]
  |> remove_fields
       ["metadata"; "annotations"]
       ["kubectl.kubernetes.io/last-applied-configuration"]
  |> update_in ~f:(assign "labels" (`Assoc [])) ["metadata"]
  |> add_fields ["metadata"; "labels"]
       [("app.kubernetes/belongs-to", `String "re-apply")]
