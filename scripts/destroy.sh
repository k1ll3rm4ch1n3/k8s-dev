#!/usr/bin/env bash
set -euo pipefail

# ====== Configuración ======
CLUSTER_NAME="${CLUSTER_NAME:-dev-cluster}"
# ===========================

log(){ echo -e "\033[1;31m[-] $*\033[0m"; }

require_root(){
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "Este script debe ejecutarse como root"; exit 1
  fi
}

destroy_cluster(){
  log "Reseteando cluster con kubeadm"
  kubeadm reset -f || true

  log "Eliminando configuración de kubectl"
  rm -rf $HOME/.kube

  log "Eliminando pods, deployments y servicios"
  kubectl delete all --all --all-namespaces || true

  log "Eliminando namespaces adicionales (traefik, externalsecrets)"
  kubectl delete ns traefik || true
  kubectl delete ns external-secrets || true

  log "Eliminando PV/PVC"
  kubectl delete pv --all || true
  kubectl delete pvc --all --all-namespaces || true

  log "Eliminando CRDs de ExternalSecrets"
  kubectl delete crd externalsecrets.external-secrets.io || true

  log "Limpiando iptables y CNI"
  iptables -F && iptables -t nat -F && iptables -X
  rm -rf /etc/cni/net.d

  log "Eliminando certificados y datos de etcd"
  rm -rf /etc/kubernetes/pki
  rm -rf /var/lib/etcd

  log "Reiniciando containerd"
  systemctl restart containerd || true
}

main(){
  require_root
  destroy_cluster
  log "Cluster ${CLUSTER_NAME} destruido correctamente."
  echo "Sistema limpio y listo para una nueva inicialización."
}

main
