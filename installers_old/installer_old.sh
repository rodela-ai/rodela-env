#!/bin/sh
echo "preflight..."
sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
echo " DONE"

echo "cleaning packages..."

PACKAGES="kubernetes-cni kubelet kubeadm helm cri-o cri-o-runc containernetworking containernetworking-plugins"
sudo apt-mark unhold $PACKAGES
sudo apt-get remove --purge $PACKAGES -y 

sudo rm -rf /etc/crio
sudo rm -rf /var/lib/kubelet/kubeadm-flags.env
sudo rm -rf /etc/containerd 
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /opt/containerd
sudo rm -rf /var/lib/etcd
sudo ./clean_storage.sh
sudo systemctl stop kubepods*

echo " DONE"
echo "adding needed repositories"
echo "crio"
echo 'deb http://download.opensuse.org/repositories/home:/alvistack/xUbuntu_24.04/ /' | sudo tee /etc/apt/sources.list.d/home:alvistack.list
curl -fsSL https://download.opensuse.org/repositories/home:alvistack/xUbuntu_24.04/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_alvistack.gpg > /dev/null

echo "nvidia"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "kubernetes"


echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "installing docker cli tools..." -n
sudo apt install docker-ce-cli -y
echo " DONE"

echo "deactivating swap..." -n
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo " DONE"

echo "installing kubernetes..." -n 
sudo apt update
sudo apt install -y runc kubelet kubeadm kubectl 
sudo apt-mark hold kubelet kubeadm kubectl 
echo " DONE"

echo "installing cri-o" -n
sudo apt update
sudo apt-get -o Dpkg::Options::="--force-overwrite" install cri-o -y
sudo apt-get install crun cri-o-runc fuse-overlayfs -y

echo " DONE"

echo "installing helm..." -n
sudo apt-get install helm -y
echo " DONE" 


echo "initiating crio..." -n
sudo systemctl enable crio
sudo systemctl start crio
sudo chmod 666 /var/run/crio/crio.sock

echo " DONE"

echo "configuring kubeadm..." -n
echo "KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-service-endpoint=unix:///var/run/crio/crio.sock --cri-socket=unix:///var/run/crio.sock " | sudo tee /var/lib/kubelet/kubeadm-flags.env
echo " DONE" 

echo "restartiing kubelet..." -n
systemctl restart crio
sudo chmod 666 /var/run/crio/crio.sock
sudo systemctl enable kubelet
sudo systemctl restart kubelet
echo " DONE"

echo "initiating cluster..." -n
#sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --advertise-address=127.0.0.1 --bind-address=0.0.0.0 --cri-socket=unix:///var/run/crio/crio.sock
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=0.0.0.0 --apiserver-bind-port=8080 --cri-socket=unix:///var/run/crio/crio.sock

echo " DONE"

echo "installing calico..." -n
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
echo "done"

echo "enabling user..." -n 
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "tests:"

sudo kubectl get nodes

sudo kubectl run nvidia-smi --restart=Never --image=nvidia/cuda:11.0-base --limits=nvidia.com/gpu=1 --command -- nvidia-smi
sudo kubectl logs nvidia-smi
