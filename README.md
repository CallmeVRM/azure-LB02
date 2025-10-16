# Azure Load Balancer - Lab Pédagogique 🎓

> **Objectif** : Prise en main d'Azure Load Balancer en déployant une architecture 3-tiers avec répartition de charge

---

## 📖 Introduction

Ce projet est un **laboratoire pratique** pour comprendre et maîtriser **Azure Load Balancer**. Vous allez déployer une application web à 3 couches (Frontend, Application, Data) avec des Load Balancers pour distribuer le trafic entre plusieurs serveurs.

### Ce que vous allez apprendre

- ✅ Créer et configurer des **Azure Load Balancers** (Public et Internal)
- ✅ Utiliser des **Backend Pools** avec plusieurs VMs
- ✅ Configurer des **Health Probes** pour la haute disponibilité
- ✅ Mettre en place le **VNet Peering** entre réseaux virtuels
- ✅ Déployer des VMs automatiquement avec **Cloud-Init**
- ✅ Comprendre le **round-robin** et la répartition de charge
- ✅ Configurer des **NSG (Network Security Groups)**
- ✅ Utiliser un **Azure Bastion** pour se connecter aux VMs

### Architecture simplifiée

```
Internet
   ↓
[Load Balancer Public] → Frontend VMs (10.1.0.x:80 et 10.1.0.x:8443)
   ↓
[Load Balancer Internal App] → App VMs (10.2.0.x:5000 et 5001)
   ↓
[Load Balancer Internal Data] → Data VMs (10.3.0.x:6000 et 6001)
```

---

## 🏗️ Architecture du projet

### Vue d'ensemble des couches

Le projet est composé de **3 couches isolées** dans des réseaux virtuels séparés :

#### 1️⃣ **Couche Frontend** (front-vnet: 10.1.0.0/16)

**Rôle** : Servir l'interface utilisateur et recevoir les requêtes HTTP depuis Internet

**VMs déployées** :
- `frontend-vm1` (10.1.0.4:80) - Port 80 standard
- `frontend-vm2` (10.1.0.5:8443) - Port 8443 sécurisé
- `frontend-vm2_b` (10.1.0.21:8443) - VM test supplémentaire

**Load Balancer** : `front-lb` (Public IP) - Distribue le trafic HTTP/HTTPS

**Ports exposés** :
- Port 80 → Routé vers frontend-vm1
- Port 8443 → Routé vers frontend-vm2 et frontend-vm2_b (round-robin)

**Endpoints disponibles** :
- `GET /` - Interface HTML
- `GET /whoami` - Informations sur l'instance
- `GET /api` - Appelle la couche App (traverse toute la stack)
- `GET /health` - Health check
- `GET /probe/app` - Interroge la couche App
- `GET /probe/data` - Interroge la couche Data

#### 2️⃣ **Couche Application** (app-vnet: 10.2.0.0/16)

**Rôle** : Traiter la logique métier et faire le pont entre Frontend et Data

**VMs déployées** :
- `app-vm1` (10.2.0.4:5000)
- `app-vm2` (10.2.0.5:5001)
- `app-vm2_b` (10.2.0.21:5002)

**Load Balancer** : `app-lb` (IP interne 10.2.0.250) - Distribue entre les VMs app

**Ports** :
- 5000 → Routé vers app-vm1
- 5001 → Routé vers app-vm2
- 5002 → Routé vers app-vm2_b (test)

**Endpoints disponibles** :
- `GET /whoami` - Informations sur l'instance
- `GET /api` - Appelle la couche Data
- `GET /health` - Health check

#### 3️⃣ **Couche Data** (data-vnet: 10.3.0.0/16)

**Rôle** : Simuler une base de données ou un backend

**VMs déployées** :
- `data-vm1` (10.3.0.4:6000)
- `data-vm2` (10.3.0.5:6001)
- `data-vm2_b` (10.3.0.21:6002)

**Load Balancer** : `data-lb` (IP interne 10.3.0.250) - Distribue entre les VMs data

**Ports** :
- 6000 → Routé vers data-vm1
- 6001 → Routé vers data-vm2
- 6002 → Routé vers data-vm2_b (test)

**Endpoints disponibles** :
- `GET /db` - Retourne des données simulées
- `GET /whoami` - Informations sur l'instance
- `GET /health` - Health check

#### 4️⃣ **VM Admin** (Bonus)

**Rôle** : Console d'administration pour surveiller toutes les VMs

- `admin-vm` (10.3.0.10:7000)
- Interroge tous les services et affiche leur statut
- Endpoint : `GET /probe` - Teste tous les serveurs

### Schéma réseau complet

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET                               │
└────────────────────────┬────────────────────────────────────┘
                         │
                    [Public IP]
                         │
                 ┌───────▼────────┐
                 │   front-lb     │ (Load Balancer Public)
                 │  - Port 80     │
                 │  - Port 8443   │
                 └────────┬───────┘
                          │ Round-Robin
        ┌─────────────────┼─────────────────┐
        │                 │                 │
  ┌─────▼─────┐   ┌──────▼──────┐   ┌─────▼─────┐
  │frontend-vm1│   │frontend-vm2│   │frontend-vm2_b│
  │ 10.1.0.4  │   │ 10.1.0.5   │   │ 10.1.0.21 │
  │  Port 80  │   │ Port 8443  │   │ Port 8443 │
  └─────┬─────┘   └──────┬──────┘   └─────┬─────┘
        │                │                 │
        └────────────────┼─────────────────┘
                         │ VNet Peering
                 ┌───────▼────────┐
                 │    app-lb      │ (Load Balancer Internal)
                 │  10.2.0.250    │
                 │  - Port 5000   │
                 │  - Port 5001   │
                 └────────┬───────┘
                          │ Round-Robin
        ┌─────────────────┼─────────────────┐
        │                 │                 │
  ┌─────▼─────┐   ┌──────▼──────┐   ┌─────▼─────┐
  │  app-vm1  │   │  app-vm2    │   │ app-vm2_b │
  │ 10.2.0.4  │   │ 10.2.0.5    │   │ 10.2.0.21 │
  │ Port 5000 │   │ Port 5001   │   │ Port 5002 │
  └─────┬─────┘   └──────┬──────┘   └─────┬─────┘
        │                │                 │
        └────────────────┼─────────────────┘
                         │ VNet Peering
                 ┌───────▼────────┐
                 │    data-lb     │ (Load Balancer Internal)
                 │  10.3.0.250    │
                 │  - Port 6000   │
                 │  - Port 6001   │
                 └────────┬───────┘
                          │ Round-Robin
        ┌─────────────────┼─────────────────┐
        │                 │                 │
  ┌─────▼─────┐   ┌──────▼──────┐   ┌─────▼─────┐
  │ data-vm1  │   │ data-vm2    │   │data-vm2_b │
  │ 10.3.0.4  │   │ 10.3.0.5    │   │ 10.3.0.21 │
  │ Port 6000 │   │ Port 6001   │   │ Port 6002 │
  └───────────┘   └─────────────┘   └───────────┘
```

---

## 🛠️ Prérequis

### Compte Azure

- Un abonnement Azure actif (gratuit ou payant)
- Azure CLI installé : https://learn.microsoft.com/cli/azure/install-azure-cli

### Connaissances de base

- Commandes Linux de base (ssh, curl, grep)
- Concepts réseau (IP, port, subnet)
- Notions JavaScript/Node.js (optionnel)

### Outils locaux

```bash
# Installer Azure CLI sur Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Se connecter à Azure
az login

# Créer un resource group
az group create --name rg-loadbalancer --location francecentral
```

---

## 📁 Structure des fichiers

```
azure-LB02/
│
├── infra.sh                    # ⭐ Script principal de déploiement Azure
│
├── frontend/                   # Couche Frontend (port 80 et 8443)
│   ├── frontend1.js            # Serveur Node.js pour frontend-vm1 (port 80)
│   ├── frontend2.js            # Serveur Node.js pour frontend-vm2 (port 8443)
│   ├── frontend2_b.js          # Serveur Node.js pour frontend-vm2_b (port 8443)
│   ├── index1.html             # Page HTML pour frontend-vm1
│   ├── index2.html             # Page HTML moderne pour frontend-vm2
│   ├── index2_b.html           # Page HTML pour frontend-vm2_b
│   ├── cloud-init-frontend1.yaml     # Déploiement automatique vm1
│   ├── cloud-init-frontend2.yaml     # Déploiement automatique vm2
│   └── cloud-init-frontend2_b.yaml   # Déploiement automatique vm2_b
│
├── app/                        # Couche Application (ports 5000, 5001, 5002)
│   ├── app1.js                 # Serveur Node.js pour app-vm1
│   ├── app2.js                 # Serveur Node.js pour app-vm2
│   ├── app2_b.js               # Serveur Node.js pour app-vm2_b
│   ├── cloud-init-app1.yaml
│   ├── cloud-init-app2.yaml
│   └── cloud-init-app2_b.yaml
│
├── data/                       # Couche Data (ports 6000, 6001, 6002)
│   ├── data1.js                # Serveur Node.js pour data-vm1
│   ├── data2.js                # Serveur Node.js pour data-vm2
│   ├── data2_b.js              # Serveur Node.js pour data-vm2_b
│   ├── cloud-init-data1.yaml
│   ├── cloud-init-data2.yaml
│   └── cloud-init-data2_b.yaml
│
├── admin/                      # VM Admin (monitoring)
│   ├── admin.js                # Serveur Node.js de monitoring
│   ├── index.html              # Interface admin
│   └── cloud-init-admin.yaml
│
├── README.md                   # 📖 Ce fichier (documentation principale)
├── STACK-8443-README.md        # Documentation détaillée stack 8443
├── TEST-LB-APP-DATA.md         # Guide de test pour VMs _b
└── FRONTEND-2B-README.md       # Guide spécifique frontend-vm2_b
```

### Rôle de chaque fichier

#### **infra.sh** ⭐
Le script Bash qui crée **toute l'infrastructure Azure** :
- VNets et subnets
- Network Security Groups (NSG)
- Load Balancers (public et internes)
- Health Probes
- NAT Gateways
- NICs et VMs
- Bastion pour la connexion SSH

#### **Fichiers .js**
Serveurs Node.js/Express qui exposent des endpoints HTTP :
- Écoutent sur un port spécifique
- Répondent à `/whoami`, `/health`, `/api`, `/db`
- Communiquent avec la couche suivante via Load Balancer

#### **Fichiers cloud-init .yaml**
Scripts d'initialisation automatique des VMs :
- Installent Node.js, npm, git
- Clonent ce dépôt GitHub
- Copient les fichiers .js
- Installent les dépendances (Express)
- Démarrent le serveur automatiquement

#### **Fichiers .html**
Interfaces web statiques pour visualiser l'architecture et tester les endpoints

---

## 🧠 Concepts Azure expliqués

### 1. Azure Load Balancer

**Qu'est-ce que c'est ?**
Un service Azure qui distribue le trafic réseau entre plusieurs serveurs (VMs). Il agit comme un "répartiteur" intelligent.

**Types de Load Balancer dans ce projet** :

#### **Public Load Balancer** (`front-lb`)
- Possède une **IP publique** accessible depuis Internet
- Reçoit les requêtes HTTP/HTTPS des utilisateurs
- Distribue vers les VMs frontend dans le backend pool
- **Cas d'usage** : Site web, API publique

#### **Internal Load Balancer** (`app-lb` et `data-lb`)
- Possède une **IP privée** (10.2.0.250, 10.3.0.250)
- Accessible uniquement depuis les VNets Azure (via peering)
- Distribue le trafic entre les VMs internes
- **Cas d'usage** : Micro-services, bases de données

### 2. Backend Pool (Pool de backends)

**Définition** : Groupe de VMs qui reçoivent le trafic du Load Balancer

**Dans ce projet** :
- `front-backpool` : frontend-vm1, frontend-vm2, frontend-vm2_b
- `app-backpool` : app-vm1, app-vm2, app-vm2_b
- `data-backpool` : data-vm1, data-vm2, data-vm2_b

**Fonctionnement** : Le Load Balancer distribue les requêtes en **round-robin** :
```
Requête 1 → VM1
Requête 2 → VM2
Requête 3 → VM3
Requête 4 → VM1 (on recommence)
```

### 3. Health Probe (Sonde de santé)

**Rôle** : Vérifier qu'une VM est "en bonne santé" avant d'envoyer du trafic

**Fonctionnement** :
- Le Load Balancer envoie une requête HTTP à `/health` toutes les 5 secondes
- Si la VM répond "OK", elle est marquée **healthy** (saine)
- Si la VM ne répond pas 2 fois consécutives, elle est marquée **unhealthy** (défaillante)
- Le Load Balancer n'envoie plus de trafic vers les VMs unhealthy

**Exemple dans le projet** :
```bash
# Health probe pour app-lb sur port 5000
az network lb probe create \
  --lb-name app-lb \
  --name ProbeApp1 \
  --protocol http \
  --path /health \
  --port 5000
```

**Code dans app1.js** :
```javascript
app.get('/health', (_, res) => res.send('OK'));
```

### 4. VNet Peering (Peering de réseaux virtuels)

**Problème** : Les 3 couches sont dans des VNets différents (front-vnet, app-vnet, data-vnet)

**Solution** : Le **VNet Peering** permet la communication directe entre VNets

**Configuration dans infra.sh** :
```bash
# Peering front-vnet ↔ app-vnet
az network vnet peering create --vnet-name front-vnet --remote-vnet app-vnet
az network vnet peering create --vnet-name app-vnet --remote-vnet front-vnet

# Peering app-vnet ↔ data-vnet
az network vnet peering create --vnet-name app-vnet --remote-vnet data-vnet
az network vnet peering create --vnet-name data-vnet --remote-vnet app-vnet
```

**Résultat** : frontend-vm2 (10.1.0.5) peut communiquer avec app-lb (10.2.0.250)

### 5. Network Security Group (NSG)

**Définition** : Pare-feu virtuel qui contrôle le trafic entrant/sortant

**Dans ce projet** : Les NSG autorisent **tout le trafic** pour simplifier l'apprentissage
```bash
az network nsg rule create \
  --nsg-name front-nsg \
  --name AllowAll \
  --priority 100 \
  --source-address-prefixes '*' \
  --destination-port-ranges "*" \
  --access Allow
```

> ⚠️ **En production** : Il faut restreindre les ports (80, 443, 5000, 6000 uniquement)

### 6. NAT Gateway

**Problème** : Les VMs internes (app-vnet, data-vnet) n'ont pas d'IP publique

**Solution** : Le **NAT Gateway** permet aux VMs internes de se connecter à Internet (pour télécharger des paquets npm)

**Dans infra.sh** :
```bash
# Créer NAT Gateway pour app-vnet
az network nat gateway create --name app-nat --public-ip-addresses nat-gateway-ip-app

# L'associer au subnet
az network vnet subnet update --vnet-name app-vnet --nat-gateway app-nat
```

### 7. Azure Bastion

**Problème** : Comment se connecter en SSH aux VMs sans IP publique ?

**Solution** : **Azure Bastion** est un service de connexion sécurisée sans exposer les VMs à Internet

**Connexion** :
```bash
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)
```

### 8. Cloud-Init

**Définition** : Script d'initialisation qui s'exécute automatiquement au démarrage d'une VM Ubuntu

**Exemple** (cloud-init-app1.yaml) :
```yaml
#cloud-config
package_update: true
packages:
  - nodejs
  - npm
  - git
runcmd:
  - git clone https://github.com/CallmeVRM/azure-LB02 /tmp/lab
  - cp /tmp/lab/app/app1.js /home/cloud/server.js
  - cd /home/cloud
  - npm init -y
  - npm install express
  - node /home/cloud/server.js &
```

**Avantage** : Déploiement 100% automatique, pas besoin de se connecter en SSH

---

## 🚀 Déploiement pas à pas

### Étape 1 : Cloner le projet

```bash
# Cloner le dépôt GitHub
git clone https://github.com/CallmeVRM/azure-LB02.git
cd azure-LB02
```

### Étape 2 : Se connecter à Azure

```bash
# Connexion interactive
az login

# Vérifier l'abonnement actif
az account show --output table

# Créer un resource group (groupe de ressources)
az group create --name rg-loadbalancer --location francecentral
```

### Étape 3 : Exécuter le script de déploiement

```bash
# Rendre le script exécutable
chmod +x infra.sh

# Lancer le déploiement (durée : 15-20 minutes)
./infra.sh
```

**Ce que fait le script** :
1. ✅ Crée 3 VNets (front, app, data)
2. ✅ Configure le peering entre les VNets
3. ✅ Crée les NSG avec règles de sécurité
4. ✅ Crée un Azure Bastion
5. ✅ Crée 3 Load Balancers (1 public, 2 internes)
6. ✅ Configure les health probes
7. ✅ Crée les NAT Gateways
8. ✅ Crée les NICs avec IPs privées statiques
9. ✅ Associe les NICs aux backend pools
10. ✅ Crée 9 VMs avec cloud-init (déploiement automatique)

### Étape 4 : Vérifier le déploiement

```bash
# Lister toutes les VMs créées
az vm list --resource-group rg-loadbalancer --output table

# Vérifier l'IP publique du Load Balancer frontend
az network public-ip show \
  --resource-group rg-loadbalancer \
  --name lb-pub-ip-in \
  --query ipAddress \
  --output tsv
```

### Étape 5 : Attendre que les VMs soient prêtes

Cloud-init prend **2-3 minutes** pour installer Node.js et démarrer les serveurs.

```bash
# Se connecter à une VM pour vérifier les logs cloud-init
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Une fois connecté, vérifier les logs
sudo tail -f /var/log/cloud-init-output.log

# Vérifier que le serveur Node.js tourne
ps aux | grep node

# Tester localement
curl http://localhost:5000/health
# Devrait retourner : OK
```

---

## ⚙️ Fonctionnement de l'application

### Flux d'une requête complète

Voici ce qui se passe quand un utilisateur visite `http://<PUBLIC_IP>:8443/api` :

```
1. Navigateur → Internet → Load Balancer Public (front-lb)
   [Requête HTTP vers PUBLIC_IP:8443]

2. front-lb → Choix d'une VM frontend (round-robin)
   [Distribue vers 10.1.0.5:8443 ou 10.1.0.21:8443]

3. frontend-vm2 reçoit la requête sur /api
   Code : http.get('http://10.2.0.250:5001/api')
   [Appelle le Load Balancer app-lb]

4. app-lb → Choix d'une VM app (round-robin)
   [Distribue vers 10.2.0.5:5001 ou 10.2.0.21:5002]

5. app-vm2 reçoit la requête sur /api
   Code : http.get('http://10.3.0.250:6001/db')
   [Appelle le Load Balancer data-lb]

6. data-lb → Choix d'une VM data (round-robin)
   [Distribue vers 10.3.0.5:6001 ou 10.3.0.21:6002]

7. data-vm2 reçoit la requête sur /db
   Code : res.send('DATA-LAYER-2: OK')
   [Retourne une réponse JSON]

8. Réponse remonte la chaîne
   data-vm2 → app-vm2 → frontend-vm2 → front-lb → Navigateur
```

### Endpoints détaillés par couche

#### **Frontend** (Ports 80, 8443)

| Endpoint | Méthode | Description | Exemple de réponse |
|----------|---------|-------------|-------------------|
| `/` | GET | Page HTML d'accueil | Interface web |
| `/whoami` | GET | Infos de l'instance frontend | `{ instance: "frontend-2", address: "10.1.0.5", port: 8443 }` |
| `/health` | GET | Health check | `OK` |
| `/api` | GET | Traverse toute la stack (Frontend→App→Data) | Données de la couche Data |
| `/probe/app` | GET | Interroge l'App Layer via LB | `{ instance: "app-1", ... }` |
| `/probe/data` | GET | Interroge la Data Layer via LB | `{ instance: "data-2", ... }` |

#### **Application** (Ports 5000, 5001, 5002)

| Endpoint | Méthode | Description | Exemple de réponse |
|----------|---------|-------------|-------------------|
| `/whoami` | GET | Infos de l'instance app | `{ instance: "app-1", address: "10.2.0.4", port: 5000 }` |
| `/health` | GET | Health check | `OK` |
| `/api` | GET | Appelle la couche Data | Données de la couche Data |

#### **Data** (Ports 6000, 6001, 6002)

| Endpoint | Méthode | Description | Exemple de réponse |
|----------|---------|-------------|-------------------|
| `/db` | GET | Retourne des données simulées | `DATA-LAYER-1: OK` |
| `/whoami` | GET | Infos de l'instance data | `{ instance: "data-1", address: "10.3.0.4", port: 6000 }` |
| `/health` | GET | Health check | `OK` |

#### **Admin** (Port 7000)

| Endpoint | Méthode | Description | Exemple de réponse |
|----------|---------|-------------|-------------------|
| `/` | GET | Interface admin | Dashboard HTML |
| `/status` | GET | Inventaire complet | `{ frontend: [...], app: [...], data: [...] }` |
| `/probe` | GET | Teste tous les serveurs | Statut de chaque VM |

### Code source expliqué

#### **frontend1.js** (frontend-vm1, port 80)

```javascript
const express = require('express');
const http = require('http');
const app = express();

// Configuration
const APP_LAYER = 'http://10.2.0.250:5000'; // IP du Load Balancer app-lb
const PORT = 80;

// Servir la page HTML
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index1.html')));

// Endpoint pour identifier la VM
app.get('/whoami', (req, res) => {
  res.json({ 
    instance: 'frontend-1',           // Nom de l'instance
    address: req.socket.localAddress, // IP privée
    port: PORT 
  });
});

// Proxy vers la couche App (traverse toute la stack)
app.get('/api', (_, res) => {
  http.get(APP_LAYER + '/api', r => r.pipe(res))  // Appelle app-lb
    .on('error', () => res.status(502).send('Bad Gateway'));
});

// Health check pour le Load Balancer
app.get('/health', (_, res) => res.send('OK'));

// Démarrage du serveur
app.listen(PORT, '10.1.0.4', () => {
  console.log(`Frontend-1 listening on http://10.1.0.4:${PORT}`);
});
```

**Points clés** :
- `APP_LAYER = 'http://10.2.0.250:5000'` : Appelle le **Load Balancer app-lb** (pas directement une VM)
- `app.listen(PORT, '10.1.0.4')` : Écoute sur l'IP privée statique de la VM
- `/api` : Utilise `http.get()` pour appeler la couche suivante

#### **app1.js** (app-vm1, port 5000)

```javascript
const express = require('express');
const http = require('http');
const app = express();

// Configuration
const DATA_LAYER = 'http://10.3.0.250:6000'; // IP du Load Balancer data-lb
const PORT = 5000;

// Endpoint qui appelle la couche Data
app.get('/api', (_, res) => {
  http.get(DATA_LAYER + '/db', r => r.pipe(res))  // Appelle data-lb
    .on('error', () => res.status(502).send('Bad Gateway'));
});

// Identification
app.get('/whoami', (req, res) => {
  res.json({ instance: 'app-1', address: req.socket.localAddress, port: PORT });
});

// Health check
app.get('/health', (_, res) => res.send('OK'));

// Écoute sur toutes les interfaces (0.0.0.0 pour compatibilité)
app.listen(PORT, '0.0.0.0', () => {
  console.log(`APP1 listening on http://0.0.0.0:${PORT}`);
});
```

**Points clés** :
- `DATA_LAYER = 'http://10.3.0.250:6000'` : Appelle le **Load Balancer data-lb**
- `app.listen(PORT, '0.0.0.0')` : Écoute sur toutes les interfaces réseau

#### **data1.js** (data-vm1, port 6000)

```javascript
const express = require('express');
const app = express();
const PORT = 6000;

// Endpoint principal : simule une base de données
app.get('/db', (_, res) => {
  res.send('DATA-LAYER-1: OK');  // Réponse simple
});

// Identification
app.get('/whoami', (req, res) => {
  res.json({ instance: 'data-1', address: req.socket.localAddress, port: PORT });
});

// Health check
app.get('/health', (_, res) => res.send('OK'));

// Démarrage
app.listen(PORT, '0.0.0.0', () => {
  console.log(`DATA1 listening on http://0.0.0.0:${PORT}`);
});
```

**Points clés** :
- `/db` : Endpoint final de la chaîne, retourne une réponse directe
- Pas d'appel HTTP vers d'autres services

---

## 🧪 Tests et validation

### 1. Tester le Load Balancer frontend (depuis Internet)

```bash
# Récupérer l'IP publique
PUBLIC_IP=$(az network public-ip show \
  --resource-group rg-loadbalancer \
  --name lb-pub-ip-in \
  --query ipAddress \
  --output tsv)

echo "IP publique : $PUBLIC_IP"

# Tester le port 80 (frontend-vm1)
curl http://$PUBLIC_IP:80/whoami

# Tester le port 8443 (frontend-vm2 et frontend-vm2_b, round-robin)
for i in {1..10}; do
  curl -s http://$PUBLIC_IP:8443/whoami | grep -o '"instance":"[^"]*"'
done
# Devrait alterner entre frontend-2 et frontend-2_b
```

### 2. Tester la chaîne complète (Frontend → App → Data)

```bash
# Appeler /api depuis le frontend (traverse toute la stack)
curl http://$PUBLIC_IP:8443/api

# Répéter pour voir la distribution round-robin
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://$PUBLIC_IP:8443/api
  sleep 1
done
```

### 3. Tester les Load Balancers internes (depuis une VM)

Les Load Balancers internes (app-lb, data-lb) ne sont pas accessibles depuis Internet. Il faut se connecter à une VM pour les tester.

```bash
# Se connecter à frontend-vm1 via Bastion
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name frontend-vm1 -g rg-loadbalancer --query id -o tsv)

# Une fois connecté, tester app-lb
curl http://10.2.0.250:5000/whoami
curl http://10.2.0.250:5001/whoami

# Tester la distribution round-robin sur app-lb
for i in {1..10}; do
  curl -s http://10.2.0.250:5000/whoami | grep -o '"instance":"[^"]*"'
done
# Devrait alterner entre app-1 et app-2

# Tester data-lb
curl http://10.3.0.250:6000/whoami
curl http://10.3.0.250:6001/whoami

# Tester la distribution round-robin sur data-lb
for i in {1..10}; do
  curl -s http://10.3.0.250:6000/db
done
# Devrait alterner entre DATA-LAYER-1 et DATA-LAYER-2
```

### 4. Tester les health checks

```bash
# Vérifier que toutes les VMs répondent aux health checks
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

### 5. Vérifier les backend pools sur Azure

```bash
# Voir les VMs dans le backend pool frontend
az network lb address-pool show \
  --resource-group rg-loadbalancer \
  --lb-name front-lb \
  --name front-backpool \
  --query backendIPConfigurations[].id -o table

# Voir les health probes
az network lb probe list \
  --resource-group rg-loadbalancer \
  --lb-name app-lb \
  --output table

# Vérifier qu'une VM est healthy
az network nic show \
  --resource-group rg-loadbalancer \
  --name app-nic-vm1 \
  --query "ipConfigurations[0].loadBalancerBackendAddressPools" \
  --output json
```

### 6. Simuler une panne pour tester la haute disponibilité

```bash
# Se connecter à app-vm1
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Arrêter le serveur Node.js
pkill -f node

# Depuis une autre VM, tester app-lb
for i in {1..20}; do
  curl -s http://10.2.0.250:5000/whoami | grep -o '"instance":"[^"]*"'
done
# Ne devrait retourner QUE "app-2" car app-1 est down

# Redémarrer le serveur sur app-vm1
cd /home/cloud
nohup node server.js > server.log 2>&1 &

# Attendre 10-15 secondes (temps de détection du health probe)
# Retester : les deux instances devraient réapparaître
```

### 7. Tester l'interface admin (monitoring)

```bash
# Se connecter à admin-vm
az network bastion ssh \
  --name bastion \
  --resource-group rg-loadbalancer \
  --auth-type password \
  --username cloud \
  --target-resource-id $(az vm show --name admin-vm -g rg-loadbalancer --query id -o tsv)

# Vérifier que le serveur admin tourne
curl http://localhost:7000/status

# Tester le probe complet (teste toutes les VMs)
curl http://10.3.0.10:7000/probe | jq .
```

**Exemple de sortie `/probe`** :
```json
{
  "frontend": [
    { "host": "10.1.0.4:80", "whoami": { "ok": true, "body": "{\"instance\":\"frontend-1\"}" }, "health": { "ok": true } },
    { "host": "10.1.0.5:8443", "whoami": { "ok": true, "body": "{\"instance\":\"frontend-2\"}" }, "health": { "ok": true } }
  ],
  "app": [
    { "host": "10.2.0.4:5000", "whoami": { "ok": true }, "health": { "ok": true } },
    { "host": "10.2.0.5:5001", "whoami": { "ok": true }, "health": { "ok": true } }
  ],
  "data": [
    { "host": "10.3.0.4:6000", "whoami": { "ok": true }, "health": { "ok": true } },
    { "host": "10.3.0.5:6001", "whoami": { "ok": true }, "health": { "ok": true } }
  ]
}
```

---

## 🐛 Troubleshooting

### Problème 1 : "Connection refused" lors du test d'un endpoint

**Symptômes** :
```bash
curl http://10.2.0.5:5001/health
curl: (7) Failed to connect to 10.2.0.5 port 5001: Connection refused
```

**Causes possibles** :
1. Le serveur Node.js n'est pas démarré
2. Cloud-init n'a pas encore terminé
3. Le serveur écoute sur la mauvaise IP

**Solutions** :
```bash
# Se connecter à la VM
az network bastion ssh --name bastion --resource-group rg-loadbalancer \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm2 -g rg-loadbalancer --query id -o tsv)

# Vérifier les logs cloud-init
sudo tail -100 /var/log/cloud-init-output.log | grep -i error

# Vérifier que Node.js est installé
node --version
npm --version

# Vérifier que le serveur tourne
ps aux | grep node

# Si pas de processus, vérifier le fichier
ls -la /home/cloud/server.js

# Démarrer manuellement
cd /home/cloud
node server.js &

# Tester localement
curl http://localhost:5001/health
```

### Problème 2 : Health probe échoue sur Azure

**Symptômes** : Dans le portail Azure, la VM est marquée "Unhealthy"

**Solutions** :
```bash
# Vérifier la configuration du health probe
az network lb probe show \
  --resource-group rg-loadbalancer \
  --lb-name app-lb \
  --name ProbeApp2

# Vérifier que l'endpoint /health répond localement
ssh vers la VM
curl http://localhost:5001/health
# Doit retourner "OK"

# Vérifier que le port est bien ouvert
sudo ss -tlnp | grep 5001

# Vérifier les NSG (ne devraient pas bloquer)
az network nsg rule list \
  --resource-group rg-loadbalancer \
  --nsg-name app-nsg \
  --output table
```

### Problème 3 : Round-robin ne fonctionne pas

**Symptômes** : Toutes les requêtes vont vers la même VM

**Causes** :
- Une seule VM est healthy
- Session affinity activée (pas le cas dans ce projet)

**Solutions** :
```bash
# Vérifier que toutes les VMs sont healthy
for i in {1..10}; do
  curl -s http://10.2.0.250:5000/whoami
  sleep 0.5
done

# Vérifier le backend pool
az network lb address-pool show \
  --resource-group rg-loadbalancer \
  --lb-name app-lb \
  --name app-backpool

# Vérifier que les NICs sont bien dans le backend pool
az network nic show --name app-nic-vm1 -g rg-loadbalancer \
  --query "ipConfigurations[0].loadBalancerBackendAddressPools"
```

### Problème 4 : "Cannot find module 'express'"

**Symptômes** :
```
Error: Cannot find module 'express'
```

**Solutions** :
```bash
# Se connecter à la VM
# Installer express manuellement
cd /home/cloud
npm init -y
npm install express

# Redémarrer le serveur
pkill -f node
nohup node server.js > server.log 2>&1 &
```

### Problème 5 : Cloud-init n'a pas cloné le dépôt GitHub

**Symptômes** :
```
cp: cannot stat '/tmp/lab/app/app1.js': No such file or directory
```

**Causes** : Problème réseau, NAT Gateway pas encore prêt

**Solutions** :
```bash
# Cloner manuellement
git clone https://github.com/CallmeVRM/azure-LB02.git /tmp/lab

# Copier les fichiers
cp /tmp/lab/app/app1.js /home/cloud/server.js

# Installer les dépendances
cd /home/cloud
npm init -y
npm install express

# Démarrer le serveur
node server.js &
```

### Problème 6 : Impossible de se connecter via Bastion

**Symptômes** :
```
Target subscription/resource group/resources could not be found.
```

**Solutions** :
```bash
# Vérifier que Bastion est déployé
az network bastion show --name bastion --resource-group rg-loadbalancer

# Vérifier que la VM existe
az vm show --name app-vm1 --resource-group rg-loadbalancer

# Alternative : utiliser serial console dans le portail Azure
# Portail → VM → Serial Console
```

### Problème 7 : Timeout sur les requêtes entre couches

**Symptômes** : frontend → app fonctionne, mais app → data timeout

**Causes** : Peering VNet manquant, NSG trop restrictif

**Solutions** :
```bash
# Vérifier le peering
az network vnet peering list --resource-group rg-loadbalancer --vnet-name app-vnet --output table

# Tester la connectivité depuis app-vm1
ssh vers app-vm1
ping 10.3.0.250  # IP de data-lb
curl http://10.3.0.250:6000/health

# Vérifier les routes réseau
ip route show
```

---

## 🎓 Exercices pratiques

### Exercice 1 : Ajouter une nouvelle VM frontend

**Objectif** : Comprendre comment ajouter un backend à un Load Balancer existant

**Étapes** :
1. Créer une nouvelle NIC avec IP statique 10.1.0.22
2. Créer une nouvelle VM frontend-vm3
3. Ajouter la NIC au backend pool `front-backpool`
4. Tester la distribution sur 4 VMs

<details>
<summary>Solution (cliquer pour afficher)</summary>

```bash
# 1. Créer la NIC
az network nic create -g rg-loadbalancer \
  -n front-nic-vm3 \
  --vnet-name front-vnet \
  --subnet vm-subnet \
  --private-ip-address 10.1.0.22

# 2. Ajouter au backend pool
az network nic ip-config address-pool add \
  -g rg-loadbalancer \
  --lb-name front-lb \
  --address-pool front-backpool \
  --nic-name front-nic-vm3 \
  --ip-config-name ipconfig1

# 3. Créer la VM (copier frontend1.js et modifier instance: 'frontend-3')
az vm create -g rg-loadbalancer \
  -n frontend-vm3 \
  --nics front-nic-vm3 \
  --image Ubuntu2404 \
  --admin-username cloud \
  --admin-password 'Motdepassefort123!' \
  --custom-data @frontend/cloud-init-frontend1.yaml \
  --size Standard_B1s

# 4. Tester
for i in {1..20}; do curl -s http://$PUBLIC_IP:80/whoami; done
```
</details>

### Exercice 2 : Modifier le code pour afficher un message personnalisé

**Objectif** : Comprendre comment modifier et redéployer le code

**Étapes** :
1. Modifier `data1.js` pour retourner `{ message: "Hello from Data Layer!", instance: "data-1" }`
2. Redéployer sur data-vm1
3. Tester l'endpoint `/db`

<details>
<summary>Solution</summary>

```bash
# 1. Modifier localement
nano data/data1.js
# Changer :
# app.get('/db', (_, res) => res.json({ message: "Hello from Data Layer!", instance: "data-1" }));

# 2. Commiter et pusher
git add data/data1.js
git commit -m "Update data1.js message"
git push

# 3. Se connecter à data-vm1
az network bastion ssh --name bastion -g rg-loadbalancer \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name data-vm1 -g rg-loadbalancer --query id -o tsv)

# 4. Mettre à jour le code
cd /tmp
git clone https://github.com/CallmeVRM/azure-LB02.git
cp azure-LB02/data/data1.js /home/cloud/server.js

# 5. Redémarrer
pkill -f node
cd /home/cloud
nohup node server.js > server.log 2>&1 &

# 6. Tester
curl http://localhost:6000/db
```
</details>

### Exercice 3 : Configurer un nouveau port sur le Load Balancer

**Objectif** : Ajouter un nouveau health probe et une règle de load balancing

**Étapes** :
1. Ajouter un health probe sur port 5002 pour app-lb
2. Créer une règle de load balancing pour port 5002
3. Vérifier que app-vm2_b reçoit du trafic sur ce port

<details>
<summary>Solution</summary>

```bash
# 1. Créer le health probe
az network lb probe create \
  -g rg-loadbalancer \
  --lb-name app-lb \
  --name ProbeApp3 \
  --protocol http \
  --path /health \
  --port 5002

# 2. Créer la règle
az network lb rule create \
  -g rg-loadbalancer \
  --lb-name app-lb \
  --name App5002 \
  --protocol TCP \
  --frontend-port 5002 \
  --backend-port 5002 \
  --frontend-ip-name app-front-ip \
  --backend-pool-name app-backpool \
  --probe-name ProbeApp3

# 3. Tester
ssh vers frontend-vm1
curl http://10.2.0.250:5002/whoami
# Devrait retourner app-2_b
```
</details>

### Exercice 4 : Surveiller les métriques Azure

**Objectif** : Utiliser Azure Monitor pour voir les métriques du Load Balancer

**Étapes** :
1. Aller dans le portail Azure → Load Balancer → Metrics
2. Afficher le graphique "Data Path Availability" (disponibilité)
3. Afficher "Health Probe Status" (statut des sondes)
4. Simuler une panne et observer les métriques

### Exercice 5 : Créer un endpoint de stress test

**Objectif** : Comprendre comment le Load Balancer gère la charge

**Étapes** :
1. Ajouter un endpoint `/heavy` dans `app1.js` qui simule un traitement lourd
2. Utiliser Apache Bench pour envoyer 1000 requêtes
3. Observer la distribution entre app-vm1 et app-vm2

<details>
<summary>Solution</summary>

```javascript
// Dans app1.js, ajouter :
app.get('/heavy', (req, res) => {
  // Simuler un traitement lourd (calculs intensifs)
  let sum = 0;
  for (let i = 0; i < 10000000; i++) {
    sum += Math.sqrt(i);
  }
  res.json({ 
    instance: 'app-1', 
    result: sum,
    timestamp: new Date().toISOString()
  });
});
```

```bash
# Installer Apache Bench
sudo apt-get install apache2-utils

# Lancer le test (1000 requêtes, 50 concurrentes)
ab -n 1000 -c 50 http://10.2.0.250:5000/heavy

# Observer les résultats
```
</details>

---

## 📚 Ressources complémentaires

### Documentation officielle Azure

- [Azure Load Balancer - Vue d'ensemble](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview)
- [VNet Peering](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Azure Bastion](https://learn.microsoft.com/azure/bastion/bastion-overview)
- [Cloud-Init sur Azure](https://learn.microsoft.com/azure/virtual-machines/linux/using-cloud-init)
- [NSG (Network Security Groups)](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)

### Tutoriels recommandés

- [Microsoft Learn - Load Balancer](https://learn.microsoft.com/training/modules/improve-app-scalability-resiliency-with-load-balancer/)
- [Azure Architecture Center - Load Balancing](https://learn.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview)

### Outils utiles

- **Azure CLI** : https://learn.microsoft.com/cli/azure/
- **Azure Portal** : https://portal.azure.com
- **VS Code + Azure Extension** : Pour éditer les fichiers et déployer
- **Postman** : Pour tester les APIs

---

## 🧹 Nettoyage (Supprimer toutes les ressources)

**Important** : Les ressources Azure coûtent de l'argent. N'oubliez pas de les supprimer après vos tests !

```bash
# Supprimer TOUT le resource group (supprime toutes les ressources d'un coup)
az group delete --name rg-loadbalancer --yes --no-wait

# Vérifier que la suppression est en cours
az group show --name rg-loadbalancer --query properties.provisioningState

# Lister tous les resource groups
az group list --output table
```

**Alternative** : Supprimer uniquement les VMs pour économiser de l'argent, mais garder l'infra réseau

```bash
# Lister toutes les VMs
az vm list -g rg-loadbalancer --query "[].name" -o tsv

# Supprimer toutes les VMs
for vm in $(az vm list -g rg-loadbalancer --query "[].name" -o tsv); do
  az vm delete -g rg-loadbalancer -n $vm --yes --no-wait
done

# Les Load Balancers, VNets, NSG restent et ne coûtent presque rien
```

---

## 📝 Checklist de validation finale

Avant de considérer le lab comme terminé, vérifiez :

- [ ] Toutes les 9 VMs sont déployées et running
- [ ] Les 3 Load Balancers (front-lb, app-lb, data-lb) fonctionnent
- [ ] Les health probes sont tous "healthy" dans le portail Azure
- [ ] Le test `/whoami` retourne bien le nom de chaque instance
- [ ] Le round-robin fonctionne (alterner entre VMs)
- [ ] La chaîne complète Frontend → App → Data fonctionne
- [ ] Azure Bastion permet de se connecter aux VMs
- [ ] Les logs cloud-init ne montrent pas d'erreurs
- [ ] L'interface admin (port 7000) fonctionne
- [ ] La simulation de panne (pkill node) déclenche le failover

---

## 🎯 Objectifs pédagogiques atteints

Après avoir complété ce lab, vous devriez être capable de :

✅ Expliquer le rôle d'un Load Balancer  
✅ Créer un Load Balancer Public et Internal dans Azure  
✅ Configurer des Backend Pools avec plusieurs VMs  
✅ Mettre en place des Health Probes  
✅ Configurer le VNet Peering pour connecter des réseaux  
✅ Déployer des VMs avec Cloud-Init  
✅ Débugger des problèmes réseau dans Azure  
✅ Utiliser Azure Bastion pour la connexion SSH  
✅ Comprendre le round-robin et la haute disponibilité  
✅ Tester et valider une architecture multi-tiers

---

## 💡 Cas d'usage réels

Ce type d'architecture est utilisé dans :

- **E-commerce** : Répartir le trafic entre plusieurs serveurs web
- **APIs REST** : Distribuer les requêtes API sur plusieurs instances
- **Micro-services** : Isoler frontend, backend, base de données
- **High Availability** : Assurer la continuité même si un serveur tombe
- **Scalabilité** : Ajouter/retirer des serveurs selon la charge

---

**Auteur** : VRM  
**Projet** : Azure Load Balancer Lab  
**Repository** : [github.com/CallmeVRM/azure-LB02](https://github.com/CallmeVRM/azure-LB02)  
**Licence** : MIT  
**Date** : 2025

---

## 📧 Support

Pour toute question ou problème :
- Ouvrir une **issue** sur GitHub
- Consulter les logs cloud-init : `sudo tail -f /var/log/cloud-init-output.log`
- Vérifier la documentation Azure officielle

**Bon apprentissage ! 🚀**
