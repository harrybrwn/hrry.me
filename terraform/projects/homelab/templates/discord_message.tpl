{{ define "_values_list" -}}
	{{- if len .Values }}{{ $first := true -}}
		{{- range $refID, $value := .Values -}}
		 	{{- if ne $refID "metric" -}}
				{{- if $first }}{{ $first = false }}{{ else }}, {{ end -}}
				{{- $refID }}={{ $value -}}
			{{- end -}}
		{{- end -}}
	{{- else }}[no value]{{ end -}}
{{- end }}

{{ define "discord.title" -}}
{{- if gt (.Alerts.Firing | len) 0 }}:red_circle: {{ end -}}
{{- if gt (.Alerts.Resolved | len) 0 }}:white_check_mark: {{ end -}}
[**{{ .Status | title }}**{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ if gt (.Alerts.Resolved | len) 0 }}, Resolved:{{ .Alerts.Resolved | len }}{{ end }}{{ end }}]{{" "}}{{ .GroupLabels.SortedPairs.Values | join " " }} {{ if gt (len .CommonLabels) (len .GroupLabels) }}({{ with .CommonLabels.Remove .GroupLabels.Names }}{{ .Values | join " " }}{{ end }}){{ end }}
{{- end }}

{{ define "_alert_list" -}}
{{- range . }}
Value: {{ template "_values_list" . }}
{{- end }}{{ end }}

{{ define "${discord_template}" }}
{{ template "discord.title" . }}
{{ template "default.message" . -}}
Got {{ len .Alerts }} alert{{ if gt 1 (len .Alerts) }}s{{ end }}.
<@&${discord_role_id}>
{{ end }}
