#!/bin/bash
# rodela.io
# author: francisco josé navarrete pan paco.j.navarrete@gmail.com
# Functions

local_set_gpu_use () {
  echo -e "deploying $FUNCNAME... "
  sudo nvidia-ctk runtime configure --runtime=docker --set-as-default
  sudo systemctl restart docker
  sudo sed -i '/accept-nvidia-visible-devices-as-volume-mounts/c\accept-nvidia-visible-devices-as-volume-mounts = true' /etc/nvidia-container-runtime/config.toml
  # https://github.com/NVIDIA/nvidia-docker/issues/614#issuecomment-423991632
  docker exec -ti substratus-control-plane ln -s /sbin/ldconfig /sbin/ldconfig.real
  helm repo add nvidia https://helm.ngc.nvidia.com/nvidia || true
  helm repo update
  helm install --wait --generate-name \
     -n gpu-operator --create-namespace \
      nvidia/gpu-operator --set driver.enabled=false

  echo "DONE (check errors)"
}

deploy_kind_cluster () {
  echo -e "deploying $FUNCNAME... "
  kind create cluster -n $2 --config data/kind/kind.yaml
  # TODO: add ingress and on values.yaml also
  kubectl create namespace $2
  install_ingress $1 $2
  deploy_metricserver $1 $2
  echo "DONE (check errors)"
  sleep 5
}

test_gpu_use () {

kubectl apply -n $2 -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vectoradd
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-vectoradd
    image: "nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1-ubuntu20.04"
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

}

install_ingress () {
  echo -e "deploying $FUNCNAME... "
  kubectl apply -f data/ingress/deploy-ingress-nginx.yaml
  # kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
  sleep 5
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=90s
  sleep 5
  echo "DONE (check errors)"
}

deploy_metricserver() {
  echo -e "deploying $FUNCNAME... "
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
  helm repo update
  helm upgrade --install metrics-server metrics-server/metrics-server -f data/metrics-server/values.yaml
  echo "DONE (check errors)"
}

install_ollama () {
  echo -e "deploying $FUNCNAME... "
  helm repo add cowboysysop https://cowboysysop.github.io/charts/
  helm upgrade --install ollama cowboysysop/ollama --namespace $2 -f data/ollama/values.yaml
  echo "DONE (check errors)"
}

install_open-webui () {
# TODO: add security
    echo -e "deploying $FUNCNAME... "
    helm repo add open-webui https://helm.openwebui.com/
    helm repo update
    helm upgrade -i openwebui open-webui/open-webui --namespace $2 -f data/open-webui/values.yaml
    echo "DONE (check errors)"
}

install_kafka () {
  echo -e "deploying $FUNCNAME... "
  helm repo add cloudnativeapp https://cloudnativeapp.github.io/charts/curated/
  helm repo add licenseware https://licenseware.github.io/charts/
  helm repo update

  helm upgrade -i kafka oci://registry-1.docker.io/bitnamicharts/kafka -f data/kafka/values.yaml --namespace $2
  helm upgrade -i schema-registry  oci://registry-1.docker.io/bitnamicharts/schema-registry -f data/schema-registry/values.yaml --namespace $2
  # TODO: repair schema-registry
  #helm upgrade -i schema-registry-ui cloudnativeapp/schema-registry-ui -f data/schema-registry-ui/values.yaml --namespace $2
  helm upgrade -i ksqldb licenseware/ksqldb -f data/ksqldb/values.yaml --namespace $2
  echo "DONE (check errors)"
}

install_vector () {
  # TODO: add security
  echo -e "deploying $FUNCNAME... "
  helm repo add qdrant https://qdrant.github.io/qdrant-helm
  helm repo update
  helm upgrade -i qdrant qdrant/qdrant -n $2 -f data/qdrant/values.yaml
  echo "DONE (check errors)"
}

install_testingLinux () {

  echo -e "deploying $FUNCNAME... "
  # ubuntu for testing
  helm repo add open https://simonmisencik.github.io/helm-charts
  helm repo update
  helm upgrade -i testlin open/ubuntu -n $2

  echo "DONE (check errors)"
}

if [ "$1" == "destroy" ]
then
  kubectl delete namespace $2
  kind delete clusters $2
  exit
fi
if [ "$1" == "local_kind" ]
then
  local_set_gpu_use
  deploy_kind_cluster $1 $2
fi

if [ "$1" == "gpu" ]
then
  local_set_gpu_use $1 $2
fi

if [ "$1" == "remote" ]
then
  # TODO: develop this part
  echo "If you are running this script on cloud, please pay attention to enable GPU support"
  echo "https://www.run.ai/guides/multi-gpu/kubernetes-gpu ."
  echo "This deployment does not include persistent storage."
  echo "exiting for now"
  exit
fi

install_ollama $1 $2
install_open-webui $1 $2
install_kafka $1 $2
install_vector $1 $2
install_testingLinux $1 $2

echo "Also renember to edit the configuration files under the data directory."


