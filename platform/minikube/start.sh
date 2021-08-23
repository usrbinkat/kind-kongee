minikube start \
    --addons="["auto-pause","default-storageclass","olm"]"
    --apiserver-name='minikubeCA' \
    --apiserver-port=8443 \
    --auto-update-drivers=true \
    --cache-images=true \
    --cni='calico' \
    --container-runtime='docker' \
    --cpus='6' \
    --disk-size='48gb' \
    --dns-domain='cluster.local' \
    --driver='docker' \
    --embed-certs=true \
    --install-addons=true \
    --kubernetes-version='stable' \
    --listen-address='192.168.1.111' \
    --memory='12gb' \
    --nodes=1 \
    --ports=["80","443"] \
    ; echo
