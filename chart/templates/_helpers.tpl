{{/*
Expand the name of the chart.
*/}}
{{- define "ai-taxi-anomaly-detector.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "ai-taxi-anomaly-detector.fullname" -}}
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
{{- define "ai-taxi-anomaly-detector.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ai-taxi-anomaly-detector.labels" -}}
helm.sh/chart: {{ include "ai-taxi-anomaly-detector.chart" . }}
{{ include "ai-taxi-anomaly-detector.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ai-taxi-anomaly-detector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ai-taxi-anomaly-detector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ai-taxi-anomaly-detector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ai-taxi-anomaly-detector.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MinIO fullname (published ai-architecture-charts MinIO chart uses minio)
*/}}
{{- define "minio.fullname" -}}
minio
{{- end }}

{{/*
MinIO secret name
*/}}
{{- define "minio.secretName" -}}
minio
{{- end }}

{{/*
Notebook resource name (must match container name for OpenShift AI)
*/}}
{{- define "ai-taxi-anomaly-detector.notebookName" -}}
{{- printf "%s-notebook" (include "ai-taxi-anomaly-detector.fullname" .) }}
{{- end }}

{{/*
Whether to bundle notebooks in a ConfigMap from chart/files/notebooks
*/}}
{{- define "ai-taxi-anomaly-detector.embeddedNotebooksEnabled" -}}
{{- if or .Values.notebook.notebooks.embedFromChart (and .Values.notebook.gitSync.enabled .Values.notebook.gitSync.fallbackToEmbedded) -}}
true
{{- end -}}
{{- end }}
