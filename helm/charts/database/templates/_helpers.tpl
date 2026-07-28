{{- define "database.name" -}}
database
{{- end }}

{{- define "database.fullname" -}}
{{ printf "%s-database" .Release.Name }}
{{- end }}

{{- define "database.labels" -}}
app.kubernetes.io/name: {{ include "database.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "database.selectorLabels" -}}
app.kubernetes.io/name: {{ include "database.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}