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

{{/*
Return comma-separated volume names for Velero backup annotation on workload pods.
Priority:
1) backup.volumes (manual override)
2) Auto-detect from statefulset volumes and PVC-backed pod volumes
*/}}
{{- define "nde-app.backupVolumeNames.workload" -}}
{{- $vols := list -}}

{{- if .Values.backup.volumes }}
	{{- range .Values.backup.volumes }}
		{{- $vols = append $vols . -}}
	{{- end }}
{{- else }}
	{{- if and (eq .Values.workload.type "statefulset") .Values.persistence.enabled .Values.persistence.name }}
		{{- $vols = append $vols .Values.persistence.name -}}
	{{- end }}

	{{- range .Values.persistentVolumes }}
		{{- if .name }}
			{{- $vols = append $vols .name -}}
		{{- end }}
	{{- end }}

	{{- range .Values.volumes }}
		{{- if and .name .persistentVolumeClaim }}
			{{- $vols = append $vols .name -}}
		{{- end }}
	{{- end }}
{{- end }}

{{- join "," ($vols | uniq) -}}
{{- end }}

{{/*
Return comma-separated volume names for Velero backup annotation on cronjob pods.
Priority:
1) cronjobs[].backupVolumes
2) backup.volumes (manual override)
3) Auto-detect from cronjobs[].volumes where persistentVolumeClaim is used
*/}}
{{- define "nde-app.backupVolumeNames.cronjob" -}}
{{- $root := index . 0 -}}
{{- $job := index . 1 -}}
{{- $vols := list -}}

{{- if $job.backupVolumes }}
	{{- range $job.backupVolumes }}
		{{- $vols = append $vols . -}}
	{{- end }}
{{- else if $root.Values.backup.volumes }}
	{{- range $root.Values.backup.volumes }}
		{{- $vols = append $vols . -}}
	{{- end }}
{{- else }}
	{{- range $job.volumes }}
		{{- if and .name .persistentVolumeClaim }}
			{{- $vols = append $vols .name -}}
		{{- end }}
	{{- end }}
{{- end }}

{{- join "," ($vols | uniq) -}}
{{- end }}
