#!/bin/sh


VERSION=1.30.8-1.1


echo "preflight..."
yes | nerdctl system prune

yes | kubeadm reset
sudo apt-get purge containerd.io kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get autoremove
sudo rm -rf ~/.kube

sudo modprobe overlay
sudo modprobe br_netfilter

sudo sysctl -w net.ipv4.ip_forward=1
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF


sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo sysctl --system

echo " DONE"

echo "cleaning packages..."

PACKAGES="kubernetes-cni kubelet kubeadm helm cri-o cri-o-runc containernetworking containernetworking-plugins"
sudo apt-mark unhold $PACKAGES
sudo apt-get remove --purge $PACKAGES -y 
sudo rm -rf /etc/kubernetes
sudo rm -rf /etc/crio
sudo rm -rf /var/lib/kubelet/kubeadm-flags.env
sudo rm -rf /etc/containerd 
sudo rm -rf /var/lib/containerd
sudo mkdir -p /var/lib/containerd
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /opt/containerd
sudo rm -rf /var/lib/etcd
#sudo ./clean_storage.sh
sudo systemctl stop kubepods*

echo " DONE"
echo "adding needed repositories"

echo "nvidia"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo "docker cli" 
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
 
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

echo "kubernetes"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


echo "installing nvidia-container-toolkit..." -n
sudo apt-get install -y nvidia-container-toolkit
echo " DONE"

echo "install nerdctl..."
wget https://github.com/containerd/nerdctl/releases/download/v2.0.2/nerdctl-2.0.2-linux-amd64.tar.gz
tar -zxf nerdctl-2.0.2-linux-amd64.tar.gz nerdctl
sudo mv nerdctl /usr/bin/nerdctl
rm nerdctl-2.0.2-linux-amd64.tar.gz

echo " DONE"
echo "installing docker cli toolsi and containerd..." -n
sudo apt-get install containerd.io
sudo apt install docker-ce-cli -y
echo " DONE"

echo "deactivating swap..." -n
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo " DONE"

echo "creating containerd configuration..." -n
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
cat confs/config.toml |  sudo tee /etc/containerd/config.toml

echo " DONE" 
echo "add this to /etc/containerd/config.toml"
echo "[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
"


echo "installing containerd" -n
sudo systemctl enable --now containerd  
echo " DONE"


echo "installing kubernetes..." -n 
sudo apt-get update
sudo apt-get install kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION -y --allow-downgrades
sudo apt-mark hold kubelet kubeadm kubectl -y
echo " DONE"


#echo "installing cri-o" -n
#sudo apt update
#sudo apt-get -o Dpkg::Options::="--force-overwrite" install cri-o -y
#sudo apt-get install crun cri-o-runc fuse-overlayfs -y
#sudo apt install apparmor apparmor-utils -y

echo "installing helm..." -n
sudo apt-get install helm -y
echo " DONE" 


echo " DONE"

echo "starting kubelet " -n
sudo systemctl enable --now kubelet
echo " DONE" 

#echo "configuring kubeadm..." -n
#echo "KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///var/run/crio/crio.sock --image-service-endpoint=unix:///var/run/crio/crio.sock --cri-socket=unix:///var/run/crio.sock " | sudo tee /var/lib/kubelet/kubeadm-flags.env
#echo " DONE" 

#echo "add binding" -n
#cat confs/kube-apiserver.yaml |  sudo tee /etc/kubernetes/manifests/kube-apiserver.yaml
#echo " DONE"
#echo "restartiing kubelet..." -n
#sudo systemctl enable kubelet
#sudo systemctl restart kubelet
#echo " DONE"


echo "initiating cluster..." -n
#sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=0.0.0.0 --apiserver-bind-port=8080 --cri-socket=unix:///var/run/crio/crio.sock
sudo kubeadm config images pull
sudo kubeadm init --v=5 --pod-network-cidr=10.244.0.0/16
# --cri-socket=/var/run/containerd/containerd.sock --apiserver-advertise-address=192.168.1.223 --v=5
#--pod-network-cidr=10.244.0.0/16 
#--apiserver-advertise-address=0.0.0.0 
#--cri-socket=unix:///var/run/crio/crio.sock
#sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock


echo " DONE"
sleep 30
echo "installing network" -n
sudo kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
echo "done"

echo "enabling user..." -n 
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "tests:"

sudo kubectl get nodes

sudo kubectl run nvidia-smi --restart=Never --image=nvidia/cuda:11.0-base --limits=nvidia.com/gpu=1 --command -- nvidia-smi
sudo kubectl logs nvidia-smi
