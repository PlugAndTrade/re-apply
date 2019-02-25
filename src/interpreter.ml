module Shell = struct
  type t = Command.t

  let run (ast: Ast.t) : t =
    Command.Kubectl.apply ()

  let seq (ast: Ast.t) : t list =
    [Command.Kubectl.apply ()]
end
