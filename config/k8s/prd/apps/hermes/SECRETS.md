# Secrets

Hermes needs four secret values. They live in **AWS Parameter Store** (SSM,
`us-west-2`), in the same JSON document the rest of the cluster already reads:

```
/homelab/k8s/secrets
```

That single parameter is a JSON object of `property -> value` pairs. Add these
four keys to it — the `ExternalSecret` in `chart.yml` pulls each one by
`property` name and turns them into one Kubernetes Secret
(`hermes-hermes-agent-env`) that the pod reads as environment variables.

## What to add

| Property in `/homelab/k8s/secrets` | Env var it becomes | What it is |
|---|---|---|
| `hermes-openrouter-api-key` | `OPENROUTER_API_KEY` | OpenRouter API key (`sk-or-...`). The agent's model provider. |
| `hermes-dashboard-username` | `HERMES_DASHBOARD_BASIC_AUTH_USERNAME` | Login for the dashboard on 9119 **and** the webapp on 9120. |
| `hermes-dashboard-password` | `HERMES_DASHBOARD_BASIC_AUTH_PASSWORD` | Password for the same two UIs. Both refuse to start without one. |
| `hermes-api-server-key` | `API_SERVER_KEY` | Bearer token for the API on 8642. Any random string; clients send it as `Authorization: Bearer <key>`. |

## Adding them

The parameter is shared by other services, so **do not overwrite the whole
document** — read it, add the four keys, write it back:

```bash
aws ssm get-parameter --region us-west-2 --with-decryption \
  --name /homelab/k8s/secrets --query Parameter.Value --output text > secrets.json

# edit secrets.json and add the four keys shown above, then:
aws ssm put-parameter --region us-west-2 --name /homelab/k8s/secrets \
  --type SecureString --overwrite --value "$(cat secrets.json)"
rm secrets.json
```

Generate the three non-provider values with `openssl rand -hex 32` (the OpenRouter
key comes from https://openrouter.ai/keys).

## How they reach the pod

`external-secrets` syncs the parameter into the `hermes` namespace once an hour
(`externalSecret.refreshInterval: 1h`), and `reloader` restarts the deployment
when the resulting Secret changes. So after adding a key:

```bash
kubectl -n hermes get externalsecret hermes-hermes-agent-env   # STATUS should be SecretSynced
kubectl -n hermes rollout status deploy/hermes-hermes-agent
```

If a key is missing from the parameter, the ExternalSecret sync fails as a
whole (it is all-or-nothing, not per-key). On a fresh install the Secret is then
never created and the pod sits in `CreateContainerConfigError` until every key
exists; on a running install it keeps the last good values instead of partially
updating.

## Notes

- Nothing here is stored in git. The names above are the only thing in the repo.
- Values are read by the container as env vars — they are never written into
  `HERMES_HOME/config.yaml`.
- `config.yaml` (model, dashboard/webapp URLs) is seeded into the PVC on first
  start only; secrets are re-read on every pod start.
