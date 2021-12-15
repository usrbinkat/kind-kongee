  - Fedora
```sh
sudo dnf -y install dnf-plugins-core -y
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo -y
sudo dnf install jq httpie docker-ce docker-ce-cli containerd.io -y
sudo systemctl enable --now docker
```

  - kubectl
```sh
export K8S_RELEASE_STABLE="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
sudo curl --output /usr/local/bin/kubectl -L https://storage.googleapis.com/kubernetes-release/release/${K8S_RELEASE_STABLE}/bin/$(uname -s | awk '{print tolower($0)}')/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
kubectl version --short --client
```

  - kind
```sh
sudo curl --output /usr/local/bin/kind -L https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
sudo chmod +x /usr/local/bin/kind
kind version
```

  - helm
```sh
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```
