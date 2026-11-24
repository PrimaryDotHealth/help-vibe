{{- define "helpvibe.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "helpvibe.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "helpvibe.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "helpvibe.secretName" -}}
{{- .Values.existingSecret | default (include "helpvibe.fullname" .) -}}
{{- end -}}

{{- define "helpvibe.postgresName" -}}
{{- printf "%s-postgresql" (include "helpvibe.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "helpvibe.dbHost" -}}
{{- if .Values.postgresql.enabled -}}
{{- include "helpvibe.postgresName" . -}}
{{- else -}}
{{- required "externalDatabase.host is required when postgresql.enabled is false" .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}
