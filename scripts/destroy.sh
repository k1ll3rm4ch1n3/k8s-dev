#!/usr/bin/env bash
set -euo pipefail

log(){ echo -e "[+] $*"; }

log "Eliminando despliegues de Traefik y External Secrets..."
helm uninstall traefik -n traefik || true
helm uninstall external-secrets -n external-secrets || true

log "Eliminando namespaces de aplicaciones y operadores..."
kubectl delete ns certs site1 site2 site3 traefik external-secrets || true

log "Eliminando PersistentVolumes..."
kubectl delete pv pv-nfs-certs pv-nfs-site1 pv-nfs-site2 pv-nfs-site3 || true

log "Reseteando cluster con kubeadm..."
kubeadm reset -f || true

log "Limpiando configuración local de kubeconfig..."
rm -rf $HOME/.kube

log "Reiniciando containerd..."
systemctl restart containerd || true

log "Limpiando reglas de iptables..."
iptables -F && iptables -t nat -F && iptables -X

log "Eliminando configuración de CNI..."
rm -rf /etc/cni/net.d

log "Cluster y despliegues eliminados correctamente."