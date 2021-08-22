# How-To
#### 1) Create Namespaces
```sh
kubectl create namespace kong         --dry-run=client -oyaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -oyaml | kubectl apply -f -
```
#### 2) Deploy Cert Manager & Self Signed CA Certificate Issuer
```sh
helm repo add jetstack https://charts.jetstack.io ; helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --set installCRDs=true \
  --values ./cert-manager/helm-jetstack-certmanager-values.yml
kubectl get all -n cert-manager
kubectl apply -n kong -f ./cert-manager/bootstrap-selfsigned-issuer.yml
kubectl apply -n kong -f ./cert-manager/kong-tls-selfsigned-cert.yml
```
#### 3) Deploy Postgres as Kong Configuration Store
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami ; helm repo update
helm install postgres bitnami/postgresql --namespace kong --values ./postgres/values.yml
```
#### 4) Deploy MetalLB for LoadBalancing
```sh
kubectl create namespace metallb --dry-run=client -oyaml | kubectl apply -f -
helm repo add metallb https://metallb.github.io/metallb ; helm repo update
helm install metallb metallb/metallb -n metallb -f metallb/values.yml
```
#### 5) Deploy Kong Gateway Enterprise Edition in Hybrid Mode
```sh
mkdir -p /tmp/kong && docker run -it --rm --pull always --user root -v /tmp/kong:/tmp/kong:z docker.io/kong/kong -- kong hybrid gen_cert /tmp/kong/tls.crt /tmp/kong/tls.key
kubectl create secret tls kong-cluster-cert --namespace kong --cert=/tmp/kong/tls.crt --key=/tmp/kong/tls.key --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic kong-enterprise-license            -n kong --from-file=license=${HOME}/.kong-license-data/license.json --dry-run=client -oyaml | kubectl apply -n kong -f -
kubectl create secret generic kong-enterprise-superuser-password -n kong --from-literal=password='kong_admin'                        --dry-run=client -oyaml | kubectl apply -n kong -f -
kubectl create secret generic kong-postgres-password             -n kong --from-literal=password=kong                                --dry-run=client -oyaml | kubectl apply -n kong -f -

kubectl create secret generic kong-session-config -n kong \
    --from-file=admin_gui_session_conf=./kongee/contrib/admin_gui_session_conf \
    --from-file=portal_session_conf=./kongee/contrib/portal_session_conf \
    --dry-run=client -oyaml \
  | kubectl apply -f -

helm repo add kong https://charts.konghq.com ; helm repo update

helm install dataplane kong/kong --namespace kong --values ./kongee/dataplane.yml --set ingressController.installCRDs=false
helm install controlplane kong/kong --namespace kong --values ./kongee/controlplane.yml --set ingressController.installCRDs=false
```

### References:
  - https://kic-v2-beta--kongdocs.netlify.app/kubernetes-ingress-controller/2.0.x/guides/getting-started/    
  - https://docs.cert-manager.io/en/release-0.8/tasks/issuers/setup-ca.html    
  - https://discuss.konghq.com/t/ssl-connection-to-kong-in-docker/5256    
  - https://docs.cert-manager.io/en/release-0.11/tasks/issuers/setup-ca.html    
  - https://faun.pub/wildcard-k8s-4998173b16c8
    
### Google Cloud ACME DNS Validation
```sh
mkdir /tmp/gc
curl --output /tmp/gc https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-353.0.0-linux-x86_64.tar.gz
tar xvf /tmp/gc/google-cloud-sdk-*-linux-x86_64.tar.gz -C /tmp/gc
cd /tmp/gc && ./google-cloud-sdk/install.sh
gcloud init
gcloud iam service-accounts create dns01-solver --display-name "dns01-solver"
gcloud projects list
export PROJECT_ID=kingpin-259919
gcloud projects add-iam-policy-binding kingpin-259919 --member serviceAccount:dns01-solver@kingpin-259919.iam.gserviceaccount.com --role roles/dns.admin
gcloud iam service-accounts keys create key.json --iam-account dns01-solver@kingpin-259919.iam.gserviceaccount.com
kubectl create secret generic clouddns-dns01-solver-svc-acct --from-file=key.json
kubectl create secret generic clouddns-dns01-solver-svc-acct --from-file=key.json -n kong
kubectl create secret generic clouddns-dns01-solver-svc-acct --from-file=key.json -n cert-manager
kubectl get secrets -n kong
kubectl get issuer -n kong -oyaml bcio-kingpin-issuer
kubectl get events -n kong
kubectl get issuer -n kong -oyaml bcio-kingpin-issuer
kubectl describe -n kong certificates && kubectl get -n kong certificates -owide
kubectl describe issuer -n kong bcio-kingpin-issuer
kubectl describe -n kong -owide CertificateRequests
kubectl get secret -n kong -oyaml kong-tls
```
