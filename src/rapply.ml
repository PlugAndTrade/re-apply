module R = Rresult.R

module Ctx = struct
  type t = {template: string; env: string * string list}
end

let run path =
  let open R in
  Template.of_yaml path >>| Interpreter.Shell.seq
