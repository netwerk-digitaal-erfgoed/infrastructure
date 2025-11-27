{{/*
Expand the name of the app.
Defaults to the release name (which equals the HelmRelease metadata.name in Flux).
*/}}
{{- define "nde-app.name" -}}
{{- .Values.nameOverride | default .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Defaults to the release name (which equals the HelmRelease metadata.name in Flux).
*/}}
{{- define "nde-app.fullname" -}}
{{- .Values.fullnameOverride | default .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nde-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nde-app.labels" -}}
helm.sh/chart: {{ include "nde-app.chart" . }}
{{ include "nde-app.selectorLabels" . }}
app: {{ include "nde-app.fullname" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nde-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nde-app.name" . }}
{{- end }}

{{/*
Generate flux resource name for a container.
Args: (fluxNameOverride, fullname, containerName)
*/}}
{{- define "nde-app.fluxName" -}}
{{- $override := index . 0 -}}
{{- $fullname := index . 1 -}}
{{- $containerName := index . 2 -}}
{{- if $override -}}
{{- $override -}}
{{- else if eq $containerName "app" -}}
{{- $fullname -}}
{{- else -}}
{{- printf "%s-%s" $fullname $containerName -}}
{{- end -}}
{{- end }}
