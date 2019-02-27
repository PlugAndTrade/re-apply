# re-apply

## Template

```yaml
resources:
  - kind: "Namespace"
    do:
      - create:
          name: "$(GIT_BRANCH)"
  - kind: "Deployment"
    do:
      - copy:
          from: "default"
          where: "app == nginx"
          to: "$(GIT_BRANCH)"
          map:
            - op: "add"
              path: "/metadata/annotations/my-annotation"
              value: "value"
            - op: "replace"
              path: "/metadata/labels/app"
              value: "foobar"
            - op: "remove"
              path: "/spec/template/containers/0/livenessProbe"
              value: "foobar"

  - kind: "Ingress"
    do:
      - duplicate:
          from: "default"
          where: "app.kubernetes/part-of != upstream-service"
          map:
            - op: "add"
              path: "/spec/rules[*]/host"
              value: "$(GIT_BRANCH)-example.com"
            - op: "replace"
              path: "/spec/rules[*]/host"
              value: "$(GIT_BRANCH)-example.com"

```

## Usage

You need Esy, you can install the beta using [npm][]:

    % npm install -g esy

Then you can install the project dependencies using:

    % esy install

Then build the project dependencies along with the project itself:

    % esy build

Now you can run your editor within the environment (which also includes merlin):

    % esy $EDITOR
    % esy vim

After you make some changes to source code, you can re-run project's build
using:

    % esy build

And test compiled executable:

    % esy ./_build/default/bin/hello.exe

Shell into environment:

    % esy shell
