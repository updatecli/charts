# udash-agent

![Version: 0.23.0](https://img.shields.io/badge/Version-0.23.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.101.0](https://img.shields.io/badge/AppVersion-0.101.0-informational?style=flat-square)

Udash Agent, is the Updatecli DASHboard agent running Updatecli to check your repositories updates.

The **udash-agent** chart deploys Updatecli as a scheduled agent inside your Kubernetes cluster. It runs Updatecli periodically (via CronJobs) and ships the results to a [Udash](https://github.com/updatecli/udash) instance for centralised reporting.

## Architecture

| Component | Image | Description |
|-----------|-------|-------------|
| `agentrelay` | `ghcr.io/updatecli/udash` | A Udash server running **without authentication**, reachable only inside the cluster at `http://agentrelay/api`. Agent CronJobs POST their reports here. |
| `agent-<id>` (CronJob) | `ghcr.io/updatecli/updatecli` | One CronJob per entry in `.Values.agents`. Runs `updatecli compose diff` on the configured schedule. |
| Argo CronWorkflows (optional) | — | When `.Values.workflows` is set and Argo Workflows is installed, one `CronWorkflow` per entry clones a Git repository and runs `updatecli compose diff`. |

## Prerequisites

- Kubernetes 1.19+
- Helm 3.x
- A running [Udash](https://updatecli.github.io/charts) instance (the `udash` chart) with its PostgreSQL database

## Get Repository Info

```console
helm repo add updatecli https://updatecli.github.io/charts
helm repo update
```

## TL;DR

```console
helm install udash-agent updatecli/udash-agent
```

## Installing the Chart

### Minimal installation

```console
helm install udash-agent updatecli/udash-agent \
  --set secrets.database.stringdata.uri="postgres://user:pass@postgres:5432/udash?sslmode=disable"
```

### With a GitHub agent

Pass a GitHub token and define at least one agent entry:

```yaml
# my-values.yaml
secrets:
  agent:
    environments:
      GITHUB_TOKEN: "ghp_xxxx"
      GITHUB_ACTOR: "my-github-user"

agents:
  github-repos:
    schedule: "0 * * * *"
    valuesFiles:
      scm.yaml: |
        scm:
          enabled: true
          user: updatecli
          owner: my-org
          repository: my-repo
          branch: main
```

```console
helm install udash-agent updatecli/udash-agent -f my-values.yaml
```

### With Argo Workflows (optional)

Requires [Argo Workflows](https://argoproj.github.io/argo-workflows/) installed in the cluster.

```yaml
# my-values.yaml
workflows:
  - url: "https://github.com/my-org/my-repo.git"
    branch: "main"
    composefile: "updatecli-compose.yaml"
```

```console
helm install udash-agent updatecli/udash-agent -f my-values.yaml
```

## Uninstalling the Chart

```console
helm uninstall udash-agent
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
| configMap.name | string | `""` | The name of the ConfigMap used to store agent configuration files. If not set, a name is generated using the fullname template. |
| defaultComposeFile | string | See values.yaml | Default Updatecli compose configuration file mounted at `/etc/updatecli/updatecli-compose.yaml` in each agent CronJob. Can be overridden per agent. |
| defaultSchedule | string | `"0 * * * *"` | Default cron schedule for all agent CronJobs. Individual agents can override this with their own `schedule` field. |
| defaultUdashConfig | string | See values.yaml | Default Udash connection configuration injected into each agent at `/home/updatecli/.config/updatecli/udash.json`. Can be overridden per agent. |
| fullnameOverride | string | `""` | Full override for the chart name used in resource names. |
| imagePullSecrets | list | `[]` | Secrets for pulling images from private registries. |
| images.agent.args | list | `["compose","diff","--file","/etc/updatecli/updatecli-compose.yaml","--experimental"]` | Arguments for the agent container. |
| images.agent.command | list | `["updatecli"]` | Command override for the agent container. |
| images.agent.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the agent image. |
| images.agent.repository | string | `"ghcr.io/updatecli/updatecli"` | Repository for the Updatecli agent image. |
| images.agent.tag | string | `"v0.116.3@sha256:1fc3729536ffd5b902a94d721e62beee482b4ae3968a6e2e79b6ce92b5eb5fdd"` | Overrides the image tag whose default is the chart appVersion. |
| images.agentrelay.args | list | `["server","start"]` | Arguments for the AgentRelay container. |
| images.agentrelay.command | list | `["udash"]` | Command override for the AgentRelay container. |
| images.agentrelay.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the AgentRelay image. |
| images.agentrelay.repository | string | `"ghcr.io/updatecli/udash"` | Repository for the AgentRelay image (Udash server running without authentication, cluster-internal only). |
| images.agentrelay.tag | string | `"v0.14.0@sha256:a52edcb9535d8c392a2e592bf7c3b4fc0c14ecd4b1360aa96639145038b5da75"` | Overrides the image tag whose default is the chart appVersion. |
| nameOverride | string | `""` | Override for the chart name used in resource names. |
| nodeSelector | object | `{}` | Node selector for pod scheduling. |
| persistence.accessModes | list | `["ReadWriteOnce"]` | Access modes for the PersistentVolumeClaim. |
| persistence.annotations | object | `{}` | Annotations to add to the PersistentVolumeClaim. |
| persistence.enabled | bool | `false` | Enable a PersistentVolumeClaim to persist the Updatecli tmp folder (`/tmp/updatecli`) across executions. One PVC is created per agent CronJob and per Argo workflow entry. |
| persistence.size | string | `"1Gi"` | Size of the PersistentVolumeClaim. |
| persistence.storageClassName | string | `""` | Storage class name for the PersistentVolumeClaim. Leave empty to use the cluster default. |
| podAnnotations | object | `{}` | Annotations to add to all pods. |
| podSecurityContext | object | `{}` | Pod-level security context. |
| resources | object | `{}` | Resource requests and limits for all containers. Ref: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/ |
| secrets.agent.annotations | object | `{}` | Annotations to add to the agent Secret. |
| secrets.agent.environments | object | `{}` | Map of environment variables injected into every agent CronJob container (e.g. GITHUB_TOKEN). Values are stored in a Secret. |
| secrets.database.annotations | object | `{}` | Annotations to add to the database Secret. |
| secrets.database.stringdata.uri | string | `"postgres://postgres:5432/udash?sslmode=disable"` | PostgreSQL connection URI used by the AgentRelay to store Updatecli reports. |
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
