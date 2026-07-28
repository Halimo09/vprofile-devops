{{/*
Expand the chart name.
*/}}
{{- define "rabbitmq.name" -}}
rabbitmq
{{- end }}

{{/*
Create a fully qualified app name.
*/}}
{{- define "rabbitmq.fullname" -}}
{{ printf "%s-rabbitmq" .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rabbitmq.labels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: rabbitmq
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rabbitmq.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rabbitmq.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}