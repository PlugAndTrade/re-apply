# re-apply

## Template

```yaml
local:
  - path: "./echoserver.deployment.yaml"
    patch:
      - op: "replace"
        path: "/spec/template/spec/containers/0/image"
        value: "gcr.io/google_containers/echoserver:{{ GIT_BRANCH }}"
      - op: "replace"
        path: "/metadata/namespace"
        value: "{{ GIT_BRANCH }}"
resources:
  - kind: "Namespace"
    do:
      - create:
          name: "{{ GIT_BRANCH }}-{{ GIT_COMMIT }}"
  - kind: "Deployment"
    do:
      - copy:
          from: "default"
          where: "app == nginx"
          to: "{{ GIT_BRANCH }}"
          patch:
            - op: "add"
              path: "/metadata/annotations/my-annotation"
              value: "value"
            - op: "replace"
              path: "/metadata/labels/app"

  - kind: "Ingress"
    do:
      - duplicate:
          from: "default"
          where: "app.kubernetes/part-of != upstream-service"
          patch:
            - op: "add"
              path: "/spec/rules/0/host"
              value: "{{ GIT_BRANCH }}-example.com"
            - op: "replace"
              path: "/spec/rules[*]/host"
              value: "{{ GIT_BRANCH }}-example.com"

```

### JSON patch

Manifests can be patched using
* Add

``` json
{"op": "add", "path": "/spec/metadata/annotations/foo", "value": "value"}
```
* Replace
``` json
{"op": "replace", "path": "/spec/metadata/labels/app", "value": "myapp"}
``**
* Remove
** TODO **

* Move
** TODO **


### Interpolation

The following variables are available for interpolation in a template:

| VAR                                      | Description                                             | Value            |
| -------------                            | :-------------:                                         | -----:           |
| `GIT_BRANCH`                             | Current git branch (`git symbolic-ref --short -q HEAD`) | `feature/foobar` |
| `GIT_USER`                               | Current git user (`git config user.name`)               | `John Doe`       |
| `GIT_COMMIT`                             | Latest git commit (`git rev-parse HEAD`)                | `26dfcdea7a022731a5c7bf1043a60cecf0bfc342`          |

The template language used is mustache.

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
