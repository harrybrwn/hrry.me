```sh
kubectl exec -n vault vault-0 -- vault operator init -format=json > keys-$(kubectl config current-context).json
```

```sh
kubectl exec -n vault vault-0 -it -- vault operator unseal "$(jq -r '.recovery_keys_b64[0]' keys-$(kubectl config current-context).json)"
kubectl exec -n vault vault-0 -it -- vault operator unseal "$(jq -r '.recovery_keys_b64[1]' keys-$(kubectl config current-context).json)"
kubectl exec -n vault vault-0 -it -- vault operator unseal "$(jq -r '.recovery_keys_b64[2]' keys-$(kubectl config current-context).json)"
```
