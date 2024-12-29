echo "enabling user..." -n 
  sudo mkdir -p /home/$1/.kube
  sudo cp -i /etc/kubernetes/admin.conf /home/$1/.kube/config
  sudo chown $1:$1 /home/$1/.kube/config
echo "DONE"

