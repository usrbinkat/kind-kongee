# Kong in Kind
Build a kong enterprise edition hybrid gateway installation on [Kind](https://kind.sigs.k8s.io).    
This guide is written for MacOS and is easily adaptable to Linux hosts.    

## Architecture
  - Name Resolution via `/etc/hosts`    
  - Kong config store via Postgres Database    
  - Certificates via Cert Manager Self Signed CA Issuer   
  - Keycloak OIDC idP
    
#### 0) Install Prerequisites:
  - Install Homebrew (MacOS only)
```sh
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | bash
```
  - Install Packages: `git kind httpie curl docker`    
```sh
brew install kubectl git kind httpie curl-openssl helm
brew install --cask lens docker
docker volume create worker1-containerd
docker volume create control1-containerd
```
  - Install Helm repositories:  
```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo add kong https://charts.konghq.com
helm repo update
```
  - Download Github Repositories  
```sh
git clone https://github.com/usrbinkat/kind-kongee.git ~/kind-kongee && cd ~/kind-kongee
```
  - create following entries in your /etc/hosts file    
```sh
export DATAPLANE_ADDRESS=127.0.0.1
cat <<EOF | sudo tee -a /etc/hosts
${DATAPLANE_ADDRESS}  kongeelabs.home.arpa
${DATAPLANE_ADDRESS}  paste.kongeelabs.home.arpa
${DATAPLANE_ADDRESS}  portal.kongeelabs.home.arpa
${DATAPLANE_ADDRESS}  manager.kongeelabs.home.arpa
${DATAPLANE_ADDRESS}  keycloak.kongeelabs.home.arpa
EOF
```
  - NOTE: be sure to open Docker Desktop before continuing if you havent done so on this mac before

#### 1) Start Kind Cluster:
  - Start Kubernetes-in-Docker cluster
```sh
docker volume create worker1-containerd
docker volume create control1-containerd
kind create cluster --config platform/kind/config.yml
```
  - Install Kube Prometheus for Kontena Lens metrics
```sh
helm upgrade --install kube-prometheus bitnami/kube-prometheus --namespace prometheus --create-namespace
```
  - Create Kong Namespaces
```sh
kubectl create namespace kong --dry-run=client -oyaml | kubectl apply -f -
```
    
#### 2) Deploy Cert Manager & Self Signed CA Certificate Issuer
```sh
kubectl create namespace cert-manager --dry-run=client -oyaml | kubectl apply -f -
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --set installCRDs=true \
  --values ./cert-manager/helm-jetstack-certmanager-values.yml ; sleep 4
```
```sh
kubectl apply -f ./cert-manager/bootstrap-selfsigned-issuer.yml
kubectl get all -n cert-manager
```

#### 3) Deploy Postgres as Kong Configuration Store
  - Create Postgres Password Secret
```sh
kubectl create secret generic kong-postgres-config -n kong --dry-run=client -oyaml \
    --from-literal=user=kong \
    --from-literal=database=kong \
    --from-literal=password=kong \
    --from-literal=pg_host="postgres-postgresql.kong.svc.cluster.local" \
  | kubectl apply -n kong -f -
```
    
#### 4) Deploy Kong Gateway Enterprise Edition in Hybrid Mode
  - Create hybrid dual plane mutual trust certificate
```sh
mkdir -p /tmp/kong
docker run -it --rm --pull always --user root --volume /tmp/kong:/tmp/kong:z \
    docker.io/kong/kong -- \
  kong hybrid gen_cert /tmp/kong/tls.crt /tmp/kong/tls.key
```
  - Create hybrid certificates secret
```sh
sudo chown $USER -R /tmp/{kong,kong/*}
kubectl create secret tls kong-cluster-cert --namespace kong \
    --cert=/tmp/kong/tls.crt --key=/tmp/kong/tls.key --dry-run=client -oyaml \
  | kubectl apply -f -
```
  - Issue self signed kong admin api, manager, portal api, and portal certificates
```sh
kubectl apply -n kong -f ./kongee/kong-tls-selfsigned-cert.yml
```
  - create kong gateway enterprise license secret
```sh
kubectl create secret generic kong-enterprise-license -n kong --from-file=license=${HOME}/.kong-license-data/license.json --dry-run=client -oyaml | kubectl apply -n kong -f -
```
  - Create `kong_admin` super user password secret
```sh
kubectl create secret generic kong-enterprise-superuser-password -n kong --from-literal=password='kong_admin' --dry-run=client -oyaml | kubectl apply -n kong -f -
```
  - Create Manager & Portal WebUI Session Config Secret
```sh
kubectl create secret generic kong-session-config -n kong \
    --from-file=admin_gui_session_conf=./kongee/contrib/admin_gui_session_conf \
    --from-file=portal_session_conf=./kongee/contrib/portal_session_conf \
    --dry-run=client -oyaml \
  | kubectl apply -f -
```
  - Install Kong Data Plane & Control Plane & Deploy Postgres
```sh
helm upgrade --install postgres bitnami/postgresql --namespace kong --values ./postgres/values.yml
helm upgrade --install controlplane kong/kong      --namespace kong --values ./kongee/controlplane.yml
helm upgrade --install dataplane    kong/kong      --namespace kong --values ./kongee/dataplane.yml
```
    
#### 5) Install Keycloak
  - Deploy Operator, Certs, Realm, & Client
```sh
until kubectl kustomize keycloak | kubectl apply -f - ;do sleep 3 ; done
```
  - Create ingress for Keycloak web console
```sh 
kubectl annotate service -n keycloak keycloak konghq.com/protocol="https"
kubectl apply -n keycloak -f ./keycloak/ingress.yml 
```

#### Final) Test Services
  - Open Kong Manager in browser: https://manager.kongeelabs.home.arpa    
  - NOTE: login to web gui with user:pass `kong_admin`:`kong_admin`
```
http --verify=no https://manager.kongeelabs.home.arpa/api kong-admin-token:kong_admin
```
  - Login to keycloak with username `admin` @ https://keycloak.kongeelabs.home.arpa
  - Lookup Keycloak admin password
```sh
kubectl get secrets -n keycloak credential-default -ojsonpath="{.data.ADMIN_PASSWORD}" | base64 -d ;echo;echo
```
  - Check for OIDC Configuration Endpoint
```
curl -Lks https://keycloak.kongeelabs.home.arpa/auth/realms/default/.well-known/openid-configuration | jq .
```
      
-------------------------
-------------------------
### References:
  - https://kic-v2-beta--kongdocs.netlify.app/kubernetes-ingress-controller/2.0.x/guides/getting-started/    
  - https://docs.cert-manager.io/en/release-0.8/tasks/issuers/setup-ca.html    
  - https://discuss.konghq.com/t/ssl-connection-to-kong-in-docker/5256    
  - https://docs.cert-manager.io/en/release-0.11/tasks/issuers/setup-ca.html    
  - https://faun.pub/wildcard-k8s-4998173b16c8
