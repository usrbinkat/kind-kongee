```sh
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
helm upgrade --install --wait frontend podinfo/podinfo --create-namespace --namespace podinfo --values podinfo/frontend.yaml
helm upgrade --install --wait backend podinfo/podinfo --create-namespace --namespace podinfo --values podinfo/backend.yaml
kubectl apply -n podinfo -f selfsigned-podinfo-tls.yaml
```
