# Kong in Kind
Build a kong enterprise edition hybrid gateway installation on [Kind](https://kind.sigs.k8s.io).    
This guide is written for MacOS and is easily adaptable to Linux hosts.    

## Architecture
  - Name Resolution via `/etc/hosts`    
  - Kong config store via Postgres Database    
  - Certificates via Cert Manager Self Signed CA Issuer   
  - MetalLB deployment for use in other local k8s solutions (optional)
    
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
git clone https://github.com/keycloak/keycloak-operator.git /tmp/keycloak
```
  - create following entries in your /etc/hosts file    
```sh
cat <<EOF | sudo tee -a /etc/hosts
127.0.0.1  kongeelabs.arpa
127.0.0.1  portal.kongeelabs.arpa
127.0.0.1  manager.kongeelabs.arpa
127.0.0.1  keycloak.kongeelabs.arpa
EOF
```
    
  - NOTE: be sure to open Docker Desktop before continuing if you havent done so on this mac before

#### 1) Start Kind Cluster:
  - Start Kubernetes-in-Docker cluster
```sh
kind create cluster --config platform/kind/config.yml
```
  - Create Kong Namespaces
```sh
kubectl create namespace kong --dry-run=client -oyaml | kubectl apply -f -
```
    
#### 2) Deploy Cert Manager & Self Signed CA Certificate Issuer
```sh
kubectl create namespace cert-manager --dry-run=client -oyaml | kubectl apply -f -
helm install cert-manager jetstack/cert-manager \
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
kubectl create secret generic kong-postgres-password -n kong --from-literal=password=kong --dry-run=client -oyaml | kubectl apply -n kong -f -
```
  - Deploy Postgres
```sh
helm install postgres bitnami/postgresql --namespace kong --values ./postgres/values.yml
```
    
#### 4) Deploy Kong Gateway Enterprise Edition in Hybrid Mode
  - Create hybrid dual plane mutual trust certificate
```sh
mkdir -p /tmp/kong
docker run -it --rm --pull always --user root --volume /tmp/kong:/tmp/kong:z \
    docker.io/kong/kong -- \
  kong hybrid gen_cert /tmp/kong/tls.crt /tmp/kong/tls.key
```
  - Create hubrid certificates secret
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
  - Install Kong Data Plane & Control Plane
```sh
helm install dataplane kong/kong --namespace kong --values ./kongee/dataplane.yml --set ingressController.installCRDs=false
helm install controlplane kong/kong --namespace kong --values ./kongee/controlplane.yml --set ingressController.installCRDs=false
```
    
#### 5) Install Keycloak
  - Create Namespace
```sh
kubectl create namespace keycloak --dry-run=client -oyaml | kubectl apply -f -
```
  - Install Keycloak Operator
```sh
kubectl apply -n keycloak -f /tmp/keycloak/deploy/crds
kubectl apply -n keycloak -f /tmp/keycloak/deploy/role.yaml
kubectl apply -n keycloak -f /tmp/keycloak/deploy/role_binding.yaml
kubectl apply -n keycloak -f /tmp/keycloak/deploy/service_account.yaml
kubectl apply -n keycloak -f /tmp/keycloak/deploy/operator.yaml
```
  - Issue Keycloak Console Certificate
```sh
kubectl apply -n keycloak -f ./keycloak/selfsigned-keycloak-tls.yml
```
  - Create keycloak, realm, and client
```sh
kubectl apply -n keycloak -f ./keycloak/keycloak.yml 
kubectl apply -n keycloak -f ./keycloak/realm.yml 
kubectl apply -n keycloak -f ./keycloak/client.yml
```
  - Create ingress for Keycloak web console
```sh 
kubectl annotate service -n keycloak keycloak konghq.com/protocol="https"
kubectl apply -n keycloak -f ./keycloak/ingress.yml 
```

#### Final) Test Services
  - NOTE: login to web gui with user:pass `kong_admin`:`kong_admin`
  - Open in browser: https://manager.kongeelabs.arpa    
```
http --verify=no https://manager.kongeelabs.arpa/api kong-admin-token:$TOKEN
```
  - TOKEN: find on web gui > top right > user drop menu > profile > bottom of page > Reset Token button
  - Login to keycloak with username `admin` @ https://keycloak.kongeelabs.arpa
  - Lookup Keycloak admin password
```sh
kubectl get secrets -n keycloak credential-default -ojsonpath="{.data.ADMIN_PASSWORD}" | base64 -d ;echo;echo
```
      
-------------------------
-------------------------
### References:
  - https://kic-v2-beta--kongdocs.netlify.app/kubernetes-ingress-controller/2.0.x/guides/getting-started/    
  - https://docs.cert-manager.io/en/release-0.8/tasks/issuers/setup-ca.html    
  - https://discuss.konghq.com/t/ssl-connection-to-kong-in-docker/5256    
  - https://docs.cert-manager.io/en/release-0.11/tasks/issuers/setup-ca.html    
  - https://faun.pub/wildcard-k8s-4998173b16c8
