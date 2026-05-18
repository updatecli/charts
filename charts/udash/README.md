# udash

![Version: 0.26.0](https://img.shields.io/badge/Version-0.26.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Udash, the Updatecli DASHboard

[Udash](https://github.com/updatecli/udash) is the Updatecli Dashboard — a web application that collects and displays Updatecli reports, giving your team a centralised view of software update activity across all your repositories.

## Architecture

The chart deploys two workloads:

| Component | Image | Description |
|-----------|-------|-------------|
| `udash-server` | `ghcr.io/updatecli/udash` | Backend API server (port 8080). Stores and serves Updatecli reports. |
| `udash-front` | `ghcr.io/updatecli/udash-front` | React SPA served on port 80. |

An optional **Ingress** routes:
- `/` → `udash-front`
- `/api` → `udash-server`

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- **[CloudNative-PG operator](https://cloudnative-pg.io/)** (when `cnpg.enabled: true`, which is the default)

Install the CNPG operator before installing this chart, and use `--wait` to ensure the operator
pod is fully ready (including its admission webhook) before proceeding:

```console
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg \
  --wait
```

Without `--wait`, the operator pod may not be ready when the chart creates the `Cluster` resource,
causing: `failed calling webhook "mcluster.cnpg.io": no endpoints available for service "cnpg-webhook-service"`.

If you prefer to bring your own PostgreSQL instance, set `cnpg.enabled=false` and supply the connection URI via `secrets.database.stringdata.uri`.

## Get Repository Info

```console
helm repo add updatecli https://updatecli.github.io/charts
helm repo update
```

## TL;DR

```console
helm install udash updatecli/udash
```

## Installing the Chart

### Default (CloudNative-PG managed PostgreSQL)

By default the chart provisions a CNPG `Cluster` and injects credentials automatically. Just install the CNPG operator first (see Prerequisites), then:

```console
helm install udash updatecli/udash
```

### Read-only mode with external PostgreSQL

Disable CNPG and supply your own connection URI:

```console
helm install udash updatecli/udash \
  --set cnpg.enabled=false \
  --set secrets.database.stringdata.uri="postgres://user:pass@postgres:5432/udash?sslmode=disable"
```

### Full mode with OAuth2

Set `readonly: false` and supply your OAuth2 provider details:

```console
helm install udash updatecli/udash \
  --set readonly=false \
  --set secrets.auth.stringdata.clientid="my-client-id" \
  --set secrets.auth.stringdata.audience="https://udash.example/api" \
  --set secrets.auth.stringdata.issuer="https://auth.example"
```

When using an external PostgreSQL in full mode, also set `cnpg.enabled=false` and `secrets.database.stringdata.uri`.

### With Ingress (same host, default paths)

Routes `udash.example.com/` to the front and `udash.example.com/api` to the server:

```console
helm install udash updatecli/udash \
  --set ingress.enabled=true \
  --set ingress.className=traefik \
  --set "ingress.hosts[0].host=udash.example.com"
```

### With Ingress (same host, subpath)

Serves the front at `app.example.com/updatecli` and the API at `app.example.com/api`.
The front ingress must strip the `/updatecli` prefix before forwarding to nginx so that
the nginx container always receives paths starting with `/`. Configure the SPA base path
to match via `front.appBasePath`.

**nginx ingress controller** (uses `rewrite-target` + `use-regex`):

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
  hosts:
    - host: app.example.com
  paths:
    front: "/updatecli(/|$)(.*)"   # regex captures the suffix to pass as $2
    server: "/api"                  # no rewrite needed; server handles /api natively

front:
  appBasePath: "/updatecli"  # must match the path prefix (without regex)
  apiBaseUrl: "/api"
```

**Traefik** — set `ingress.traefik.stripPrefix.enabled: true` and the chart creates the
`StripPrefix` Middleware CR and wires its annotation into the Ingress automatically.
Requires Traefik CRDs (`traefik.io/v1alpha1`) to be installed in the cluster:

```yaml
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: app.example.com
  paths:
    front: "/updatecli"
    server: "/api"
  traefik:
    stripPrefix:
      enabled: true   # creates the Middleware CR and injects the router annotation

front:
  appBasePath: "/updatecli"
  apiBaseUrl: "/api"
```

> **Note:** `front.appBasePath` tells the SPA JavaScript router which path prefix to use for
> client-side navigation. It must always match the **un-rewritten** path (e.g. `/updatecli`).
> The API server does not need a strip-prefix because it handles `/api` natively.

### With Ingress (split domain)

Routes the front and API to different hostnames. Set `front.apiBaseUrl` to the absolute API URL
so the browser knows where to reach the server:

```yaml
front:
  apiBaseUrl: "https://api.udash.example.com/api"

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: udash.example.com
  tls:
    - secretName: udash-tls
      hosts: [udash.example.com]
  server:
    host: api.udash.example.com
    tls:
      - secretName: udash-api-tls
        hosts: [api.udash.example.com]
```

### With Ingress (split domain and custom sub-paths)

Serves the front at `domain.example/project` and the API at `api.domain.example/updatecli`.
Set `ingress.traefik.stripPrefix.enabled: true` and the chart automatically creates all needed
Traefik Middlewares and wires their annotations:

- **Front**: `StripPrefix /project` → nginx receives `/`
- **Server**: `StripPrefix /updatecli` → `AddPrefix /api` → backend receives `/api/*`

Requires Traefik CRDs (`traefik.io/v1alpha1`) to be installed:

```yaml
front:
  appBasePath: "/project"
  apiBaseUrl: "https://api.domain.example/updatecli"

ingress:
  enabled: true
  className: traefik
  hosts:
    - host: domain.example
  paths:
    front: "/project"
    server: "/api"
  traefik:
    stripPrefix:
      enabled: true   # creates Middlewares for both front and server automatically
  server:
    host: api.domain.example
    path: "/updatecli"
```

The chart renders:

| Middleware | Type | Effect |
|---|---|---|
| `<release>-strip-front` | StripPrefix `/project` | strips front sub-path before nginx |
| `<release>-strip-server` | StripPrefix `/updatecli` | strips external prefix on API host |
| `<release>-add-server` | AddPrefix `/api` | restores the `/api` prefix the backend expects |

## Uninstalling the Chart

```console
helm uninstall udash
```

## Configuration

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod scheduling. |
| autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler. |
| autoscaling.maxReplicas | int | `100` | Maximum number of replicas. |
| autoscaling.minReplicas | int | `1` | Minimum number of replicas. |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization percentage for autoscaling. |
| cnpg.database | string | `"udash"` | PostgreSQL database name created during cluster bootstrap. |
| cnpg.enabled | bool | `true` | Enable CloudNative-PG managed PostgreSQL cluster. When true, the chart provisions a CNPG Cluster and injects credentials automatically. Requires the CNPG operator to be installed separately. |
| cnpg.instances | int | `1` | Number of PostgreSQL instances in the CNPG cluster. |
| cnpg.owner | string | `"udash"` | PostgreSQL role/owner created during cluster bootstrap. |
| cnpg.storage.size | string | `"1Gi"` | Storage size for each PostgreSQL instance. |
| configMap.annotations | object | `{}` | Annotations to add to the ConfigMap. |
| configMap.name | string | `""` | The name of the ConfigMap used to store server/front configuration. If not set, a name is generated using the fullname template. |
| front.apiBaseUrl | string | `"/api"` | API base URL used by the browser. Use a relative path (e.g. "/api") for same-host routing. Use an absolute URL (e.g. "https://api.domain.example/api") for split-domain routing. |
| front.appBasePath | string | `"/"` | Base path for the SPA. Must match ingress.paths.front when using subpath routing. Example: set both ingress.paths.front and front.appBasePath to "/updatecli". |
| fullnameOverride | string | `""` | Full override for the chart name used in resource names. |
| imagePullSecrets | list | `[]` | Secrets for pulling images from private registries. |
| images.front.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-front image. |
| images.front.repository | string | `"ghcr.io/updatecli/udash-front"` | Repository for the udash-front image. |
| images.front.tag | string | `"v0.19.0@sha256:b220b047a7536ab3bd77a5a312da10a051802a674385cd50ac7df00e652c7e5e"` | Overrides the image tag whose default is the chart appVersion. |
| images.server.args | list | `["server","start"]` | Arguments for the udash-server container. |
| images.server.command | list | `["udash"]` | Command override for the udash-server container. |
| images.server.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-server image. |
| images.server.repository | string | `"ghcr.io/updatecli/udash"` | Repository for the udash-server image. |
| images.server.tag | string | `"v0.14.0@sha256:a52edcb9535d8c392a2e592bf7c3b4fc0c14ecd4b1360aa96639145038b5da75"` | Overrides the image tag whose default is the chart appVersion. |
| ingress.annotations | object | `{}` | Annotations to add to the front Ingress resource. For subpath routing, add the strip-prefix annotation for your ingress controller. nginx example:   nginx.ingress.kubernetes.io/rewrite-target: /$2   nginx.ingress.kubernetes.io/use-regex: "true" (and set ingress.paths.front to "/updatecli(/|$)(.*)") traefik example (requires a Middleware CR for stripprefix):   traefik.ingress.kubernetes.io/router.middlewares: <namespace>-<middlewarename>@kubernetescrd |
| ingress.className | string | `""` | IngressClass name (Kubernetes >= 1.18). |
| ingress.enabled | bool | `false` | Enable Ingress resource creation. |
| ingress.hosts | list | `[{"host":"udash.local"}]` | Ingress host rules for the front. Traffic is forwarded according to ingress.paths. |
| ingress.paths.front | string | `"/"` | Path prefix for udash-front on same-host routing. For subpath routing (e.g. "/updatecli"), also set front.appBasePath to the same value and add a strip-prefix annotation so nginx receives "/" instead of "/updatecli/...". |
| ingress.paths.server | string | `"/api"` | Path prefix for udash-server on same-host routing (when ingress.server.host is empty). |
| ingress.server.annotations | object | `{}` | Annotations to add to the server Ingress resource. |
| ingress.server.host | string | `""` | Optional separate hostname for the API server. When empty (default): udash-server is routed via ingress.paths.server on each front host. When set: a second Ingress is created for this host routing to udash-server. |
| ingress.server.path | string | `"/api"` | Path prefix for udash-server on the separate server host. |
| ingress.server.tls | list | `[]` | TLS configuration for the server Ingress. |
| ingress.tls | list | `[]` | TLS configuration for the front Ingress. |
| ingress.traefik.stripPrefix.enabled | bool | `false` | When true, create Traefik Middleware resources and wire their annotations automatically. Front: a StripPrefix Middleware strips ingress.paths.front (useful when it is not "/"). Server: a StripPrefix + AddPrefix Middleware chain rewrites ingress.server.path to ingress.paths.server ("/api") — only rendered when ingress.server.host is set. Example: external /updatecli/* → strip /updatecli → add /api → backend sees /api/*. Requires Traefik CRDs (traefik.io/v1alpha1) to be installed in the cluster. |
| nameOverride | string | `""` | Override for the chart name used in resource names. |
| nodeSelector | object | `{}` | Node selector for pod scheduling. |
| podAnnotations | object | `{}` | Annotations to add to all pods. |
| podSecurityContext | object | `{}` | Pod-level security context. |
| readonly | bool | `true` | Run the udash-server in read-only / dry-run mode (no authentication required). Set to `false` to enable full OAuth2 authentication. |
| replicaCount | int | `1` | Number of replicas for the udash-server and udash-front deployments. |
| resources | object | `{}` | Resource requests and limits for all containers. Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| secrets.auth.annotations | object | `{}` | Annotations to add to the auth Secret. |
| secrets.auth.stringdata.audience | string | `"https://udash.example/api"` | OAuth2 audience. |
| secrets.auth.stringdata.clientid | string | `"xxx.example"` | OAuth2 client ID. |
| secrets.auth.stringdata.issuer | string | `"https://oauth.example"` | OAuth2 issuer URL. |
| secrets.auth.stringdata.mode | string | `"none"` | Authentication mode. Supported values: `oauth`, `none`. |
| secrets.database.annotations | object | `{}` | Annotations to add to the database Secret. |
| secrets.database.stringdata.uri | string | `"postgres://postgres:5432/udash?sslmode=disable"` | PostgreSQL connection URI used by the udash-server. |
| secrets.name | string | `""` | The name of the Secret used to store credentials. If not set, a name is generated using the fullname template. |
| securityContext | object | `{}` | Container-level security context. |
| service.port | int | `80` | Service port. |
| service.type | string | `"ClusterIP"` | Kubernetes Service type. |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account. |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created. |
| serviceAccount.name | string | `""` | The name of the service account to use. If not set and create is true, a name is generated using the fullname template. |
| tolerations | list | `[]` | Tolerations for pod scheduling. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
