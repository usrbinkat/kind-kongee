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
#### Deploy MetalLB for LoadBalancing
```sh
kubectl create namespace metallb --dry-run=client -oyaml | kubectl apply -f -
helm repo add metallb https://metallb.github.io/metallb ; helm repo update
helm install metallb metallb/metallb -n metallb -f metallb/values.yml
```
