# 📘 DOCUMENTATION COMPLÈTE - Azure Load Balancer Lab

> **Projet** : Laboratoire Azure Load Balancer 3-tiers avec gestion systemd et intégration storage images  
> **Auteur** : VRM  
> **Version** : 2.0  
> **Date** : 2025

---

## 📑 TABLE DES MATIÈRES

1. [Vue d'ensemble du projet](#1-vue-densemble-du-projet)
2. [Architecture réseau](#2-architecture-réseau)
3. [Composants et services](#3-composants-et-services)
4. [Gestion des services systemd](#4-gestion-des-services-systemd)
5. [Intégration Azure Storage Images](#5-intégration-azure-storage-images)
6. [Déploiement et configuration](#6-déploiement-et-configuration)
7. [Tests et validation](#7-tests-et-validation)
8. [Troubleshooting](#8-troubleshooting)
9. [Référence rapide des commandes](#9-référence-rapide-des-commandes)

---

## 1. VUE D'ENSEMBLE DU PROJET

### 1.1 Objectif

Ce projet est un **laboratoire pédagogique** pour maîtriser Azure Load Balancer en déployant une architecture 3-tiers complète avec :
- ✅ Load Balancers (Public + 2 Internal)
- ✅ Backend Pools avec plusieurs VMs
- ✅ Health Probes pour haute disponibilité
- ✅ VNet Peering entre réseaux virtuels
- ✅ Services systemd pour auto-restart
- ✅ Intégration Azure Storage (images)
- ✅ Dashboard web moderne

### 1.2 Architecture simplifiée

```
Internet
   ↓
[Load Balancer Public] → Frontend VMs (10.1.0.x:80 et 8443)
   ↓
[Load Balancer Internal App] → App VMs (10.2.0.x:5000-5002)
   ↓
[Load Balancer Internal Data] → Data VMs (10.3.0.x:6000-6002)
   ↓
[Azure Storage Accounts] → Images (front.jpg, app.jpg, data.jpg)
```

### 1.3 Ce que vous allez apprendre

- ✅ Créer et configurer des Azure Load Balancers
- ✅ Mettre en place le VNet Peering
- ✅ Déployer des VMs avec Cloud-Init
- ✅ Gérer des services avec systemd
- ✅ Intégrer Azure Storage avec Private Endpoints
- ✅ Débugger des problèmes réseau dans Azure

---

## 2. ARCHITECTURE RÉSEAU

### 2.1 Structure des VNets

Le projet utilise **3 VNets isolés** avec peering :

#### VNet Frontend (10.1.0.0/16)
```
┌──────────────────────────────────────┐
│ front-vnet (10.1.0.0/16)            │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ vm-subnet (10.1.0.0/24)        │  │
│ │ - frontend-vm1    : 10.1.0.4   │  │
│ │ - frontend-vm2    : 10.1.0.5   │  │
│ │ - frontend-vm2_b  : 10.1.0.21  │  │
│ └────────────────────────────────┘  │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ AzureBastionSubnet             │  │
│ │ - bastion         : 10.1.1.0/26│  │
│ └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

#### VNet Application (10.2.0.0/16)
```
┌──────────────────────────────────────┐
│ app-vnet (10.2.0.0/16)              │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ vm-subnet (10.2.0.0/24)        │  │
│ │ - app-vm1     : 10.2.0.4       │  │
│ │ - app-vm2     : 10.2.0.5       │  │
│ │ - app-vm2_b   : 10.2.0.21      │  │
│ │ - app-lb (VIP): 10.2.0.250     │  │
│ └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

#### VNet Data (10.3.0.0/16)
```
┌──────────────────────────────────────┐
│ data-vnet (10.3.0.0/16)             │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ vm-subnet (10.3.0.0/24)        │  │
│ │ - data-vm1    : 10.3.0.4       │  │
│ │ - data-vm2    : 10.3.0.5       │  │
│ │ - data-vm2_b  : 10.3.0.21      │  │
│ │ - admin-vm    : 10.3.0.10      │  │
│ │ - data-lb (VIP): 10.3.0.250    │  │
│ └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 2.2 VNet Peering

```
front-vnet ←→ app-vnet
app-vnet ←→ data-vnet
```

**Note** : Pas de peering direct front ↔ data (par design, communication via app)

### 2.3 Load Balancers

| Load Balancer | Type | IP | Ports | Backend Pool |
|---------------|------|-----|-------|--------------|
| **front-lb** | Public | Public IP | 80, 8443 | frontend-vm1, vm2, vm2_b |
| **app-lb** | Internal | 10.2.0.250 | 5000, 5001, 5002 | app-vm1, vm2, vm2_b |
| **data-lb** | Internal | 10.3.0.250 | 6000, 6001, 6002 | data-vm1, vm2, vm2_b |

### 2.4 Flux d'une requête complète

```
1. Client Browser
   ↓
2. Internet → Load Balancer Public (front-lb)
   ↓
3. Round-Robin → frontend-vm1/vm2/vm2_b
   ↓
4. Frontend → App LB (10.2.0.250:5000/5001/5002)
   ↓
5. Round-Robin → app-vm1/vm2/vm2_b
   ↓
6. App → Data LB (10.3.0.250:6000/6001/6002)
   ↓
7. Round-Robin → data-vm1/vm2/vm2_b
   ↓
8. Data → Réponse JSON
   ↓
9. Réponse remonte : Data → App → Frontend → Client
```

---

## 3. COMPOSANTS ET SERVICES

### 3.1 Couche Frontend (Port 80 & 8443)

#### VMs Frontend

| VM | IP | Port | Instance | Fichiers |
|----|-----|------|----------|----------|
| frontend-vm1 | 10.1.0.4 | 80 | frontend-1 | frontend1.js, index1.html |
| frontend-vm2 | 10.1.0.5 | 8443 | frontend-2 | frontend2.js, index2.html |
| frontend-vm2_b | 10.1.0.21 | 8443 | frontend-2_b | frontend2_b.js, index2_b.html |

#### Endpoints Frontend

```
GET /                 → Interface HTML
GET /whoami           → { instance, address, port, timestamp }
GET /health           → OK (pour health probes)
GET /api              → Traverse toute la stack (Frontend→App→Data)
GET /probe/app        → Infos App Layer via LB
GET /probe/data       → Infos Data Layer via LB
GET /metrics          → Métriques (uptime, memory)

🖼️ STORAGE IMAGES:
GET /images           → Dashboard images (index1_images.html ou index2_images.html)
GET /image/frontend   → Proxy vers Storage Frontend
GET /image/app        → Proxy vers Storage App via app-lb
GET /image/data       → Proxy vers Storage Data via data-lb
GET /api/images       → Métadonnées JSON des images
```

#### Caractéristiques
- ✅ Écoute sur `0.0.0.0` (frontend1 port 80, frontend2/2_b port 8443)
- ✅ Timeouts 5 secondes sur requêtes HTTP
- ✅ Gestion d'erreurs complète avec logging
- ✅ Interface web moderne avec auto-refresh
- ✅ Dashboard images avec gradients CSS

### 3.2 Couche Application (Ports 5000-5002)

#### VMs Application

| VM | IP | Port | Instance | Fichiers |
|----|-----|------|----------|----------|
| app-vm1 | 10.2.0.4 | 5000 | app-1 | app1.js |
| app-vm2 | 10.2.0.5 | 5001 | app-2 | app2.js |
| app-vm2_b | 10.2.0.21 | 5002 | app-2_b | app2_b.js |

#### Endpoints Application

```
GET /whoami           → { instance, address, port, timestamp }
GET /health           → OK (pour health probes)
GET /api              → Proxy vers Data Layer (appelle /db)
GET /metrics          → Métriques monitoring

🖼️ STORAGE IMAGES:
GET /image/app        → Image app depuis Storage Account (⏳ placeholder 503)
```

#### Caractéristiques
- ✅ Écoute sur `0.0.0.0`
- ✅ Timeouts 5 secondes sur appels data
- ✅ Logging avec timestamps ISO

### 3.3 Couche Data (Ports 6000-6002)

#### VMs Data

| VM | IP | Port | Instance | Fichiers |
|----|-----|------|----------|----------|
| data-vm1 | 10.3.0.4 | 6000 | data-1 | data1.js |
| data-vm2 | 10.3.0.5 | 6001 | data-2 | data2.js |
| data-vm2_b | 10.3.0.21 | 6002 | data-2_b | data2_b.js |

#### Endpoints Data

```
GET /db               → { message, instance, timestamp } (données)
GET /whoami           → { instance, address, port, timestamp }
GET /health           → OK (pour health probes)
GET /metrics          → Métriques avec compteur requêtes

🖼️ STORAGE IMAGES:
GET /image/data       → Image data depuis Storage Account (⏳ placeholder 503)
```

#### Caractéristiques
- ✅ Écoute sur `0.0.0.0`
- ✅ Compteur de requêtes
- ✅ Réponses JSON structurées

### 3.4 VM Admin (Monitoring)

| VM | IP | Port | Instance | Fichiers |
|----|-----|------|----------|----------|
| admin-vm | 10.3.0.10 | 7000 | admin | admin.js, index.html |

#### Endpoints Admin

```
GET /               → Dashboard HTML
GET /status         → Inventaire complet
GET /probe          → Teste tous les serveurs
```

---

## 4. GESTION DES SERVICES SYSTEMD

### 4.1 Pourquoi systemd ?

**Avant (avec `node &`)** :
- ❌ Serveur s'arrête au redémarrage de VM
- ❌ Nécessite intervention manuelle pour relancer
- ❌ Si crash, reste arrêté
- ❌ Logs perdus au logout

**Après (avec systemd)** :
- ✅ Serveur démarre automatiquement au boot
- ✅ Aucune intervention manuelle
- ✅ Redémarrage automatique en cas de crash (5s)
- ✅ Logs persistants dans journalctl

### 4.2 Structure des services

Chaque serveur Node.js est géré par un service systemd :

```ini
[Unit]
Description=App-1 Node.js Server (Port 5000)
After=network.target

[Service]
Type=simple
User=cloud
WorkingDirectory=/home/cloud/app
ExecStart=/usr/bin/node /home/cloud/app/server.js
Restart=always                    # ← Redémarre automatiquement
RestartSec=5                      # Attendre 5 secondes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target        # ← Démarre au boot
```

### 4.3 Services créés

| Couche | Service | Port | VM |
|--------|---------|------|-----|
| **Frontend** | frontend1.service | 80 | frontend-vm1 |
| **Frontend** | frontend2.service | 8443 | frontend-vm2 |
| **Frontend** | frontend2.service | 8443 | frontend-vm2_b |
| **App** | app1.service | 5000 | app-vm1 |
| **App** | app2.service | 5001 | app-vm2 |
| **App** | app2_b.service | 5002 | app-vm2_b |
| **Data** | data1.service | 6000 | data-vm1 |
| **Data** | data2.service | 6001 | data-vm2 |
| **Data** | data2_b.service | 6002 | data-vm2_b |
| **Admin** | admin.service | 7000 | admin-vm |

### 4.4 Commandes essentielles

#### Voir l'état d'un service
```bash
sudo systemctl status app1.service
```

#### Redémarrer un service
```bash
sudo systemctl restart app1.service
```

#### Voir les logs en temps réel
```bash
sudo journalctl -u app1.service -f
```

#### Voir tous les services Node.js
```bash
sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"
```

#### Redémarrer tous les services d'une couche
```bash
# Tous les services frontend
sudo systemctl restart frontend*.service

# Tous les services app
sudo systemctl restart app*.service

# Tous les services data
sudo systemctl restart data*.service
```

#### Activer/Désactiver au démarrage
```bash
# Désactiver (ne redémarre plus au boot)
sudo systemctl disable app1.service

# Réactiver
sudo systemctl enable app1.service

# Vérifier l'état
sudo systemctl is-enabled app1.service
```

### 4.5 FIX Port 80 - CAP_NET_BIND_SERVICE

**Problème** : frontend1.service crashait car le port 80 est privilégié (<1024) et l'utilisateur `cloud` n'est pas root.

**Solution** : Ajouter la capability `CAP_NET_BIND_SERVICE` :

```ini
[Service]
Type=simple
User=cloud
ExecStart=/usr/bin/node /home/cloud/frontend/server.js
AmbientCapabilities=CAP_NET_BIND_SERVICE  # ← CRUCIAL pour port 80
Restart=always
RestartSec=5
```

**Résultat** : Le service peut maintenant binder sur port 80 sans être root.

### 4.6 Script de gestion (manage-services.sh)

```bash
# Voir l'état de tous les services
./manage-services.sh all-status

# Redémarrer un service
./manage-services.sh restart app1

# Voir les logs
./manage-services.sh logs app1
```

---

## 5. INTÉGRATION AZURE STORAGE IMAGES

### 5.1 Objectif

Afficher des images stockées dans Azure Storage Accounts via un dashboard web moderne, avec spécification de la provenance de chaque image.

### 5.2 Architecture Storage

```
┌────────────────────────────────────────────────────────────┐
│                   Azure Storage Accounts                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ stgfront       │  │ stgapp         │  │ stgdata      │ │
│  │ (NFS Share)    │  │ (Blob)         │  │ (Blob)       │ │
│  │ front.jpg      │  │ app.jpg        │  │ data.jpg     │ │
│  └────────┬───────┘  └────────┬───────┘  └──────┬───────┘ │
│           │                   │                  │         │
│  Private Endpoint    Private Endpoint   Private Endpoint  │
│           ↓                   ↓                  ↓         │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │ front-vnet     │  │ app-vnet       │  │ data-vnet    │ │
│  │ 10.1.0.0/16    │  │ 10.2.0.0/16    │  │ 10.3.0.0/16  │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### 5.3 Dashboard Images

#### Pages créées

| Fichier | Port | Design | Accès |
|---------|------|--------|-------|
| `index1_images.html` | 80 | Gradient bleu/violet | `GET /images` |
| `index2_images.html` | 8443 | Gradient violet/rose | `GET /images` |

#### Features du Dashboard
- ✨ **3 Cartes d'images** : Frontend, App, Data
- ✨ **Responsive** : Desktop (3 colonnes), Mobile (1 colonne)
- ✨ **Animations** : Hover effects, spinner loading
- ✨ **Auto-refresh** : Toutes les 30 secondes
- ✨ **Indicateurs** : 🟡 Chargement, 🟢 Succès, 🔴 Erreur
- ✨ **Métadonnées** : Source, fichier, statut pour chaque image
- ✨ **Info système** : Frontend/App/Data actifs, timestamp

### 5.4 Flux Image Proxy

```
Client Browser
   ↓
GET http://frontend-ip/image/app
   ↓
Frontend (proxy)
   ↓
App LB (10.2.0.250:5000)
   ↓
App Server (app1/app2/app2_b)
   ↓
Azure Storage Account (via Private Endpoint)
   ↓
Blob app.jpg
   ↓
Response → Client (image/jpeg)
```

### 5.5 Statut actuel

| Endpoint | Statut | Description |
|----------|--------|-------------|
| `GET /images` | ✅ Complet | Dashboard affiche cartes |
| `GET /image/frontend` | ⏳ Placeholder | Retourne 503 (Azure pending) |
| `GET /image/app` | ⏳ Placeholder | Retourne 503 (Azure pending) |
| `GET /image/data` | ⏳ Placeholder | Retourne 503 (Azure pending) |
| `GET /api/images` | ✅ Complet | Retourne métadonnées JSON |

### 5.6 Implémentation Azure (À faire)

#### Étape 1 : Créer les Storage Accounts

```bash
# Storage Frontend (NFS File Share)
STORAGE_NAME_FRONT="stgfront$(date +%s | tail -c 6)"

az storage account create \
  --name $STORAGE_NAME_FRONT \
  --resource-group rg-loadbalancer \
  --location francecentral \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --default-action Deny

# Créer NFS File Share
az storage share create \
  --account-name $STORAGE_NAME_FRONT \
  --name images \
  --protocol NFS \
  --quota 100

# Storage App (Blob Container)
STORAGE_NAME_APP="stgapp$(date +%s | tail -c 6)"

az storage account create \
  --name $STORAGE_NAME_APP \
  --resource-group rg-loadbalancer \
  --location francecentral \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --default-action Deny

# Créer Blob Container
az storage container create \
  --account-name $STORAGE_NAME_APP \
  --name images

# Storage Data (Blob Container)
STORAGE_NAME_DATA="stgdata$(date +%s | tail -c 6)"

az storage account create \
  --name $STORAGE_NAME_DATA \
  --resource-group rg-loadbalancer \
  --location francecentral \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --default-action Deny

# Créer Blob Container
az storage container create \
  --account-name $STORAGE_NAME_DATA \
  --name images
```

#### Étape 2 : Uploader les images

```bash
# Frontend (NFS Share)
az storage file upload \
  --account-name $STORAGE_NAME_FRONT \
  --share-name images \
  --source ./front.jpg \
  --path "front.jpg"

# App (Blob)
az storage blob upload \
  --account-name $STORAGE_NAME_APP \
  --container-name images \
  --name app.jpg \
  --file ./app.jpg

# Data (Blob)
az storage blob upload \
  --account-name $STORAGE_NAME_DATA \
  --container-name images \
  --name data.jpg \
  --file ./data.jpg
```

#### Étape 3 : Créer Private Endpoints

```bash
# Frontend Private Endpoint
az network private-endpoint create \
  --resource-group rg-loadbalancer \
  --name pe-stgfront \
  --vnet-name front-vnet \
  --subnet vm-subnet \
  --private-connection-resource-id \
    "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-loadbalancer/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME_FRONT" \
  --group-ids file

# App Private Endpoint
az network private-endpoint create \
  --resource-group rg-loadbalancer \
  --name pe-stgapp \
  --vnet-name app-vnet \
  --subnet vm-subnet \
  --private-connection-resource-id \
    "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-loadbalancer/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME_APP" \
  --group-ids blob

# Data Private Endpoint
az network private-endpoint create \
  --resource-group rg-loadbalancer \
  --name pe-stgdata \
  --vnet-name data-vnet \
  --subnet vm-subnet \
  --private-connection-resource-id \
    "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-loadbalancer/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME_DATA" \
  --group-ids blob
```

#### Étape 4 : Private DNS Zones

```bash
# Private DNS Zone pour File Share
az network private-dns zone create \
  --resource-group rg-loadbalancer \
  --name privatelink.file.core.windows.net

az network private-dns link vnet create \
  --resource-group rg-loadbalancer \
  --zone-name privatelink.file.core.windows.net \
  --name link-front-vnet \
  --virtual-network front-vnet \
  --registration-enabled false

# Private DNS Zone pour Blob
az network private-dns zone create \
  --resource-group rg-loadbalancer \
  --name privatelink.blob.core.windows.net

az network private-dns link vnet create \
  --resource-group rg-loadbalancer \
  --zone-name privatelink.blob.core.windows.net \
  --name link-app-vnet \
  --virtual-network app-vnet \
  --registration-enabled false

az network private-dns link vnet create \
  --resource-group rg-loadbalancer \
  --zone-name privatelink.blob.core.windows.net \
  --name link-data-vnet \
  --virtual-network data-vnet \
  --registration-enabled false
```

#### Étape 5 : Mettre à jour le code Node.js

```bash
# Sur App VMs
npm install @azure/storage-blob
```

Code à ajouter dans `app1.js`, `app2.js`, `app2_b.js` :

```javascript
const { BlobServiceClient } = require("@azure/storage-blob");
require('dotenv').config();

app.get('/image/app', async (_, res) => {
  try {
    const connectionString = process.env.AZURE_STORAGE_CONNECTION_STRING;
    if (!connectionString) {
      throw new Error('AZURE_STORAGE_CONNECTION_STRING not set');
    }

    const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
    const containerClient = blobServiceClient.getContainerClient("images");
    const blockBlobClient = containerClient.getBlockBlobClient("app.jpg");
    
    const downloadBlockBlobResponse = await blockBlobClient.download(0);
    
    res.setHeader('Content-Type', 'image/jpeg');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    
    downloadBlockBlobResponse.readableStreamBody.pipe(res);
  } catch (err) {
    console.error('[ERROR] /image/app failed:', err.message);
    res.status(503).json({ 
      error: 'Storage access failed',
      message: err.message,
      instance: 'app-1'
    });
  }
});
```

Idem pour `data1.js`, `data2.js`, `data2_b.js` avec `data.jpg`.

#### Étape 6 : Variables d'environnement

Créer `/home/cloud/app/.env` :
```env
AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=https;AccountName=stgapp...;AccountKey=...;EndpointSuffix=core.windows.net"
```

Idem pour `/home/cloud/data/.env` avec la connection string de stgdata.

---

## 6. DÉPLOIEMENT ET CONFIGURATION

### 6.1 Prérequis

- Compte Azure actif
- Azure CLI installé
- Accès SSH (via Bastion)

### 6.2 Déploiement complet

```bash
# 1. Cloner le projet
git clone https://github.com/CallmeVRM/azure-LB02.git
cd azure-LB02

# 2. Se connecter à Azure
az login

# 3. Créer le resource group
az group create --name rg-loadbalancer --location francecentral

# 4. Rendre le script exécutable
chmod +x infra.sh

# 5. Lancer le déploiement (15-20 minutes)
./infra.sh
```

### 6.3 Structure du script infra.sh

Le script `infra.sh` crée :
1. ✅ 3 VNets (front, app, data)
2. ✅ VNet Peering (front↔app, app↔data)
3. ✅ NSG avec règles de sécurité
4. ✅ Azure Bastion
5. ✅ 3 Load Balancers (1 public, 2 internes)
6. ✅ Health Probes
7. ✅ NAT Gateways
8. ✅ NICs avec IPs privées statiques
9. ✅ 10 VMs avec cloud-init (auto-deploy)

### 6.4 Vérifier le déploiement

```bash
# Lister toutes les VMs
az vm list --resource-group rg-loadbalancer --output table

# Récupérer l'IP publique du LB frontend
az network public-ip show \
  --resource-group rg-loadbalancer \
  --name lb-pub-ip-in \
  --query ipAddress \
  --output tsv
```

### 6.5 Attendre Cloud-Init (2-3 minutes)

```bash
# Se connecter à une VM via Bastion
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Vérifier les logs cloud-init
sudo tail -f /var/log/cloud-init-output.log

# Vérifier que le serveur tourne
ps aux | grep node

# Tester localement
curl http://localhost:5000/health
```

---

## 7. TESTS ET VALIDATION

### 7.1 Tester le Load Balancer frontend

```bash
# Récupérer l'IP publique
PUBLIC_IP=$(az network public-ip show \
  --resource-group rg-loadbalancer \
  --name lb-pub-ip-in \
  --query ipAddress \
  --output tsv)

echo "IP publique : $PUBLIC_IP"

# Tester port 80 (frontend-vm1)
curl http://$PUBLIC_IP:80/whoami

# Tester port 8443 (round-robin vm2/vm2_b)
for i in {1..10}; do
  curl -s http://$PUBLIC_IP:8443/whoami | grep -o '"instance":"[^"]*"'
done
# Devrait alterner entre frontend-2 et frontend-2_b
```

### 7.2 Tester la chaîne complète

```bash
# Traverse Frontend → App → Data
curl http://$PUBLIC_IP:8443/api

# Répéter pour voir round-robin
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://$PUBLIC_IP:8443/api
  sleep 1
done
```

### 7.3 Tester les LB internes (depuis une VM)

```bash
# Se connecter à frontend-vm1
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name frontend-vm1 -g rg-loadbalancer --query id -o tsv)

# Tester app-lb
curl http://10.2.0.250:5000/whoami
curl http://10.2.0.250:5001/whoami

# Round-robin app-lb
for i in {1..10}; do
  curl -s http://10.2.0.250:5000/whoami | grep -o '"instance":"[^"]*"'
done
# Devrait alterner entre app-1 et app-2

# Tester data-lb
curl http://10.3.0.250:6000/db
curl http://10.3.0.250:6001/db

# Round-robin data-lb
for i in {1..10}; do
  curl -s http://10.3.0.250:6000/db
done
# Devrait alterner entre DATA-LAYER-1 et DATA-LAYER-2
```

### 7.4 Tester les health checks

```bash
# Frontend
curl http://10.1.0.4:80/health        # frontend-vm1
curl http://10.1.0.5:8443/health      # frontend-vm2
curl http://10.1.0.21:8443/health     # frontend-vm2_b

# App
curl http://10.2.0.4:5000/health      # app-vm1
curl http://10.2.0.5:5001/health      # app-vm2
curl http://10.2.0.21:5002/health     # app-vm2_b

# Data
curl http://10.3.0.4:6000/health      # data-vm1
curl http://10.3.0.5:6001/health      # data-vm2
curl http://10.3.0.21:6002/health     # data-vm2_b

# Toutes devraient retourner "OK"
```

### 7.5 Simuler une panne (haute disponibilité)

```bash
# Se connecter à app-vm1
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Arrêter le service
sudo systemctl stop app1.service

# Depuis une autre VM, tester app-lb
for i in {1..20}; do
  curl -s http://10.2.0.250:5000/whoami | grep -o '"instance":"[^"]*"'
done
# Ne devrait retourner QUE "app-2" (app-1 est down)

# Redémarrer le service (auto-restart avec systemd)
sudo systemctl start app1.service

# Attendre 10-15 secondes (détection health probe)
# Retester : les deux instances devraient réapparaître
```

### 7.6 Tester le dashboard images

```bash
# Dans le navigateur
http://<PUBLIC_IP>/images           # Port 80
https://<PUBLIC_IP>:8443/images     # Port 8443

# Via curl
curl http://$PUBLIC_IP/images
curl http://$PUBLIC_IP/api/images | jq .
```

### 7.7 Tester les services après redémarrage

```bash
# Redémarrer une VM
az vm restart --name app-vm1 --resource-group rg-loadbalancer

# Attendre 1 minute
sleep 60

# Vérifier que le service a redémarré automatiquement
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

sudo systemctl status app1.service
# Devrait afficher "active (running)"

curl http://localhost:5000/health
# Devrait retourner "OK"
```

---

## 8. TROUBLESHOOTING

### 8.1 "Connection refused" sur un endpoint

**Symptômes** :
```bash
curl http://10.2.0.5:5001/health
curl: (7) Failed to connect to 10.2.0.5 port 5001: Connection refused
```

**Causes** :
1. Serveur Node.js pas démarré
2. Cloud-init pas terminé
3. Service systemd en erreur

**Solutions** :
```bash
# Se connecter à la VM
az network bastion ssh --name bastion --resource-group rg-loadbalancer \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm2 -g rg-loadbalancer --query id -o tsv)

# Vérifier cloud-init
sudo tail -100 /var/log/cloud-init-output.log | grep -i error

# Vérifier le service
sudo systemctl status app2.service

# Vérifier que Node.js tourne
ps aux | grep node

# Si pas de processus, redémarrer le service
sudo systemctl restart app2.service

# Tester localement
curl http://localhost:5001/health
```

### 8.2 Health probe échoue sur Azure

**Symptômes** : VM marquée "Unhealthy" dans le portail Azure

**Solutions** :
```bash
# Vérifier config health probe
az network lb probe show \
  --resource-group rg-loadbalancer \
  --lb-name app-lb \
  --name ProbeApp2

# Vérifier que /health répond localement
ssh vers VM
curl http://localhost:5001/health

# Vérifier que le port est ouvert
sudo ss -tlnp | grep 5001

# Vérifier les NSG
az network nsg rule list \
  --resource-group rg-loadbalancer \
  --nsg-name app-nsg \
  --output table
```

### 8.3 Round-robin ne fonctionne pas

**Symptômes** : Toutes les requêtes vont vers la même VM

**Causes** :
- Une seule VM est healthy
- Session affinity activée

**Solutions** :
```bash
# Vérifier que toutes les VMs sont healthy
for i in {1..10}; do
  curl -s http://10.2.0.250:5000/whoami
  sleep 0.5
done

# Vérifier backend pool
az network lb address-pool show \
  --resource-group rg-loadbalancer \
  --lb-name app-lb \
  --name app-backpool

# Vérifier que les NICs sont dans le backend pool
az network nic show --name app-nic-vm1 -g rg-loadbalancer \
  --query "ipConfigurations[0].loadBalancerBackendAddressPools"
```

### 8.4 Service systemd reste "inactive (dead)"

**Causes** :
- Fichier server.js n'existe pas
- Permissions insuffisantes
- Erreur dans le code

**Solutions** :
```bash
# Vérifier que le fichier existe
ls -la /home/cloud/app/server.js

# Vérifier les permissions
sudo chown cloud:cloud /home/cloud/app/server.js
sudo chmod 755 /home/cloud/app/server.js

# Voir les erreurs
sudo journalctl -u app1.service -n 20

# Vérifier Node.js
which node
node --version

# Redémarrer le service
sudo systemctl restart app1.service
```

### 8.5 "Cannot find module 'express'"

**Solutions** :
```bash
# Se connecter à la VM
# Installer express
cd /home/cloud/app
npm init -y
npm install express

# Redémarrer le service
sudo systemctl restart app1.service
```

### 8.6 Timeout sur requêtes (5 secondes)

**Causes** :
- Latence réseau élevée
- Backend lent à répondre
- VNet Peering manquant

**Solutions** :
```bash
# Vérifier latence
ping 10.2.0.250
ping 10.3.0.250

# Tester chaîne complète
time curl http://10.1.0.20:8443/api

# Vérifier peering
az network vnet peering list \
  --resource-group rg-loadbalancer \
  --vnet-name app-vnet \
  --output table

# Augmenter timeout dans le code si nécessaire
# Dans frontend2.js : httpGetWithTimeout(url, 10000) au lieu de 5000
```

### 8.7 Dashboard images affiche "Erreur"

**Causes** :
- Storage Accounts pas créés
- Private Endpoints manquants
- Code pas mis à jour

**Solutions** :
```bash
# Vérifier que les endpoints retournent 503 (normal si Azure pas fait)
curl http://<PUBLIC_IP>/image/app
curl http://<PUBLIC_IP>/image/data

# Vérifier les logs frontend
sudo journalctl -u frontend2.service -n 50

# Si Azure créé, vérifier Storage Accounts
az storage account list --resource-group rg-loadbalancer --output table
```

### 8.8 Frontend1 service crash loop (port 80)

**Cause** : Manque CAP_NET_BIND_SERVICE

**Solution** :
```bash
# Vérifier que la capability est présente
systemctl cat frontend1.service | grep AmbientCapabilities

# Si manquante, ajouter
sudo nano /etc/systemd/system/frontend1.service
# Ajouter : AmbientCapabilities=CAP_NET_BIND_SERVICE

sudo systemctl daemon-reload
sudo systemctl restart frontend1.service
```

---

## 9. RÉFÉRENCE RAPIDE DES COMMANDES

### 9.1 Gestion des services

```bash
# Voir l'état
sudo systemctl status app1.service

# Redémarrer
sudo systemctl restart app1.service

# Arrêter
sudo systemctl stop app1.service

# Démarrer
sudo systemctl start app1.service

# Activer au boot
sudo systemctl enable app1.service

# Désactiver
sudo systemctl disable app1.service

# Vérifier si activé
sudo systemctl is-enabled app1.service
```

### 9.2 Logs

```bash
# Logs en temps réel
sudo journalctl -u app1.service -f

# 50 dernières lignes
sudo journalctl -u app1.service -n 50

# Depuis 10 minutes
sudo journalctl -u app1.service --since "10 minutes ago"

# Erreurs uniquement
sudo journalctl -u app1.service -p err
```

### 9.3 Tests réseau

```bash
# Vérifier port ouvert
sudo ss -tlnp | grep 5000

# Vérifier processus Node.js
ps aux | grep node

# Test local
curl http://localhost:5000/health

# Test via LB
curl http://10.2.0.250:5000/whoami
```

### 9.4 Azure CLI

```bash
# Lister VMs
az vm list -g rg-loadbalancer --output table

# IP publique LB
az network public-ip show -g rg-loadbalancer -n lb-pub-ip-in --query ipAddress -o tsv

# Backend pool
az network lb address-pool show -g rg-loadbalancer --lb-name app-lb --name app-backpool

# Health probes
az network lb probe list -g rg-loadbalancer --lb-name app-lb -o table

# VNet peering
az network vnet peering list -g rg-loadbalancer --vnet-name app-vnet -o table
```

### 9.5 Connexion Bastion

```bash
# Template
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name <VM_NAME> -g rg-loadbalancer --query id -o tsv)

# Exemples
# Frontend-vm1
az network bastion ssh --name bastion -g rg-loadbalancer --auth-type password --username cloud --target-resource-id $(az vm show --name frontend-vm1 -g rg-loadbalancer --query id -o tsv)

# App-vm1
az network bastion ssh --name bastion -g rg-loadbalancer --auth-type password --username cloud --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Data-vm1
az network bastion ssh --name bastion -g rg-loadbalancer --auth-type password --username cloud --target-resource-id $(az vm show --name data-vm1 -g rg-loadbalancer --query id -o tsv)
```

### 9.6 Redémarrer tous les services

```bash
# Frontend
sudo systemctl restart frontend*.service

# App
sudo systemctl restart app*.service

# Data
sudo systemctl restart data*.service

# Tous
sudo systemctl restart frontend*.service app*.service data*.service admin.service
```

### 9.7 Vérifier tous les services

```bash
# Liste
sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"

# Statut détaillé
for service in frontend1 frontend2 app1 app2 app2_b data1 data2 data2_b admin; do
  echo "=== $service.service ==="
  sudo systemctl status ${service}.service | grep -E "Active|Loaded"
done
```

### 9.8 Alias utiles (ajouter à ~/.bashrc)

```bash
alias service-status='sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"'
alias service-logs='sudo journalctl -u "*.service" -f | grep -E "frontend|app|data|admin"'
alias service-restart-all='sudo systemctl restart frontend*.service app*.service data*.service admin.service'

alias logs-app1='sudo journalctl -u app1.service -f'
alias logs-app2='sudo journalctl -u app2.service -f'
alias logs-data1='sudo journalctl -u data1.service -f'

alias test-app1='curl http://localhost:5000/whoami'
alias test-data1='curl http://localhost:6000/whoami'
```

### 9.9 Nettoyage (supprimer toutes les ressources)

```bash
# Supprimer TOUT le resource group
az group delete --name rg-loadbalancer --yes --no-wait

# Vérifier suppression en cours
az group show --name rg-loadbalancer --query properties.provisioningState

# Lister tous les resource groups
az group list --output table
```

---

## 📊 TABLEAU RÉCAPITULATIF COMPLET

### VMs et Services

| Couche | VM | IP | Port | Instance | Service | Fichiers |
|--------|-----|-----|------|----------|---------|----------|
| **Frontend** | frontend-vm1 | 10.1.0.4 | 80 | frontend-1 | frontend1.service | frontend1.js, index1.html, index1_images.html |
| **Frontend** | frontend-vm2 | 10.1.0.5 | 8443 | frontend-2 | frontend2.service | frontend2.js, index2.html, index2_images.html |
| **Frontend** | frontend-vm2_b | 10.1.0.21 | 8443 | frontend-2_b | frontend2.service | frontend2_b.js, index2_b.html |
| **App** | app-vm1 | 10.2.0.4 | 5000 | app-1 | app1.service | app1.js |
| **App** | app-vm2 | 10.2.0.5 | 5001 | app-2 | app2.service | app2.js |
| **App** | app-vm2_b | 10.2.0.21 | 5002 | app-2_b | app2_b.service | app2_b.js |
| **Data** | data-vm1 | 10.3.0.4 | 6000 | data-1 | data1.service | data1.js |
| **Data** | data-vm2 | 10.3.0.5 | 6001 | data-2 | data2.service | data2.js |
| **Data** | data-vm2_b | 10.3.0.21 | 6002 | data-2_b | data2_b.service | data2_b.js |
| **Admin** | admin-vm | 10.3.0.10 | 7000 | admin | admin.service | admin.js, index.html |

### Load Balancers

| LB | Type | IP | Ports | Backend Pool | Health Probe |
|----|------|-----|-------|--------------|--------------|
| **front-lb** | Public | Public IP | 80, 8443 | frontend-vm1, vm2, vm2_b | /health |
| **app-lb** | Internal | 10.2.0.250 | 5000, 5001, 5002 | app-vm1, vm2, vm2_b | /health |
| **data-lb** | Internal | 10.3.0.250 | 6000, 6001, 6002 | data-vm1, vm2, vm2_b | /health |

### Storage Accounts (À créer)

| Storage | Type | VNet | Container/Share | Image |
|---------|------|------|----------------|-------|
| **stgfront** | NFS File Share | front-vnet | images | front.jpg |
| **stgapp** | Blob Container | app-vnet | images | app.jpg |
| **stgdata** | Blob Container | data-vnet | images | data.jpg |

---

## 🎓 RESSOURCES COMPLÉMENTAIRES

### Documentation officielle Azure
- [Azure Load Balancer](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview)
- [VNet Peering](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)
- [Cloud-Init](https://learn.microsoft.com/azure/virtual-machines/linux/using-cloud-init)
- [Azure Storage](https://learn.microsoft.com/azure/storage/)
- [Private Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)

### Systemd
- [Systemd Documentation](https://systemd.io/)
- [Systemctl Manual](https://man7.org/linux/man-pages/man1/systemctl.1.html)
- [Journalctl Manual](https://man7.org/linux/man-pages/man1/journalctl.1.html)

### Outils
- **Azure CLI** : https://learn.microsoft.com/cli/azure/
- **Azure Portal** : https://portal.azure.com
- **VS Code + Azure Extension** : Pour éditer et déployer

---

## 📝 CHECKLIST FINALE

Avant de considérer le lab comme terminé, vérifiez :

- [ ] Toutes les 10 VMs sont déployées et running
- [ ] Les 3 Load Balancers (front-lb, app-lb, data-lb) fonctionnent
- [ ] Les health probes sont tous "healthy"
- [ ] `/whoami` retourne le nom de chaque instance
- [ ] Round-robin fonctionne (alterner entre VMs)
- [ ] Chaîne complète Frontend → App → Data fonctionne
- [ ] Azure Bastion permet connexion aux VMs
- [ ] Services systemd démarrent automatiquement
- [ ] Logs cloud-init sans erreurs
- [ ] Dashboard admin (port 7000) fonctionne
- [ ] Dashboard images (port 80/8443) affiche les cartes
- [ ] Simulation panne déclenche failover
- [ ] Services redémarrent après reboot VM

---

## ✅ STATUT DU PROJET

| Composant | Statut | Description |
|-----------|--------|-------------|
| **Infrastructure Azure** | ✅ Complet | VNets, LB, VMs, Peering, Bastion |
| **Services systemd** | ✅ Complet | Auto-start, auto-restart, logs |
| **Fix Port 80** | ✅ Complet | CAP_NET_BIND_SERVICE ajouté |
| **Dashboard Images (Web)** | ✅ Complet | HTML, endpoints, proxy |
| **Storage Accounts Azure** | ⏳ À faire | Créer stgfront, stgapp, stgdata |
| **Private Endpoints** | ⏳ À faire | Configurer pour chaque storage |
| **Private DNS** | ⏳ À faire | Zones DNS pour résolution |
| **Code Storage SDK** | ⏳ À faire | Intégrer @azure/storage-blob |
| **Tests finaux** | ⏳ À faire | Valider images affichées |

---

**Auteur** : VRM  
**Projet** : Azure Load Balancer Lab  
**Repository** : [github.com/CallmeVRM/azure-LB02](https://github.com/CallmeVRM/azure-LB02)  
**Licence** : MIT  
**Date** : 2025

---

**Pour toute question ou problème** :
- Consulter cette documentation
- Vérifier les logs : `sudo journalctl -u <service>.service -f`
- Consulter les logs cloud-init : `sudo tail -f /var/log/cloud-init-output.log`
- Ouvrir une issue sur GitHub

**Bon apprentissage ! 🚀**
