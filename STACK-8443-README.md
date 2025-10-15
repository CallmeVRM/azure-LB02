#  Documentation Complète Généré par Claude via copilot, ébauche à corriger...

## 🎯 Vue d'ensemble

Cette stack (port 8443) représente une architecture 3-tiers complète avec load balancing Azure. Le projet inclut maintenant des **VMs supplémentaires (_b)** pour tester la répartition de charge avec 3 backends au lieu de 2.

### Architecture de base (port 8443)

```
Frontend-2 / Frontend-2_b (port 8443)
    ↓
App-LB (10.2.0.250:5001/5002)
    ↓
App-2 / App-2_b (port 5001/5002)
    ↓
Data-LB (10.3.0.250:6001/6002)
    ↓
Data-2 / Data-2_b (port 6001/6002)
```

### Architecture complète avec Load Balancers

```
                  Frontend Load Balancer (Public IP)
                            |
        +-------------------+-------------------+
        |                   |                   |
   frontend-vm1      frontend-vm2        frontend-vm2_b
   10.1.0.10:80      10.1.0.20:8443       10.1.0.21:8443
        |                   |                   |
        +-------------------+-------------------+
                            |
                   App Load Balancer (10.2.0.250)
                            |
        +-------------------+-------------------+
        |                   |                   |
     app-vm1            app-vm2            app-vm2_b
   10.2.0.10:5000     10.2.0.20:5001      10.2.0.21:5002
        |                   |                   |
        +-------------------+-------------------+
                            |
                   Data Load Balancer (10.3.0.250)
                            |
        +-------------------+-------------------+
        |                   |                   |
    data-vm1           data-vm2           data-vm2_b
  10.3.0.10:6000     10.3.0.20:6001     10.3.0.21:6002
```

## ✨ Fonctionnalités


### Architecture :
- ✅ **Timeouts** sur toutes les requêtes HTTP (5 secondes)
- ✅ **Gestion d'erreurs** complète avec logging
- ✅ **Métriques** disponibles sur chaque couche
- ✅ **Écoute sur 0.0.0.0** pour compatibilité maximale
- ✅ **Détection automatique** des changements de backend via Load Balancer

## 📦 Composants

### Couche Frontend

#### Frontend-2 (`frontend/frontend2.js`)
- **VM** : frontend-vm2
- **IP Privée** : 10.1.0.20
- **Port** : 8443
- **Instance** : `frontend-2`
- **Cible App** : http://10.2.0.250:5001
- **Fichiers** : `frontend2.js`, `index2.html`, `cloud-init-frontend2.yaml`

#### Frontend-2_b (`frontend/frontend2_b.js`)
- **VM** : frontend-vm2_b
- **IP Privée** : 10.1.0.21
- **Port** : 8443
- **Instance** : `frontend-2_b`
- **Cible App** : http://10.2.0.250:5001
- **Fichiers** : `frontend2_b.js`, `index2_b.html`, `cloud-init-frontend2_b.yaml`

**Endpoints frontends** :
- `GET /` - Interface utilisateur moderne avec cards et animations
- `GET /whoami` - Retourne `{ instance, address, port, timestamp }`
- `GET /health` - Retourne `OK` (pour health probes)
- `GET /api` - Proxy vers la couche App (traverse toute la stack)
- `GET /probe/app` - Récupère les infos de l'app via LB (JSON)
- `GET /probe/app-health` - Health check de l'app layer
- `GET /probe/data` - Récupère les infos de la data via LB (JSON)
- `GET /probe/data-health` - Health check de la data layer
- `GET /metrics` - Métriques de monitoring (uptime, memory)

**Caractéristiques** :
- ✅ Écoute sur `0.0.0.0:8443`
- ✅ Timeouts de 5 secondes sur toutes les requêtes HTTP
- ✅ Gestion d'erreurs robuste avec logs structurés
- ✅ Interface web avec auto-refresh toutes les 3 secondes
- ✅ Animations visuelles lors des changements d'instance

### Couche Application

#### App-2 (`app/app2.js`)
- **VM** : app-vm2
- **IP Privée** : 10.2.0.20
- **Port** : 5001
- **Instance** : `app-2`
- **Cible Data** : http://10.3.0.250:6001
- **Fichiers** : `app2.js`, `cloud-init-app2.yaml`

#### App-2_b (`app/app2_b.js`)
- **VM** : app-vm2_b
- **IP Privée** : 10.2.0.21
- **Port** : 5002
- **Instance** : `app-2_b`
- **Cible Data** : http://10.3.0.250:6002
- **Fichiers** : `app2_b.js`, `cloud-init-app2_b.yaml`

**Endpoints apps** :
- `GET /whoami` - Retourne `{ instance, address, port, timestamp }`
- `GET /health` - Retourne `OK` (pour health probes)
- `GET /api` - Proxy vers la couche Data (appelle `/db`)
- `GET /metrics` - Métriques de monitoring

**Caractéristiques** :
- ✅ Écoute sur `0.0.0.0`
- ✅ Timeouts de 5 secondes sur les appels data
- ✅ Gestion d'erreurs avec fallback JSON
- ✅ Logging avec timestamps ISO

### Couche Data

#### Data-2 (`data/data2.js`)
- **VM** : data-vm2
- **IP Privée** : 10.3.0.20
- **Port** : 6001
- **Instance** : `data-2`
- **Fichiers** : `data2.js`, `cloud-init-data2.yaml`

#### Data-2_b (`data/data2_b.js`)
- **VM** : data-vm2_b
- **IP Privée** : 10.3.0.21
- **Port** : 6002
- **Instance** : `data-2_b`
- **Fichiers** : `data2_b.js`, `cloud-init-data2_b.yaml`

**Endpoints data** :
- `GET /db` - Retourne `{ message, instance, timestamp }` (données principales)
- `GET /whoami` - Retourne `{ instance, address, port, timestamp }`
- `GET /health` - Retourne `OK` (pour health probes)
- `GET /metrics` - Métriques avec compteur de requêtes

**Caractéristiques** :
- ✅ Écoute sur `0.0.0.0`
- ✅ Compteur de requêtes pour monitoring
- ✅ Logging de toutes les requêtes
- ✅ Réponses JSON structurées

## 🔗 Flux de données

### Appel complet (Frontend → App → Data)

```
1. Browser → Frontend LB (Public IP:8443)
2. Frontend LB → frontend-vm2 ou frontend-vm2_b (round-robin)
3. Frontend → GET /api
4. Frontend → App LB (10.2.0.250:5001 ou 5002)
5. App LB → app-vm2 ou app-vm2_b (round-robin)
6. App → GET /api → proxy vers Data LB
7. App → Data LB (10.3.0.250:6001 ou 6002)
8. Data LB → data-vm2 ou data-vm2_b (round-robin)
9. Data → GET /db → retourne JSON
10. Réponse remonte la chaîne : Data → App → Frontend → Browser
```

### Probes serveur-side (pour éviter CORS)

```
Browser → GET /probe/app
Frontend → http://10.2.0.250:5001/whoami
App LB → app-vm2 ou app-vm2_b
Response JSON → Frontend → Browser
```

## 🚀 Déploiement

### Vue d'ensemble

Ce projet utilise **cloud-init** pour automatiser le déploiement. Chaque VM clone le dépôt GitHub, copie les fichiers nécessaires, installe les dépendances et démarre le serveur automatiquement.

> ⚠️ **Important** : Avant de déployer les VMs, assurez-vous que tous les fichiers sont **commités et pushés** sur GitHub, car cloud-init clone le repo au démarrage.

### Étape 1 : Commiter les fichiers sur GitHub

```bash
# Ajouter tous les nouveaux fichiers
git add frontend/frontend2*.js frontend/index2*.html frontend/cloud-init-frontend2*.yaml
git add app/app2*.js app/cloud-init-app2*.yaml
git add data/data2*.js data/cloud-init-data2*.yaml
git add STACK-8443-README.md TEST-LB-APP-DATA.md FRONTEND-2B-README.md

# Commiter
git commit -m "Add stack 8443 with test VMs (_b variants)"

# Pousser sur GitHub
git push origin main
```

### Étape 2 : Déploiement automatique (Cloud-Init)

Les fichiers cloud-init sont déjà configurés :
- VMs principales : `cloud-init-frontend2.yaml`, `cloud-init-app2.yaml`, `cloud-init-data2.yaml`
- VMs de test : `cloud-init-frontend2_b.yaml`, `cloud-init-app2_b.yaml`, `cloud-init-data2_b.yaml`

**Création des VMs avec cloud-init** :

```bash
# Frontend-VM2 (port 8443)
az vm create \
  --resource-group rg-loadbalancer \
  --name frontend-vm2 \
  --vnet-name vnet-main \
  --subnet subnet-frontend \
  --private-ip-address 10.1.0.20 \
  --public-ip-address pip-frontend-vm2 \
  --nsg nsg-frontend \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data frontend/cloud-init-frontend2.yaml

# Frontend-VM2_b (port 8443, VM de test)
az vm create \
  --resource-group rg-loadbalancer \
  --name frontend-vm2_b \
  --vnet-name vnet-main \
  --subnet subnet-frontend \
  --private-ip-address 10.1.0.21 \
  --public-ip-address pip-frontend-vm2-b \
  --nsg nsg-frontend \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data frontend/cloud-init-frontend2_b.yaml

# App-VM2 (port 5001)
az vm create \
  --resource-group rg-loadbalancer \
  --name app-vm2 \
  --vnet-name vnet-main \
  --subnet subnet-app \
  --private-ip-address 10.2.0.20 \
  --nsg nsg-app \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data app/cloud-init-app2.yaml

# App-VM2_b (port 5002, VM de test)
az vm create \
  --resource-group rg-loadbalancer \
  --name app-vm2_b \
  --vnet-name vnet-main \
  --subnet subnet-app \
  --private-ip-address 10.2.0.21 \
  --nsg nsg-app \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data app/cloud-init-app2_b.yaml

# Data-VM2 (port 6001)
az vm create \
  --resource-group rg-loadbalancer \
  --name data-vm2 \
  --vnet-name vnet-main \
  --subnet subnet-data \
  --private-ip-address 10.3.0.20 \
  --nsg nsg-data \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data data/cloud-init-data2.yaml

# Data-VM2_b (port 6002, VM de test)
az vm create \
  --resource-group rg-loadbalancer \
  --name data-vm2_b \
  --vnet-name vnet-main \
  --subnet subnet-data \
  --private-ip-address 10.3.0.21 \
  --nsg nsg-data \
  --image Ubuntu2204 \
  --size Standard_B1s \
  --custom-data data/cloud-init-data2_b.yaml
```

> 📘 **Note pour les VMs `_b`** : Vous devez également ajouter les règles de load balancer et health probes dans `infra.sh` pour les ports **5002** et **6002**. Voir `TEST-LB-APP-DATA.md` pour les détails.

### Étape 3 : Ajouter les VMs aux backend pools

```bash
# Frontend VMs → Frontend LB backend pool
az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name frontend-vm2VMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-frontend \
  --address-pool bepool-frontend

az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name frontend-vm2_bVMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-frontend \
  --address-pool bepool-frontend

# App VMs → App LB backend pool
az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name app-vm2VMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-app \
  --address-pool bepool-app

az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name app-vm2_bVMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-app \
  --address-pool bepool-app

# Data VMs → Data LB backend pool
az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name data-vm2VMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-data \
  --address-pool bepool-data

az network nic ip-config address-pool add \
  --resource-group rg-loadbalancer \
  --nic-name data-vm2_bVMNic \
  --ip-config-name ipconfig1 \
  --lb-name lb-data \
  --address-pool bepool-data
```

### Étape 4 : Vérification du déploiement

```bash
# Vérifier que cloud-init a terminé (peut prendre 2-3 minutes)
ssh cloud@<VM-IP> "sudo tail -f /var/log/cloud-init-output.log"

# Vérifier que le serveur est en cours d'exécution
ssh cloud@<VM-IP> "ps aux | grep node"

# Tester localement sur la VM
ssh cloud@<VM-IP> "curl http://localhost:<PORT>/health"
# Frontend: PORT=8443
# App-2: PORT=5001, App-2_b: PORT=5002
# Data-2: PORT=6001, Data-2_b: PORT=6002
```

### Option alternative : Déploiement manuel

Si vous devez déployer manuellement (troubleshooting ou développement local) :

#### Sur frontend-vm2
```bash
# Se connecter à la VM
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name frontend-vm2 -g $rg --query id -o tsv)

# Cloner le repo et installer
mkdir -p /home/cloud/frontend
cd /home/cloud/frontend
git clone https://github.com/CallmeVRM/azure-LB02 /tmp/lab
cp /tmp/lab/frontend/frontend2.js ./server.js
cp /tmp/lab/frontend/index2.html ./index2.html
npm init -y
npm install express

# Démarrer le serveur
node server.js
```

#### Sur frontend-vm2_b
```bash
# Même procédure que frontend-vm2, mais avec :
cp /tmp/lab/frontend/frontend2_b.js ./server.js
cp /tmp/lab/frontend/index2_b.html ./index2_b.html
```

#### Sur app-vm2
```bash
# Se connecter à la VM
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm2 -g $rg --query id -o tsv)

# Cloner le repo et installer
mkdir -p /home/cloud/app
cd /home/cloud/app
git clone https://github.com/CallmeVRM/azure-LB02 /tmp/lab
cp /tmp/lab/app/app2.js ./server.js
npm init -y
npm install express

# Démarrer le serveur
node server.js
```

#### Sur app-vm2_b
```bash
# Même procédure que app-vm2, mais avec :
cp /tmp/lab/app/app2_b.js ./server.js
```

#### Sur data-vm2
```bash
# Se connecter à la VM
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name data-vm2 -g $rg --query id -o tsv)

# Cloner le repo et installer
mkdir -p /home/cloud/data
cd /home/cloud/data
git clone https://github.com/CallmeVRM/azure-LB02 /tmp/lab
cp /tmp/lab/data/data2.js ./server.js
npm init -y
npm install express

# Démarrer le serveur
node server.js
```

#### Sur data-vm2_b
```bash
# Même procédure que data-vm2, mais avec :
cp /tmp/lab/data/data2_b.js ./server.js
```

## 🔍 Tests et Validation

### 1. Tester les endpoints directement (VMs individuelles)

#### Frontend VMs (port 8443)

```bash
# Frontend-VM2
curl -s http://10.1.0.20:8443/whoami | jq .
curl -s http://10.1.0.20:8443/health
curl -s http://10.1.0.20:8443/metrics | jq .

# Frontend-VM2_b
curl -s http://10.1.0.21:8443/whoami | jq .
curl -s http://10.1.0.21:8443/health
curl -s http://10.1.0.21:8443/metrics | jq .
```

#### App VMs (ports 5001, 5002)

```bash
# App-VM2 (port 5001)
curl -s http://10.2.0.20:5001/whoami | jq .
curl -s http://10.2.0.20:5001/health
curl -s http://10.2.0.20:5001/api | jq .

# App-VM2_b (port 5002)
curl -s http://10.2.0.21:5002/whoami | jq .
curl -s http://10.2.0.21:5002/health
curl -s http://10.2.0.21:5002/api | jq .
```

#### Data VMs (ports 6001, 6002)

```bash
# Data-VM2 (port 6001)
curl -s http://10.3.0.20:6001/whoami | jq .
curl -s http://10.3.0.20:6001/db | jq .
curl -s http://10.3.0.20:6001/health

# Data-VM2_b (port 6002)
curl -s http://10.3.0.21:6002/whoami | jq .
curl -s http://10.3.0.21:6002/db | jq .
curl -s http://10.3.0.21:6002/health
```

### 2. Tester les Load Balancers (distribution round-robin)

#### App Load Balancer (10.2.0.250)

```bash
# Port 5001 - Distribue vers app-vm1 et app-vm2
for i in {1..10}; do
  curl -s http://10.2.0.250:5001/whoami | jq -r '.instance'
done
# Devrait alterner entre app-1 et app-2

# Port 5002 - Devrait router vers app-vm2_b (si health probe configuré)
for i in {1..5}; do
  curl -s http://10.2.0.250:5002/whoami | jq -r '.instance'
done
# Devrait retourner app-2_b
```

#### Data Load Balancer (10.3.0.250)

```bash
# Port 6001 - Distribue vers data-vm1 et data-vm2
for i in {1..10}; do
  curl -s http://10.3.0.250:6001/whoami | jq -r '.instance'
done
# Devrait alterner entre data-1 et data-2

# Port 6002 - Devrait router vers data-vm2_b (si health probe configuré)
for i in {1..5}; do
  curl -s http://10.3.0.250:6002/whoami | jq -r '.instance'
done
# Devrait retourner data-2_b
```

### 3. Tester les probes depuis le frontend

Ces endpoints évitent les problèmes CORS en faisant les appels côté serveur :

```bash
# Probes vers App Layer
curl -s http://10.1.0.20:8443/probe/app | jq .
curl -s http://10.1.0.20:8443/probe/app-health

# Probes vers Data Layer
curl -s http://10.1.0.20:8443/probe/data | jq .
curl -s http://10.1.0.20:8443/probe/data-health
```

### 4. Tester la chaîne complète (Frontend → App → Data)

```bash
# Depuis le frontend, appeler l'API qui traverse toutes les couches
curl -s http://10.1.0.20:8443/api

# Répéter plusieurs fois pour voir la distribution du LB
for i in {1..10}; do
  echo "=== Requête $i ==="
  curl -s http://10.1.0.20:8443/api | jq .
  sleep 1
done
```

### 5. Tester l'interface web

```bash
# Ouvrir dans le navigateur (remplacer par l'IP publique du frontend LB)
open http://<FRONTEND_PUBLIC_IP>:8443

# L'interface devrait afficher :
# - Card Frontend avec nom d'instance (frontend-2 ou frontend-2_b) et IP
# - Card App avec nom d'instance (app-1 ou app-2) et IP
# - Card Data avec nom d'instance (data-1 ou data-2) et IP
# - Badges de statut verts si tout fonctionne
# - Auto-refresh toutes les 3 secondes avec animations
```

### 6. Tester la haute disponibilité

#### Simuler une panne de VM

```bash
# Arrêter le serveur Node.js sur app-vm2
az network bastion ssh --name bastion --resource-group $rg --auth-type password --username cloud --target-resource-id $(az vm show --name app-vm2 -g $rg --query id -o tsv)

cd ~/app
sudo pkill -f server.js


#Une fois les testes finis, Redémarrez le serveur node.
sudo nohup node server.js > server.log 2>&1 &

```

#### Vérifier les health probes

```bash
# Vérifier le statut des health probes sur le Load Balancer
az network lb probe show \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --name healthprobe-app-5001

# Voir les backends actifs
az network lb address-pool show \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --name bepool-app \
  --query backendIPConfigurations[].id -o table
```

### 7. Tests de charge (optionnel)

```bash
# Installer Apache Bench
sudo apt-get install apache2-utils

# Test de charge sur l'API complète (10000 requêtes, 100 concurrentes)
ab -n 10000 -c 100 http://10.2.0.250:5001/api

# Vérifier les métriques après le test
curl -s http://10.2.0.20:5001/metrics | jq .
curl -s http://10.3.0.20:6001/metrics | jq .
```

## 📊 Monitoring et Métriques

Chaque service expose un endpoint `/metrics` qui retourne :
- Nom de l'instance
- Port d'écoute
- Uptime du processus
- Utilisation mémoire
- Timestamp

Exemple :
```bash
curl -s http://10.1.0.20:8443/metrics | jq .
```

## 🔧 Maintenance

### Redémarrer un service

```bash
# Trouver le processus Node.js
ps aux | grep node

# Tuer un processus spécifique
sudo pkill -f frontend2.js  # ou app2.js, app2_b.js, data2.js, data2_b.js

# Relancer le service
cd /home/cloud
nohup node frontend2.js > frontend.log 2>&1 &
nohup node app2.js > app.log 2>&1 &
nohup node data2.js > data.log 2>&1 &
```

### Voir les logs

```bash
# Logs cloud-init (après déploiement initial)
sudo tail -f /var/log/cloud-init-output.log

# Logs applicatifs (si lancé avec nohup)
tail -f /home/cloud/frontend.log
tail -f /home/cloud/app.log
tail -f /home/cloud/data.log

# Logs système Node.js
journalctl -u node --follow
```

### Vérifier l'état des services

```bash
# Vérifier que le port écoute
sudo ss -tlnp | grep 8443  # Frontend
sudo ss -tlnp | grep 5001  # App-2
sudo ss -tlnp | grep 5002  # App-2_b
sudo ss -tlnp | grep 6001  # Data-2
sudo ss -tlnp | grep 6002  # Data-2_b

# Tester les endpoints localement
curl http://localhost:8443/health  # Frontend
curl http://localhost:5001/health  # App
curl http://localhost:6001/health  # Data

# Vérifier les processus Node.js
ps aux | grep node
```

### Mettre à jour le code

```bash
# Se connecter à la VM à condition qu'un NAT au niveau du loadbalancer soit configuré
ssh -p <port> cloud@lb-pub-ip-in

# Sauvegarder l'ancienne version
cp frontend2.js frontend2.js.bak

# Mettre à jour depuis GitHub
cd /tmp
git clone https://github.com/CallmeVRM/azure-LB02.git
cp azure-LB02/frontend/frontend2.js /home/cloud/

# Redémarrer le service
pkill -f frontend2.js
cd /home/cloud
nohup node frontend2.js > frontend.log 2>&1 &

# Vérifier que ça fonctionne
sleep 2
curl http://localhost:8443/health
```

## 🎯 Prochaines Améliorations Suggérées

### 1. Détection Automatique des Backends
Pour détecter automatiquement les nouveaux backends ajoutés au Load Balancer :

**Option A : Polling Azure API**
```javascript
// Interroger l'API Azure toutes les 30 secondes pour détecter les nouveaux backends
const { DefaultAzureCredential } = require('@azure/identity');
const { NetworkManagementClient } = require('@azure/arm-network');

async function getBackendPool() {
  const credential = new DefaultAzureCredential();
  const client = new NetworkManagementClient(credential, subscriptionId);
  const lb = await client.loadBalancers.get(resourceGroup, loadBalancerName);
  return lb.backendAddressPools[0].backendIPConfigurations;
}
```

**Option B : Health Probes Dynamiques**
```javascript
// Interroger tous les IPs d'un range et détecter les réponses
async function discoverBackends() {
  const range = ['10.2.0.10', '10.2.0.20', '10.2.0.6', '10.2.0.7'];
  const active = [];
  
  for (const ip of range) {
    try {
      await httpGetWithTimeout(`http://${ip}:5001/health`, 2000);
      active.push(ip);
    } catch (e) {
      // Pas actif
    }
  }
  return active;
}
```

**Option C : Service Discovery (Recommandé pour production)**
- Utiliser **Azure Service Bus** ou **Redis** comme registre de services
- Chaque backend s'enregistre au démarrage
- Frontend/App interrogent le registre pour connaître les backends actifs

### 2. Persistance avec systemd

Créer des services systemd pour auto-restart :

```ini
# /etc/systemd/system/frontend2.service
[Unit]
Description=Frontend-2 Node Service
After=network.target

[Service]
Type=simple
User=cloud
WorkingDirectory=/home/cloud/frontend
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Activer :
```bash
sudo systemctl enable frontend2
sudo systemctl start frontend2
sudo systemctl status frontend2
```

### 3. Monitoring avec Prometheus

Ajouter des métriques Prometheus :
```javascript
const promClient = require('prom-client');
const register = new promClient.Registry();

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status']
});

register.registerMetric(httpRequestDuration);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### 4. Load Balancing Intelligent

Implémenter un round-robin côté client pour distribuer entre plusieurs backends :
```javascript
const backends = ['10.2.0.10:5001', '10.2.0.20:5001'];
let currentIndex = 0;

function getNextBackend() {
  const backend = backends[currentIndex];
  currentIndex = (currentIndex + 1) % backends.length;
  return backend;
}
```

### 5. Circuit Breaker Pattern

Éviter les cascades d'erreurs avec un circuit breaker :
```javascript
class CircuitBreaker {
  constructor(threshold = 5, timeout = 60000) {
    this.failures = 0;
    this.threshold = threshold;
    this.timeout = timeout;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
  }

  async call(fn) {
    if (this.state === 'OPEN') {
      throw new Error('Circuit breaker is OPEN');
    }
    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (err) {
      this.onFailure();
      throw err;
    }
  }

  onSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }

  onFailure() {
    this.failures++;
    if (this.failures >= this.threshold) {
      this.state = 'OPEN';
      setTimeout(() => {
        this.state = 'HALF_OPEN';
        this.failures = 0;
      }, this.timeout);
    }
  }
}
```

## 📝 Notes Importantes

1. **Load Balancer Health Probes** : Assurez-vous que les health probes Azure sont configurés pour interroger `/health` sur chaque backend

2. **Sécurité** : En production, ajoutez :
   - HTTPS/TLS
   - Authentification
   - Rate limiting
   - WAF (Web Application Firewall)

3. **Performance** : Pour de meilleures performances :
   - Utilisez PM2 ou cluster mode de Node.js
   - Ajoutez du caching (Redis)
   - Utilisez HTTP/2

4. **Backup** : Configurez des snapshots réguliers des VMs ou utilisez Azure Backup

## 📋 Tableau récapitulatif des VMs

| Layer | VM | IP Privée | Port | Instance | Fichiers | Cloud-Init |
|-------|-----|-----------|------|----------|----------|------------|
| **Frontend** | frontend-vm2 | 10.1.0.20 | 8443 | `frontend-2` | frontend2.js, index2.html | cloud-init-frontend2.yaml |
| **Frontend** | frontend-vm2_b | 10.1.0.21 | 8443 | `frontend-2_b` | frontend2_b.js, index2_b.html | cloud-init-frontend2_b.yaml |
| **App** | app-vm2 | 10.2.0.20 | 5001 | `app-2` | app2.js | cloud-init-app2.yaml |
| **App** | app-vm2_b | 10.2.0.21 | 5002 | `app-2_b` | app2_b.js | cloud-init-app2_b.yaml |
| **Data** | data-vm2 | 10.3.0.20 | 6001 | `data-2` | data2.js | cloud-init-data2.yaml |
| **Data** | data-vm2_b | 10.3.0.21 | 6002 | `data-2_b` | data2_b.js | cloud-init-data2_b.yaml |

### Load Balancers

| LB | IP Interne | Ports | Backend Pool | Health Probe |
|----|------------|-------|--------------|--------------|
| **lb-frontend** | Public IP | 80, 8443 | frontend-vm1, vm2, vm2_b | /health |
| **lb-app** | 10.2.0.250 | 5000, 5001, 5002* | app-vm1, vm2, vm2_b* | /health |
| **lb-data** | 10.3.0.250 | 6000, 6001, 6002* | data-vm1, vm2, vm2_b* | /health |

> *Note : Les ports 5002 et 6002 doivent être ajoutés manuellement dans `infra.sh` pour les VMs `_b`.

## 🆘 Troubleshooting

### 1. L'interface web ne se met pas à jour

**Symptômes** : L'interface affiche "Loading..." ou ne rafraîchit pas les données

**Solutions** :
```bash
# Vérifier que le serveur frontend écoute sur le port 8443
ssh cloud@10.1.0.20
sudo ss -tlnp | grep 8443

# Tester les probes manuellement
curl http://10.1.0.20:8443/probe/app
curl http://10.1.0.20:8443/probe/data

# Vérifier les logs du frontend
tail -f /home/cloud/frontend.log

# Redémarrer le service si nécessaire
pkill -f frontend2.js
nohup node /home/cloud/frontend2.js > /home/cloud/frontend.log 2>&1 &
```

### 2. Les health checks Azure échouent

**Symptômes** : Les VMs sont marquées "Unhealthy" dans le backend pool

**Solutions** :
```bash
# Vérifier que l'endpoint /health répond localement
ssh cloud@10.2.0.20
curl http://localhost:5001/health
# Devrait retourner "OK"

# Vérifier que le port est accessible depuis une autre VM
# Depuis frontend-vm2
curl http://10.2.0.20:5001/health

# Vérifier la configuration du health probe Azure
az network lb probe show \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --name healthprobe-app-5001

# Vérifier les NSG (Network Security Groups)
az network nsg rule list \
  --resource-group rg-loadbalancer \
  --nsg-name nsg-app \
  --output table
```

### 3. Timeout sur les requêtes (5 secondes)

**Symptômes** : Erreurs "Error: timeout" dans les logs ou l'interface

**Solutions** :
```bash
# Vérifier la latence réseau
ping 10.2.0.250
ping 10.3.0.250

# Tester manuellement la chaîne complète
time curl http://10.1.0.20:8443/api

# Vérifier la charge CPU/RAM des VMs
ssh cloud@10.2.0.20
top
# Si CPU > 80%, considérer un redimensionnement de VM

# Augmenter le timeout dans le code si nécessaire (actuellement 5000ms)
# Dans frontend2.js, app2.js, app2_b.js : modifier httpGetWithTimeout
```

### 4. Cloud-init n'a pas démarré le serveur

**Symptômes** : VM créée mais serveur Node.js non actif

**Solutions** :
```bash
# Vérifier les logs cloud-init
ssh cloud@<VM-IP>
sudo tail -100 /var/log/cloud-init-output.log

# Chercher des erreurs spécifiques
sudo cat /var/log/cloud-init-output.log | grep -i error

# Erreurs courantes :
# - "cannot stat frontend2_b.js" → Fichiers non commités sur GitHub
# - "npm ERR!" → Problème d'installation de dépendances
# - "Address already in use" → Port déjà occupé

# Redémarrer manuellement si nécessaire
cd /home/cloud
git clone https://github.com/CallmeVRM/azure-LB02.git
cp azure-LB02/app/app2.js ./
npm init -y
npm install express
nohup node app2.js > app.log 2>&1 &
```

### 5. Load Balancer ne distribue pas les requêtes

**Symptômes** : Toutes les requêtes vont vers la même VM

**Solutions** :
```bash
# Tester la distribution LB
for i in {1..20}; do
  curl -s http://10.2.0.250:5001/whoami | jq -r '.instance'
done
# Devrait alterner entre app-1 et app-2

# Vérifier le backend pool
az network lb address-pool show \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --name bepool-app \
  --query backendIPConfigurations[].id -o table

# Vérifier que les VMs sont "Healthy"
az network nic show-effective-route-table \
  --resource-group rg-loadbalancer \
  --name app-vm2VMNic \
  --output table

# Vérifier la règle de load balancing
az network lb rule show \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --name rule-app-5001
```

### 6. VMs `_b` ne reçoivent pas de trafic

**Symptômes** : app-vm2_b ou data-vm2_b ne répondent jamais

**Solutions** :
```bash
# Vérifier que les health probes pour les ports 5002/6002 existent
az network lb probe list \
  --resource-group rg-loadbalancer \
  --lb-name lb-app \
  --output table

# Si absents, les ajouter dans infra.sh :
# az network lb probe create \
#   --resource-group rg-loadbalancer \
#   --lb-name lb-app \
#   --name healthprobe-app-5002 \
#   --protocol tcp \
#   --port 5002 \
#   --interval 5 \
#   --threshold 2

# Créer également les règles de load balancing pour les ports 5002/6002
# Voir TEST-LB-APP-DATA.md pour les commandes complètes
```

### 7. Erreur "Cannot find module 'express'"

**Symptômes** : Erreur au démarrage du serveur Node.js

**Solutions** :
```bash
# Se connecter à la VM
ssh cloud@<VM-IP>

# Installer express manuellement
cd /home/cloud
npm init -y
npm install express

# Redémarrer le serveur
nohup node app2.js > app.log 2>&1 &
```

## � Structure des fichiers du projet

```
azure-LB02/
├── frontend/
│   ├── frontend2.js           # Serveur frontend principal (port 8443)
│   ├── frontend2_b.js          # Serveur frontend test (port 8443)
│   ├── index2.html             # Interface web moderne (frontend-2)
│   ├── index2_b.html           # Interface web test (frontend-2_b)
│   ├── cloud-init-frontend2.yaml    # Déploiement automatique frontend-2
│   └── cloud-init-frontend2_b.yaml  # Déploiement automatique frontend-2_b
├── app/
│   ├── app2.js                 # Serveur app principal (port 5001)
│   ├── app2_b.js               # Serveur app test (port 5002)
│   ├── cloud-init-app2.yaml   # Déploiement automatique app-2
│   └── cloud-init-app2_b.yaml # Déploiement automatique app-2_b
├── data/
│   ├── data2.js                # Serveur data principal (port 6001)
│   ├── data2_b.js              # Serveur data test (port 6002)
│   ├── cloud-init-data2.yaml  # Déploiement automatique data-2
│   └── cloud-init-data2_b.yaml # Déploiement automatique data-2_b
├── STACK-8443-README.md        # Documentation complète (ce fichier)
├── TEST-LB-APP-DATA.md         # Guide de test pour les VMs _b
├── FRONTEND-2B-README.md       # Guide spécifique frontend-vm2_b
└── infra.sh                    # Script de déploiement infrastructure Azure
```

## 🔗 Liens vers documentation complémentaire

- **[TEST-LB-APP-DATA.md](./TEST-LB-APP-DATA.md)** : Guide détaillé pour déployer et tester les VMs `_b` (app-vm2_b, data-vm2_b)
- **[FRONTEND-2B-README.md](./FRONTEND-2B-README.md)** : Documentation spécifique pour frontend-vm2_b
- **[infra.sh](./infra.sh)** : Script Bash pour créer toute l'infrastructure Azure (VNet, Subnets, NSG, Load Balancers, Health Probes)

## �📚 Ressources externes

- [Express.js Documentation](https://expressjs.com/) - Framework web Node.js
- [Azure Load Balancer Documentation](https://docs.microsoft.com/azure/load-balancer/) - Service de load balancing Azure
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices) - Guide des bonnes pratiques Node.js
- [Azure Cloud-Init Guide](https://docs.microsoft.com/azure/virtual-machines/linux/using-cloud-init) - Automatisation du provisioning VM
- [MDN - CSS Grid](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Grid_Layout) - Layout utilisé dans l'interface web

## 🎓 Concepts Azure couverts

- ✅ **Azure Load Balancer** (Public et Internal)
- ✅ **Backend Address Pools** avec plusieurs VMs
- ✅ **Health Probes** sur endpoint `/health`
- ✅ **Load Balancing Rules** avec round-robin
- ✅ **Network Security Groups (NSG)** avec règles de trafic
- ✅ **Azure Virtual Network** avec subnets segmentés
- ✅ **Cloud-Init** pour provisioning automatique
- ✅ **Static Private IP addressing**

## 🚀 Commandes rapides (Quick Reference)

### Tests rapides

```bash
# Tester frontend
curl http://10.1.0.20:8443/whoami

# Tester app via LB
curl http://10.2.0.250:5001/whoami

# Tester data via LB
curl http://10.3.0.250:6001/whoami

# Tester chaîne complète
curl http://10.1.0.20:8443/api
```

### Vérifications rapides

```bash
# Voir les processus Node.js
ps aux | grep node

# Voir les ports en écoute
sudo ss -tlnp | grep node

# Tester health checks
curl http://localhost:8443/health
curl http://localhost:5001/health
curl http://localhost:6001/health
```

### Redémarrage rapide

```bash
# Redémarrer tous les services

cd /home/cloud/dossier
sudo pkill -f server.js
nohup node server.js > server.log 2>&1 &
nohup node app2.js > app.log 2>&1 &
nohup node data2.js > data.log 2>&1 &
```

---

**Auteur** : VRM  
**Projet** : Azure Load Balancer Lab - Stack 8443  
**Repository** : [github.com/CallmeVRM/azure-LB02](https://github.com/CallmeVRM/azure-LB02)  
**Date** : 2025  
**Version** : 2.0 (avec VMs de test _b)

---

## ✨ Changelog

### Version 2.0 (Actuelle)
- ✅ Ajout des VMs de test `_b` (frontend-vm2_b, app-vm2_b, data-vm2_b)
- ✅ Interface web moderne avec cards, gradients et animations
- ✅ Timeouts de 5 secondes sur toutes les requêtes HTTP
- ✅ Endpoints `/metrics` pour monitoring
- ✅ Cloud-init pour déploiement automatique
- ✅ Documentation complète (STACK-8443, TEST-LB-APP-DATA, FRONTEND-2B)
- ✅ Support multi-backend avec ports alternatifs (5002, 6002)

### Version 1.0 (Initiale)
- Déploiement basique frontend-vm2, app-vm2, data-vm2
- Interface HTML simple
- Scripts Node.js avec Express
