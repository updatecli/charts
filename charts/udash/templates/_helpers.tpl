{{/*
Expand the name of the chart.
*/}}
{{- define "udash.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "udash.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "udash.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "udash.labels" -}}
helm.sh/chart: {{ include "udash.chart" . }}
{{ include "udash.selectorLabels.front" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "udash.selectorLabels.agent" -}}
app.kubernetes.io/name: {{ include "udash.name" . }}-agent
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "udash.selectorLabels.server" -}}
app.kubernetes.io/name: {{ include "udash.name" . }}-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "udash.selectorLabels.front" -}}
app.kubernetes.io/name: {{ include "udash.name" . }}-front
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "udash.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "udash.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use for configuration
*/}}
{{- define "udash.configMapName" -}}
{{- default (include "udash.fullname" .) .Values.configMap.name }}
{{- end }}

{{/*
Create the name of the secrets use by udash agents
*/}}
{{- define "udash.secretName" -}}
{{- default (include "udash.fullname" .) .Values.secrets.name }}
{{- end }}

{{/*
Create the name of the CloudNative-PG cluster
*/}}
{{- define "udash.cnpgClusterName" -}}
{{- printf "%s-db" (include "udash.fullname" .) }}
{{- end }}

{{/*
OIDC issuer as a full URL, for the frontend.
The API server accepts a bare host and prepends https:// itself, but the SPA hands this
value straight to the OIDC discovery endpoint, so it always needs a scheme.
In zitadel mode the server is configured from auth.zitadel.domain and never reads
auth.issuer, so fall back to it rather than leaving the SPA on the placeholder issuer.
*/}}
{{- define "udash.oauthDomain" -}}
{{- $issuer := .Values.auth.issuer | default "" -}}
{{- if and (eq .Values.auth.mode "zitadel") .Values.auth.zitadel.domain -}}
{{- $issuer = .Values.auth.zitadel.domain -}}
{{- end -}}
{{- if or (hasPrefix "http://" $issuer) (hasPrefix "https://" $issuer) -}}
{{- $issuer -}}
{{- else -}}
{{- printf "https://%s" $issuer -}}
{{- end -}}
{{- end }}

{{/*
Name of the Secret holding the Zitadel service account key.
Prefers an existing Secret when one is referenced, otherwise the chart-managed one.
*/}}
{{- define "udash.zitadelKeySecretName" -}}
{{- if .Values.auth.zitadel.keyFile.existingSecret -}}
{{- .Values.auth.zitadel.keyFile.existingSecret -}}
{{- else -}}
{{- printf "%s-auth-zitadel" (include "udash.secretName" .) -}}
{{- end -}}
{{- end }}

{{/*
Whether a Zitadel service account key is configured, inline or by reference.
*/}}
{{- define "udash.zitadelKeyEnabled" -}}
{{- if and .Values.auth.enabled (eq .Values.auth.mode "zitadel") -}}
{{- if or .Values.auth.zitadel.keyFile.content .Values.auth.zitadel.keyFile.existingSecret -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Directory the Zitadel key Secret is mounted into. Deliberately outside /etc/udash, which
is already occupied by the server configuration ConfigMap volume.
*/}}
{{- define "udash.zitadelKeyMountPath" -}}
/etc/udash-auth
{{- end }}

{{/*
Create the name of the Traefik StripPrefix Middleware for the front ingress
*/}}
{{- define "udash.traefikStripFrontMiddlewareName" -}}
{{- printf "%s-strip-front" (include "udash.fullname" .) }}
{{- end }}

{{/*
Create the name of the Traefik StripPrefix Middleware for the server ingress
*/}}
{{- define "udash.traefikStripServerMiddlewareName" -}}
{{- printf "%s-strip-server" (include "udash.fullname" .) }}
{{- end }}

{{/*
Create the name of the Traefik AddPrefix Middleware for the server ingress
*/}}
{{- define "udash.traefikAddServerMiddlewareName" -}}
{{- printf "%s-add-server" (include "udash.fullname" .) }}
{{- end }}
