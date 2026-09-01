# udash

![Version: 0.34.0](https://img.shields.io/badge/Version-0.34.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

Udash, the Updatecli DASHboard

[Udash](https://github.com/updatecli/udash) is the Updatecli Dashboard, a web application that collects and displays Updatecli reports,
giving your team a centralised view of software update activity across all your repositories.

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

### With an external PostgreSQL

Disable CNPG and supply your own connection URI:

```console
helm install udash updatecli/udash \
  --set cnpg.enabled=false \
  --set secrets.database.stringdata.uri="postgres://user:pass@postgres:5432/udash?sslmode=disable"
```

## Authentication

Authentication is off by default: the API accepts unauthenticated requests and the frontend
shows no login UI. Enable it with the `auth` block, which configures both components at once.

```console
helm install udash updatecli/udash \
  --set auth.enabled=true \
  --set auth.issuer="https://auth.example" \
  --set auth.clientid="my-client-id" \
  --set "auth.audience[0]=https://udash.example/api"
```

### Registering the application with your provider

Register `udash-front` as a **User Agent / SPA** client using **PKCE**. The redirect URI is
derived from the browser origin and `front.appBasePath` rather than configured directly, so
register `https://<your front host><front.appBasePath>` as **both** the allowed redirect URI
and the post-logout redirect URI. `helm install` prints the exact URL for your values.

### `auth.issuer`

Accepted with or without a scheme — `https://` is assumed when omitted. It must match the
`iss` claim your provider puts in its tokens **exactly**, including any trailing slash: Auth0
issues one, Zitadel and Keycloak do not. A mismatch rejects every token.

### `auth.visibility`

| Value | Effect |
|---|---|
| `public` (default) | Read endpoints stay open to anyone; writes require a valid token. |
| `private` | Every API endpoint requires a valid token. |

The chart writes this to both sides — `server.auth.visibility` for the API and
`AUTH_VISIBILITY` for the SPA. They must agree, and the frontend defaults the key to
`private` where the API defaults to `public`, so letting the chart set both is the point.
`AUTH_VISIBILITY` needs `udash-front` >= `v0.25.0`; older images ignore it and always ask
for a login before showing data.

### Roles and permissions

Udash has three permissions, in increasing order: `viewer`, `publisher`, `admin`. Publishing
reports requires `publisher`. The server maps identity provider roles onto them through
`auth.roles`:

```yaml
auth:
  roles:
    claim: realm_access.roles          # where your provider puts the roles
    mapping:
      admin: ["udash.admin"]
      publisher: ["ci-bot", "udash.publisher"]
    default: viewer                    # nobody matched -> least privilege
```

> **Set `auth.roles.claim` in `oidc` mode.** Only `zitadel` mode infers it. Left empty, the
> server reads no roles at all, every authenticated identity falls back to
> `auth.roles.default` (`viewer`), and **nobody can publish**. The server logs a warning
> saying so at startup.

`auth.roles.mapping` is keyed by Udash permission, not by provider role. Left empty it
defaults to `udash.admin` / `udash.publisher` / `udash.viewer`.

### API tokens

With authentication enabled the API issues personal access tokens (prefix `udash_pat_`) that
`updatecli` can use to publish. `auth.roles.resolver` decides what a token is allowed to do:
`snapshot` (the default) freezes the permission its creator had at issue time, while
`zitadel` re-reads the creator's current grants on use and therefore requires
`auth.mode: zitadel`. `auth.roles.cacheTTL` bounds how long a resolved permission is reused.

### `auth.scope`

Left empty, the frontend requests `openid profile email offline_access` (`offline_access`
enables silent token renewal). Zitadel additionally requires the project audience scope
`urn:zitadel:iam:org:project:id:<PROJECT_ID>:aud`, or the API rejects the token:

```console
--set auth.scope="openid profile email offline_access urn:zitadel:iam:org:project:id:123:aud"
```

### Zitadel mode

`auth.mode=zitadel` uses Zitadel's own authorization SDK instead of generic JWT validation,
and needs a service account key. Provide it inline, or reference a Secret you manage yourself:

```yaml
auth:
  enabled: true
  mode: zitadel
  zitadel:
    domain: my-instance.region.zitadel.cloud
    keyFile:
      existingSecret: my-zitadel-key
      key: key.json
  roles:
    mapping:
      admin: ["udash.admin"]
```

Access is granted through `auth.roles` rather than a single required role. In this mode the
chart also points the SPA at `auth.zitadel.domain`, so `auth.issuer` is not needed.

The key is mounted into `udash-server` at `/etc/udash-auth/`, deliberately outside
`/etc/udash/`, which the configuration ConfigMap already occupies.

> **Version requirements.** Runtime auth configuration reached `udash-front` in `v0.23.0`;
> `AUTH_VISIBILITY` in `v0.25.0`. Releases up to `v0.22.0` had authentication compiled into the
> bundle at build time, so they show no login UI regardless of these values. On the API side
> the `oidc` mode and the roles model need `udash` `v0.17.1`. The chart pins images that
> satisfy all of this.

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

## Upgrading

### To 0.34.0

Authentication was reworked into a single top-level `auth` block, and the server-side schema
was renamed to follow udash `v0.17.1`:

| Removed | Replacement |
|---|---|
| `readonly` | `auth.enabled` (inverted: `readonly: true` is the default `auth.enabled: false`) |
| `secrets.auth.stringdata.mode` | `auth.mode` |
| `secrets.auth.stringdata.issuer` | `auth.issuer` |
| `secrets.auth.stringdata.clientid` | `auth.clientid` |
| `secrets.auth.stringdata.audience` | `auth.audience` (now a **list**) |
| `auth.mode: oauth` | `auth.mode: oidc` |
| `auth.zitadel.role` | `auth.roles.mapping` |

**`auth.mode: oauth` is now rejected by the chart**, because udash `v0.17.1` renamed the mode
to `oidc` and refuses to start on the old value rather than silently serving an open API. The
chart fails the render with a message pointing at the rename.

New in this release: `auth.roles.*` (see [Roles and permissions](#roles-and-permissions)) and
`AUTH_VISIBILITY` for the SPA. Both images are bumped — udash `v0.17.1` and udash-front
`v0.25.0` — which is the minimum for the above.

Upgrading the server to `v0.17.1` runs two new migrations on first boot
(`000012_create_api_tokens`, `000013_alter_pipelineReports_attribution`).

The `<release>-auth` Secret is no longer created. It was referenced by no workload, and none
of its contents were secret — a public SPA publishes its client ID, issuer and audience to
every browser that loads it. Only the Zitadel service account key gets a Secret now.

If you never set `readonly: false`, no action is needed. If you did, note that the previous
release did not actually apply your OAuth settings: they were written as flat keys the server
never read, so `auth` was effectively enabled with an empty issuer. Move them to the new block
and authentication will work for the first time.

## Configuration

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity rules for pod scheduling. |
| auth.audience | list | `["https://udash.example/api"]` | OAuth2 audiences the API server accepts in a token. |
| auth.clientid | string | `"xxx.example"` | OAuth2 client ID of the frontend SPA application. Register it with the provider as a User Agent / SPA client using PKCE. |
| auth.enabled | bool | `false` | Enable authentication for both the udash-server API and the udash-front SPA. When false, the server requires no authentication and the frontend shows no login UI. |
| auth.issuer | string | `"https://oauth.example"` | OIDC issuer, with or without a scheme (`https://` is assumed when omitted). Used by the server to validate tokens and by the frontend for OIDC discovery. It must match the `iss` claim your provider issues exactly, including any trailing slash (Auth0 issues one, Zitadel and Keycloak do not). |
| auth.mode | string | `"oidc"` | Authentication mode. Supported values: `oidc`, `zitadel`. Renamed from `oauth` in udash v0.17.1; the old value is now a fatal server error. |
| auth.roles.cacheTTL | string | `""` | How long a resolved permission is reused before being looked up again, e.g. `60s`. Empty uses the server default (60s). |
| auth.roles.claim | string | `""` | Token claim holding the identity provider roles. Providers disagree on both the name and the shape: Zitadel uses an object keyed by role name, Keycloak and Auth0 an array of strings; both are accepted. Only `zitadel` mode infers it (`urn:zitadel:iam:org:project:roles`). In `oidc` mode leaving this empty means no roles are read at all and every authenticated identity falls back to `auth.roles.default` (`viewer`), which cannot publish reports -- so set it if anyone needs to write. Examples: `realm_access.roles` (Keycloak), `https://your.app/roles` (Auth0). |
| auth.roles.default | string | `""` | Permission granted to an authenticated identity matching no role at all. One of `viewer`, `publisher`, `admin`. Empty uses the server default (`viewer`). |
| auth.roles.mapping | object | `{}` | Identity provider roles granting each Udash permission, keyed by permission. Empty uses the server default: `admin: [udash.admin]`, `publisher: [udash.publisher]`, `viewer: [udash.viewer]`. Example:   mapping:     admin: ["udash.admin"]     publisher: ["ci-bot", "udash.publisher"] |
| auth.roles.resolver | string | `""` | How the permission behind an Udash API token is resolved. `snapshot` trusts the permission recorded when the token was created; `zitadel` re-reads the current grants and requires `auth.mode: zitadel`. Empty uses the server default. |
| auth.scope | string | `""` | OAuth2 scopes requested by the frontend. Leave empty to use the application default (`openid profile email offline_access`). Zitadel additionally requires `urn:zitadel:iam:org:project:id:<PROJECT_ID>:aud` so the token is accepted by the API. |
| auth.visibility | string | `"public"` | API visibility. `public` leaves read endpoints open to anyone and requires authentication only for writes. `private` requires authentication everywhere. |
| auth.zitadel.domain | string | `""` | Zitadel domain, e.g. `xxx.region.zitadel.cloud`. Only used when mode is `zitadel`. |
| auth.zitadel.keyFile.content | string | `""` | Inline Zitadel service account key JSON. When set, the chart creates a Secret and mounts it into the udash-server. |
| auth.zitadel.keyFile.existingSecret | string | `""` | Name of an existing Secret holding the service account key, used instead of inlining it above. |
| auth.zitadel.keyFile.key | string | `"key.json"` | Key within the Secret that holds the service account key JSON. |
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
| front.maxHistoryDays | int | `30` | How many days of history the UI may query. Capped at 366 by the API server. |
| fullnameOverride | string | `""` | Full override for the chart name used in resource names. |
| imagePullSecrets | list | `[]` | Secrets for pulling images from private registries. |
| images.front.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-front image. |
| images.front.repository | string | `"ghcr.io/updatecli/udash-front"` | Repository for the udash-front image. |
| images.front.tag | string | `"v0.25.0@sha256:1b4977cc534b643a61fadfd8da27ef771e95b55af1ada038e1086a165205552d"` | Overrides the image tag whose default is the chart appVersion. |
| images.server.args | list | `["server","start"]` | Arguments for the udash-server container. |
| images.server.command | list | `["udash"]` | Command override for the udash-server container. |
| images.server.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-server image. |
| images.server.repository | string | `"ghcr.io/updatecli/udash"` | Repository for the udash-server image. |
| images.server.tag | string | `"v0.17.1@sha256:76450ac9e81edfd705b02dc66bd66b226e6620a3cb4bd0488c4dd9a461266e4c"` | Overrides the image tag whose default is the chart appVersion. |
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
| replicaCount | int | `1` | Number of replicas for the udash-server and udash-front deployments. |
| resources | object | `{}` | Resource requests and limits for all containers. Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
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
