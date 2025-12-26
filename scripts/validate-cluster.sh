#!/bin/bash
# Script de validación automática del cluster Kubernetes
# Requiere: kubectl configurado con acceso al cluster

set -euo pipefail

echo "🔍 Validando despliegue del cluster..."

# Función auxiliar para validar recursos
check_resource() {
  local type=$1
  local name=$2
  local ns=${3:-}
  if [[ -n "$ns" ]]; then
    if kubectl get "$type" "$name" -n "$ns" &>/dev/null; then
      echo "✅ $type/$name en namespace $ns existe"
    else
      echo "❌ $type/$name en namespace $ns NO encontrado"
    fi
  else
    if kubectl get "$type" "$name" &>/dev/null; then
      echo "✅ $type/$name existe"
    else
      echo "❌ $type/$name NO encontrado"
    fi
  fi
}

# 1. Certificados y sincronización
echo -e "\n🔐 Certificados y sincronización"
check_resource namespace certs
check_resource pv pv-nfs-certs
check_resource pvc pvc-nfs-certs certs
check_resource deploy cert-sync certs

# 2. External Secrets
echo -e "\n🔁 External Secrets"
check_resource clustersecretstore k8s-cert-store
for site in site1 site2 site3; do
  check_resource namespace $site
  check_resource externalsecret es-${site}-cert $site
  check_resource secret tls-${site} $site
done

# 3. Sitios web
echo -e "\n📦 Sitios web"
for site in site1 site2 site3; do
  check_resource pv pv-nfs-${site}
  check_resource pvc pvc-nfs-${site} $site
  check_resource deploy web-${site} $site
  check_resource svc web-${site} $site
done

# 4. Ingress y Traefik
echo -e "\n🌐 Ingress y Traefik"
for site in site1 site2 site3; do
  check_resource ingress ${site}-ing $site
done
check_resource deploy traefik kube-system || echo "⚠️ Traefik no encontrado en kube-system, verificar namespace"

# 5. External Secrets Operator
echo -e "\n🧠 External Secrets Operator"
check_resource namespace external-secrets
check_resource deploy external-secrets external-secrets
check_resource deploy external-secrets-webhook external-secrets
check_resource svc external-secrets-webhook external-secrets

echo -e "\n✅ Validación completada"
