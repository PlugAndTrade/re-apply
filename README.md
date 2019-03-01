# re-apply

Template driven modifications to local & remote kubernetes manifests

`re-apply` allows taking already existing kubernetes manifests, apply JSON
patches and output all changes as a single `yaml` with all modified resources.

This allows creating permutations of already existing resources using only a
template and already existing kubernetes resources or manifests. 

## Usage

``` yaml
re-apply mod -t ./path/to/template | kubectl apply -f -
re-apply mod -t ./path/to/template | kubectl delete -f -
```

## Template

```yaml
local:
  - path: "./echoserver.deployment.yaml"
    patch:
      - op: "replace"
        path: "/spec/template/spec/containers/0/image"
        value: "gcr.io/google_containers/echoserver:1.5"
      - op: "replace"
        path: "/metadata/name"
        value: "{{ GIT_BRANCH }}-{{ GIT_COMMIT }}"
      - op: "replace"
        path: "/metadata/namespace"
        value: "{{ GIT_BRANCH }}"
resources:
  - kind: "Namespace"
    do:
      - create:
          name: "{{ GIT_BRANCH }}"
  - kind: "Deployment"
    do:
      - copy:
          from: "default"
          where: "run == echoserver,app.kubernetes/belongs-to != re-apply"
          to: "test"
          patch:
            - op: "add"
              path: "/metadata/annotations/test"
              value: "test-value"
          patch:
            - op: "replace"
              path: "/metadata/labels/app"
              value: "{{ GIT_USER }}"
  - kind: "Ingress"
    do:
      - duplicate:
          from: "default"
          where: "test == test,app.kubernetes/belongs-to != re-apply"
          namePrefix: "{{ GIT_BRANCH }}-"
          patch:
            - op: "replace"
              path: "/spec/rules/0/host"
              value: "{{ GIT_BRANCH }}.example.com"

```

### Local

The `local` takes a file path and an optional array of operations and applies
the patch to the manifest before inserting it into the output manifest.
``` yaml
local:
  - path: "./path/to/manifest.yaml"
    patch: 
      - op: "replace"
        path: "/metadata/labels/app"
        value: "my-app"
      - op: "add"
        path: "/metadata/annotations/app"
        value: "my-app"
```

### resources

`resources` is used for fetching remote resources i.e from a cluster. The
operations supported are `create`, `copy` & `duplicate`. 

#### `copy`
`copy` fetches a collection of `kind` matching the selector(s) provided in
`where`, optionally applies the patch to the resources and copies the resource
to the namespace provided in`to`
```yaml
resources:
  - kind: Deployment
    do:
      - copy:
          from: default # from namespace
          where: "app == echoserver" # label/field selector
          to: test # target namespace
          patch: 
            - op: add
              path: /metdata/annotations/test
              value: test

```
#### `duplicate`
Fetches a collection of `kind` matching the selector(s) provided in `where`,
optionally applies the `patch` to the resource and copies the resource changing
the `metadata.name` with the prefix provided in `namePrefix`

``` yaml
  - kind: Deployment
    do:
      - duplicate:
          from: default
          where: "test == test,app.kubernetes/belongs-to != re-apply"
          namePrefix: "{{ GIT_BRANCH }}-"
          patch:
            - op: add
              path: /metadata/annotation/test
              value: "{{ GIT_BRANCH }}"
```
#### `create`
Creates a resource 

``` yaml
- kind: Namespace
  do:
    - create: 
        name: my-namespac-{{ GIT_BRANCH }}
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

```
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
