#!/usr/bin/env bash
set -euo pipefail

# ====== Configuración ======
K8S_VERSION="${K8S_VERSION:-1.29.0}"         # versión semántica completa
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"       # red de pods para Calico
DISABLE_FIREWALL="${DISABLE_FIREWALL:-true}" # para laboratorio
SELINUX_MODE="disabled"                      # SELinux desactivado
CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"  # nombre del cluster
DOMAIN="${DOMAIN:-dev.local}"                # dominio para ingress
NFS_SERVER="${NFS_SERVER:-192.168.1.100}"    # servidor NFS
# ===========================

# Logging con color verde
log(){ echo -e "\033[1;32m[+] $*\033[0m"; }

require_root(){
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"; exit 1
  fi
}

get_hostname(){
  HOSTNAME_SET="$(hostname)"
  log "Usando hostname actual: ${HOSTNAME_SET}"
}

fix_hosts(){
  HOSTNAME_SET="$(hostname)"
  if ! grep -q "127.0.0.1 ${HOSTNAME_SET}" /etc/hosts; then
    log "Agregando hostname ${HOSTNAME_SET} a /etc/hosts"
    echo "127.0.0.1 ${HOSTNAME_SET}" >> /etc/hosts
  else
    log "Hostname ${HOSTNAME_SET} ya está en /etc/hosts"
  fi
}

prepare_os(){
  log "Actualizando paquetes base"
  dnf -y update

  log "Instalando utilitarios"
  dnf -y install curl wget tar git bash-completion iproute iptables yum-utils nfs-utils

  if [[ "${DISABLE_FIREWALL}" == "true" ]]; then
    log "Deshabilitando firewalld (laboratorio)"
    systemctl disable --now firewalld || true
  fi

  log "Desactivando SELinux"
  setenforce 0 || true
  sed -ri "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config

  log "Deshabilitando swap (requerido por kubelet)"
  swapoff -a
  sed -ri 's/^\s*([^#].*\s)swap(\s.*)$/# \1swap\2/' /etc/fstab || true

  log "Habilitando módulos del kernel"
  cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
  modprobe overlay
  modprobe br_netfilter

  log "Configurando sysctl para tráfico puenteado"
  cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system

  log "Configurando zona horaria y NTP"
  timedatectl set-timezone America/Santiago
  timedatectl set-ntp true
}

install_containerd(){
  log "Agregando repositorio oficial de Docker"
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

  log "Instalando containerd.io y runc"
  dnf -y install containerd.io runc

  log "Generando configuración y habilitando cgroups systemd"
  mkdir -p /etc/containerd
  containerd config default | tee /etc/containerd/config.toml >/dev/null
  sed -ri 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

  log "Habilitando y arrancando containerd"
  systemctl daemon-reexec
  systemctl enable --now containerd
}

install_kubernetes(){
  log "Agregando repositorio de Kubernetes (upstream)"
  cat >/etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION%.*}/rpm/repodata/repomd.xml.key
EOF

  log "Instalando kubelet, kubeadm y kubectl"
  dnf -y install kubelet kubeadm kubectl

  log "Habilitando kubelet"
  systemctl enable kubelet
}

init_cluster(){
  log "Inicializando el cluster con kubeadm"
  IFACE="$(ip route show default | awk '/default/ {print $5; exit}')"
  IP="$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)"

  kubeadm init \
    --pod-network-cidr="${POD_CIDR}" \
    --kubernetes-version "${K8S_VERSION}" \
    --apiserver-advertise-address "${IP}"

  log "Configurando kubeconfig para el usuario actual (root)"
  mkdir -p $HOME/.kube
  cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  log "Instalando CNI Calico"
  curl -sSLo /tmp/calico.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml
  sed -ri "s#192\.168\.0\.0/16#${POD_CIDR}#" /tmp/calico.yaml || true
  kubectl apply -f /tmp/calico.yaml

  log "Permitiendo agendamiento en el control-plane (single node)"
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

  log "Esperando que el nodo esté Ready"
  kubectl wait node --all --for=condition=Ready --timeout=180s || true
}

install_helm(){
  log "Instalando Helm"
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  if ! echo $PATH | grep -q "/usr/local/bin"; then
    log "Agregando /usr/local/bin al PATH"
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
    source ~/.bashrc || true
  fi

  helm version
}

install_traefik(){
  log "Instalando Traefik con Helm"
  helm repo add traefik https://traefik.github.io/charts
  helm repo update
  helm install traefik traefik/traefik -f sites/08-sites-ingress.yaml
}

install_external_secrets(){
  log "Instalando ExternalSecrets"
  helm repo add external-secrets https://charts.external-secrets.io
  helm repo update
  helm install external-secrets external-secrets/external-secrets -f sites/06-external-secrets-sites.yaml
}

configure_nfs(){
  log "Configurando NFS con servidor ${NFS_SERVER}"
  showmount -e "${NFS_SERVER}" || true
  kubectl apply -f manifests/pv-pvc.yaml
}

post_install_tuning(){
  log "Habilitando autocompletado de kubectl"
  echo 'source <(kubectl completion bash)' >> /etc/bashrc
  {
    echo "alias k=kubectl"
    echo "complete -F __start_kubectl k"
  } >> /etc/bashrc
}

validations(){
  log "Validando estado del cluster"
  kubectl get nodes
  kubectl get pods -A
  kubectl get pv,pvc
  kubectl get secrets
}

main(){
  require_root
  get_hostname
  fix_hosts
  prepare_os
  install_containerd
  install_kubernetes
  init_cluster
  install_helm
  install_traefik
  install_external_secrets
  configure_nfs
  post_install_tuning
  validations
  log "Cluster ${CLUSTER_NAME} listo con Traefik, ExternalSecrets y NFS configurados."
  echo "Accede a tus apps vía dominio: ${DOMAIN}"
}

if [[ "${1:-}" == "reset" ]]; then
  kubeadm reset -f || true
  rm -rf $HOME/.kube
  systemctl restart containerd || true
  iptables -F && iptables -t nat -F && iptables -X
  rm -rf /etc/cni/net.d /etc/kubernetes/pki /var/lib/etcd
else
  main
fi
