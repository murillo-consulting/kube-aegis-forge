{{/* Stable workload name bounded by Kubernetes DNS limits. */}}
{{- define "demo-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Release-aware name prevents collisions across environments. */}}
{{- define "demo-api.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "demo-api.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Common labels keep selectors, dashboards, and policies aligned. */}}
{{- define "demo-api.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "demo-api.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{/* Immutable selector labels never include a deploy-time version. */}}
{{- define "demo-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Digest wins over tag so promoted workloads are immutable. */}}
{{- define "demo-api.image" -}}
{{- if .Values.image.digest -}}
{{ printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else -}}
{{ printf "%s:%s" .Values.image.repository (required "image.tag is required without image.digest" .Values.image.tag) }}
{{- end -}}
{{- end }}

{{/* Service account defaults to the release-aware workload name. */}}
{{- define "demo-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "demo-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

