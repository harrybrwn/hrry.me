{{ $refresh := "24h0m0s" -}}
{{ if (index . "refresh") -}}
{{ $refresh := .refresh -}}
{{ end -}}
{{ $environment := .environment -}}
{{ range .secrets -}}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .name }}
  {{- if (index . "ns" )}}
  namespace: {{ .ns }}
  {{- else }}
  namespace: default
  {{- end }}
  labels:
    environment: {{ $environment }}
spec:
  refreshPolicy: OnChange
  refreshInterval: {{ $refresh }}
  secretStoreRef:
    name: aws-ssm-store
    kind: ClusterSecretStore
  target:
    name: {{ .name }}
    creationPolicy: {{ if (index . "policy") -}}
      {{ if eq .policy "merge" -}}
        CreateOrMerge
      {{- else -}}
        {{ title .policy }}
      {{- end }}
    {{- else -}}
      Owner
    {{- end }}
    template:
      metadata:
        labels:
          environment: {{ $environment }}
        annotations:
          replicator.v1.mittwald.de/replication-allowed: 'true'
          replicator.v1.mittwald.de/replication-allowed-namespaces: .*
  data:
    {{- $secret := .secret }}
    {{- range .keys }}
    - secretKey: {{ .name }}
      remoteRef:
        key: {{ $secret }}
        {{- if (index . "key") }}
        property: {{ .key }}
        {{- else }}
        #property: {{ .name }}
        {{- end}}
    {{- end }}
{{ end -}}
