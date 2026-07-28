{{- define "memcached.name" -}}
memcached
{{- end }}

{{- define "memcached.fullname" -}}
{{ printf "%s-memcached" .Release.Name }}
{{- end }}

{{- define "memcached.labels" -}}
app.kubernetes.io/name: {{ include "memcached.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: memcached
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "memcached.selectorLabels" -}}
app.kubernetes.io/name: {{ include "memcached.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}