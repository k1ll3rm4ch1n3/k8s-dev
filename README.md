k8s-dev 🚀
Repositorio público para la construcción de un cluster Kubernetes single-node reproducible, con automatización vía scripts y despliegue de componentes clave como Helm, Traefik, ExternalSecrets y almacenamiento persistente con NFS.
El objetivo es validar un flujo completo de instalación y operación, documentar cada paso y preparar el terreno para escalar a multi-node, multi-cloud.

🎯 Objetivo
- Helm instalado desde el inicio.
- Traefik como Ingress Controller.
- External Secrets Operator para consumir certificados centralizados.
- Pod sincronizador que exporta certificados SSL desde un storage NFS a Secrets.
- Tres sitios web de prueba (site1, site2, site3) cada uno en su propio namespace, sirviendo contenido desde NFS y expuestos con TLS en dominios distintos.

---

📋 Requisitos previos
• 	Sistema operativo: Oracle Linux 9 / Ubuntu 22.04 (probado en Oracle Linux).
• 	Dependencias instaladas:
    • 	Docker
    • 	kubectl
    • 	helm
    • 	git
    • 	nfs-utils
• 	Versiones mínimas probadas:
    • 	Kubernetes >= 1.29
    • 	Helm >= 3.14
• 	Recursos mínimos recomendados:
    • 	4 CPU
    • 	8 GB RAM
    • 	50 GB disco
• 	Certificados/secretos iniciales: si se requiere sincronización con "ExterbakSecrets"

## ⚙️ Instalación paso a paso
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/k1ll3rm4ch1n3/k8s-dev.git
   cd k8s-dev

2. Exportar variables de entorno necesarias:
   ```bash
   export CLUSTER_NAME=dev-cluster
   export NFS_SERVER=192.168.1.100
   export DOMAIN=dev.local

3. 	Ejecutar el script de inicialización:
    ```bash
   	./scripts/cluster-init.sh

4. 	Validar estado del cluster:
    ```bash
    kubectl get nodes
    kubectl get pods -A
   
5. 	Troubleshooting básico:
    ```bash
    kubectl describe pod <nombre>
    journalctl -u kubelet

📂 Estructura del repositorio
    k8s-dev/
        ├── README.md                # Guía principal del proyecto
        ├── scripts/                 # Scripts de automatización
        │   ├── cluster-init.sh      # Script principal para inicializar el cluster
        │   ├── helpers.sh           # Funciones auxiliares (si aplica)
        │   └── validate.sh          # Validaciones post-deploy
        ├── manifests/               # Manifests de Kubernetes
        │   ├── pv-pvc.yaml          # Persistencia con NFS
        │   ├── ingress-traefik.yaml # Configuración de Traefik
        │   ├── rbac.yaml            # Roles y permisos
        │   ├── secrets.yaml         # Ejemplo de secretos
        │   └── externalsecrets.yaml # Integración con ExternalSecrets
        ├── docs/                    # Documentación adicional
        │   ├── troubleshooting.md   # Guía de resolución de problemas
        │   └── roadmap.md           # Plan de evolución del proyecto
        └── .gitignore               # Archivos ignorados por git

✅ Validaciones rápidas
• 	Nodo listo:  → STATUS 
• 	Traefik corriendo: 
• 	NFS montado: 
• 	ExternalSecrets sincronizando: 

🌐 Configuración de red
    Este cluster utiliza un CNI (ej. flannel o calico). Validar con:
    ```bash
    kubectl get pods -n kube-system

📦 Ejemplo de despliegue de aplicación
Para validar que Ingress + Traefik funcionan correctamente:
1. Crear un deployment de Nginx:
   ```yaml
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: nginx
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:latest
            ports:
            - containerPort: 80

2. Crear un servicio:
   ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: nginx-service
    spec:
      selector:
        app: nginx
    ports:
      - protocol: TCP
        port: 80
        targetPort: 80

3. Crear un ingress para Traefik:
   ```yaml
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: nginx-ingress
      annotations:
        kubernetes.io/ingress.class: traefik
    spec:
      rules:
      - host: nginx.dev.local
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-service
                port:
                  number: 80
4. Validar acceso:
   ```bash
   curl http://nginx.dev.local
   
🛠️ Roadmap
• 	Consolidar documentación y reproducibilidad en single-node.
• 	Extender a cluster multi-node.
• 	Integración con GitLab + Terraform para despliegues multi-cloud.
• 	Portabilidad hacia GCP/Azure sin vendor lock-in.

🤝 Contribuir
• 	Reportar issues en GitHub.
• 	Pull requests bienvenidos (scripts, manifests, docs).
• 	Mantener estilo modular y documentado.

📜 Licencia
Este proyecto es open source bajo licencia MIT.

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
    # Navegar a https://site1.exampledomain.cl
                https://site2.exampledomain.cl
                https://site3.exampledomain.cl

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



