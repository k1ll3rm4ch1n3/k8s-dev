🚀 Kubernetes Single‑Node en Oracle Linux 9
🎯 Objetivo
Desplegar un cluster single‑node Kubernetes en Oracle Linux 9 (minimal), con:
- Helm instalado desde el inicio.
- Traefik como Ingress Controller.
- External Secrets Operator para consumir certificados centralizados.
- Pod sincronizador que exporta certificados SSL desde un storage NFS a Secrets.
- Tres sitios web de prueba (site1, site2, site3) cada uno en su propio namespace, sirviendo contenido desde NFS y expuestos con TLS en dominios distintos.

📂 Estructura del repositorio
    k8s-single-node/
    ├── scripts/
    │   ├── cluster-init.sh          # Script maestro para inicializar cluster
    │   └── destroy.sh               # Limpieza total del cluster y recursos
    ├── ingress/
    │   └── traefik-values.yaml      # Configuración de Traefik
    ├── certs/
    │   ├── 01-namespace-pv-pvc.yaml # Namespace y PV/PVC NFS
    │   ├── 02-rbac.yaml             # RBAC para sincronizador
    │   ├── 03-cert-sync-deploy.yaml # Deployment sincronizador con recursos asignados
    │   └── 04-clustersecretstore.yaml
    ├── sites/
    │   ├── 05-namespaces-pv-pvc.yaml # Namespaces y PV/PVC para cada sitio
    │   ├── 06-external-secrets.yaml  # ExternalSecrets para consumir TLS centralizados
    │   ├── 07-deploy-svc.yaml        # Deployments y Services con recursos asignados
    │   └── 08-ingress.yaml           # Ingress único para los tres sitios
    └── README.md                     # Documentación completa

🔄 Flujo de creación
1. Inicialización del servidor y cluster
    - Ejecutar scripts/cluster-init.sh como root.
    - Configura zona horaria (America/Santiago), activa NTP, desactiva SELinux, instala containerd, kubeadm/kubectl/kubelet, inicializa cluster con Calico y deja Helm instalado.
    - Resultado: cluster single‑node listo para recibir manifiestos.

2. Instalación de Ingress Controller (Traefik)
    helm repo add traefik https://traefik.github.io/charts
    helm repo update
    helm install traefik traefik/traefik -n traefik --create-namespace -f ingress/traefik-values.yaml

3. Instalación de External Secrets Operator
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

4. Aplicar manifiestos de certificados
    kubectl apply -f certs/

5. Aplicar manifiestos de sitios
    kubectl apply -f sites/

6. Validación final
    kubectl get nodes
    kubectl get pods -A

✅ Validaciones
    Cluster operativo:
        kubectl get nodes
        kubectl get pods -A
    
    Traefik activo:
        kubectl -n traefik get pods

    Secrets sincronizados:
        kubectl -n certs get secrets

    External Secrets creados:
        kubectl -n site1 get secret tls-site1
        kubectl -n site1 get secret tls-site1
        kubectl -n site1 get secret tls-site1
    # Navegar a https://site1.celmediafidelizacion.cl
                https://site2.celmediafidelizacion.cl
                https://site3.celmediafidelizacion.cl

🧹 Limpieza
Para destruir todo el despliegue, usar:
    sudo ./scripts/destroy.sh

    Este script elimina:
    - Releases de Helm (Traefik, External Secrets).
    - Namespaces (certs, site1, site2, site3, traefik, external-secrets).
    - PersistentVolumes (pv-nfs-certs, pv-nfs-site1, pv-nfs-site2, pv-nfs-site3).
    - Resetea el cluster con kubeadm.
    - Limpia kubeconfig, iptables y configuración de CNI

📌 Notas
- Zona horaria: configurada en America/Santiago con NTP activo.
- SELinux: desactivado permanentemente.
- Solo puerto 443 expuesto: todo acceso será HTTPS.
- NFS: se monta en modo ReadOnlyMany.
- Certificados: sincronizados automáticamente cada 90 segundos.
- DNS externo: debe apuntar los registros A/AAAA de site1, site2, site3 al IP público del servidor, bien se puede apuntar via tabla hosts.
