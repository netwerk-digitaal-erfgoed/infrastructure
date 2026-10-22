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
Render a Job spec – retries, deadline and pod template – from a cronjobs[] or jobs[] entry.
Args: (root, job, valuesKey); valuesKey names the list in error messages.
backoffLimit is checked with hasKey, not with: 0 is a meaningful limit that `with` would drop.
*/}}
{{- define "nde-app.jobSpec" -}}
{{- $root := index . 0 -}}
{{- $job := index . 1 -}}
{{- $key := index . 2 -}}
{{- if hasKey $job "backoffLimit" }}
backoffLimit: {{ $job.backoffLimit }}
{{- end }}
{{- with $job.activeDeadlineSeconds }}
activeDeadlineSeconds: {{ . }}
{{- end }}
template:
  metadata:
    {{- if $root.Values.backup.enabled }}
    {{- $backupVols := include "nde-app.backupVolumeNames.cronjob" (list $root $job) }}
    {{- if $backupVols }}
    annotations:
      backup.velero.io/backup-volumes: {{ $backupVols | quote }}
    {{- end }}
    {{- end }}
    labels:
      {{- include "nde-app.selectorLabels" $root | nindent 6 }}
      app: {{ include "nde-app.fullname" $root }}-{{ $job.name }}
  spec:
    {{- if hasPrefix "ghcr.io" $job.image }}
    imagePullSecrets:
      - name: ghcr
    {{- end }}
    {{- with $job.priorityClassName }}
    priorityClassName: {{ . }}
    {{- end }}
    {{- with $job.securityContext }}
    securityContext:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $job.nodeSelector }}
    nodeSelector:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- with $job.affinity }}
    affinity:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- if hasKey $job "automountServiceAccountToken" }}
    automountServiceAccountToken: {{ $job.automountServiceAccountToken }}
    {{- end }}
    {{- with $job.initContainers }}
    initContainers:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    containers:
      - name: {{ $job.name }}
        image: {{ required (printf "%s[].image is required" $key) $job.image }}
        {{- with $job.imagePullPolicy }}
        imagePullPolicy: {{ . }}
        {{- end }}
        {{- with $job.command }}
        command:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $job.args }}
        args:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $job.env }}
        env:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $job.volumeMounts }}
        volumeMounts:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $job.resources }}
        resources:
          {{- toYaml . | nindent 10 }}
        {{- end }}
    {{- with $job.volumes }}
    volumes:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    restartPolicy: {{ $job.restartPolicy | default "OnFailure" }}
{{- end }}

{{/*
Return the Velero pre-backup hook command, as a JSON array, that writes the dump.
The dump goes to a temporary file first, so a failed dump leaves the previous one in place.
*/}}
{{- define "nde-app.backupDumpHookCommand" -}}
{{- $script := printf "set -e; { %s; } > /backup/dump.tmp; mv /backup/dump.tmp /backup/dump" (trim .Values.backup.dump.command) -}}
{{- list "/bin/sh" "-c" $script | toRawJson -}}
{{- end }}

{{/*
Return comma-separated volume names for Velero backup annotation on workload pods.
Priority:
1) backup.volumes (manual override)
2) Auto-detect from statefulset volumes and PVC-backed pod volumes
With backup.dump.command set, the dump volume replaces the auto-detected ones.
*/}}
{{- define "nde-app.backupVolumeNames.workload" -}}
{{- $vols := list -}}

{{- if .Values.backup.dump.command }}
	{{- $vols = append $vols "dump" -}}
{{- end }}

{{- if .Values.backup.volumes }}
	{{- range .Values.backup.volumes }}
		{{- $vols = append $vols . -}}
	{{- end }}
{{- else if not .Values.backup.dump.command }}
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
