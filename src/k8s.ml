module KSOMod = struct
  open Modifier.Json

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
    json |> Modifier.Json.get "items" |> Util.map f |> Util.to_list

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
         ["selfLink"; "uid"; "creationTimestamp"; "resourceVersion"]
    |> remove_fields
         ["metadata"; "annotations"]
         ["kubectl.kubernetes.io/last-applied-configuration"]

    |> add_fields
         ["metadata"; "labels"]
         [("app.kubernetes/part-of", `String "re-apply")]
end

module Kubectl = struct
  open Command.Infix

  let exe = Command.make "kubectl"

  type kind = Configmap | Deployment | Ingress | Namespace | Secret | Service

  let kind_of_string s =
    match String.lowercase_ascii s with
    | "configmap" -> Some Configmap
    | "deployment" -> Some Deployment
    | "ingress" -> Some Ingress
    | "namespace" -> Some Namespace
    | "secret" -> Some Secret
    | "service" -> Some Service
    | _ -> None

  let kind_of_string_exn s =
    match kind_of_string s with
    | Some kind -> kind
    | None -> failwith (Format.sprintf "unknown k8s kind %s" s)

  let kind_to_string = function
    | Configmap -> "configmap"
    | Deployment -> "deployment"
    | Ingress -> "ingress"
    | Namespace -> "namespace"
    | Secret -> "secret"
    | Service -> "service"

  let get ?(ns = "default") resource =
    exe % "get" % kind_to_string resource % ("-n=" ^ ns)

  let create resource name = exe % "create" % kind_to_string resource % name

  let delete resource name = exe % "delete" % kind_to_string resource % name

  let apply () = exe % "apply"

  let with_file cmd = cmd % "-f" % "-"

  let with_output ?(output = "json") cmd = cmd % ("-o=" ^ output)

  let with_selectors selectors cmd = cmd % ("-l=" ^ String.concat "," selectors)

  let dry_run cmd = cmd % "--dry-run"
end
