module R = Rresult.R

let run path =
  let open R in
  (Ast.of_yaml path) >>| (Interpreter.Shell.seq)
