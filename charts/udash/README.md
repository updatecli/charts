# udash

![Version: 0.25.0](https://img.shields.io/badge/Version-0.25.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

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
- A running **PostgreSQL** instance accessible from the cluster

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

### Read-only mode (default)

In read-only mode the server runs without authentication (dry-run). No OAuth credentials are required.

```console
helm install udash updatecli/udash \
  --set secrets.database.stringdata.uri="postgres://user:pass@postgres:5432/udash?sslmode=disable"
```

### Full mode with OAuth2

Set `readonly: false` and supply your OAuth2 provider details:

```console
helm install udash updatecli/udash \
  --set readonly=false \
  --set secrets.database.stringdata.uri="postgres://user:pass@postgres:5432/udash?sslmode=disable" \
  --set secrets.auth.stringdata.clientid="my-client-id" \
  --set secrets.auth.stringdata.audience="https://udash.example/api" \
  --set secrets.auth.stringdata.issuer="https://auth.example"
```

### With Ingress

```console
helm install udash updatecli/udash \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=udash.example.com"
```

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
| configMap.annotations | object | `{}` | Annotations to add to the ConfigMap. |
| configMap.name | string | `""` | The name of the ConfigMap used to store server/front configuration. If not set, a name is generated using the fullname template. |
| fullnameOverride | string | `""` | Full override for the chart name used in resource names. |
| imagePullSecrets | list | `[]` | Secrets for pulling images from private registries. |
| images.front.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-front image. |
| images.front.repository | string | `"ghcr.io/updatecli/udash-front"` | Repository for the udash-front image. |
| images.front.tag | string | `"v0.17.0@sha256:9afa7d7b0d8a8bc70154b83fd3ded620714cd79443c9e17a72bc5d7611c22f28"` | Overrides the image tag whose default is the chart appVersion. |
| images.server.args | list | `["server","start"]` | Arguments for the udash-server container. |
| images.server.command | list | `["udash"]` | Command override for the udash-server container. |
| images.server.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the udash-server image. |
| images.server.repository | string | `"ghcr.io/updatecli/udash"` | Repository for the udash-server image. |
| images.server.tag | string | `"v0.14.0@sha256:a52edcb9535d8c392a2e592bf7c3b4fc0c14ecd4b1360aa96639145038b5da75"` | Overrides the image tag whose default is the chart appVersion. |
| ingress.annotations | object | `{}` | Annotations to add to the Ingress resource. |
| ingress.className | string | `""` | IngressClass name (Kubernetes >= 1.18). |
| ingress.enabled | bool | `false` | Enable Ingress resource creation. |
| ingress.hosts | list | `[{"host":"udash.local"}]` | Ingress host rules. Traffic to `/` is forwarded to udash-front; traffic to `/api` is forwarded to udash-server. |
| ingress.tls | list | `[]` | TLS configuration for the Ingress. |
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
| secrets.auth.stringdata.mode | string | `"oauth"` | Authentication mode. Supported values: `oauth`. |
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
