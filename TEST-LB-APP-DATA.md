# Test des Load Balancers - VMs supplémentaires

## 📋 Vue d'ensemble

Ce document décrit les VMs supplémentaires créées pour tester les Load Balancers sur les couches App et Data.

### VMs de test créées

| VM | Layer | IP Privée | Port | Instance Name | Fichiers |
|--- |-------|-----------|------|---------------|----------|
| **frontend-vm2_b** | Frontend | 10.1.0.21 | 8443 | frontend-2_b | `frontend2_b.js`, `index2_b.html` |
| **app-vm2_b** | App | 10.2.0.21 | 5002 | app-2_b | `app2_b.js` |
| **data-vm2_b** | Data | 10.3.0.21 | 6002 | data-2_b | `data2_b.js` |

## 🎯 Objectif

Ces VMs permettent de tester que les Load Balancers Azure distribuent correctement le trafic entre **3 backends** au lieu de 2 :

- **Frontend LB** : distribue entre frontend-vm1, frontend-vm2, frontend-vm2_b
- **App LB** : distribue entre app-vm1, app-vm2, app-vm2_b  
- **Data LB** : distribue entre data-vm1, data-vm2, data-vm2_b

## 📊 Architecture complète

```
                  Frontend Load Balancer (Public)
                            |
        +-------------------+-------------------+
        |                   |                   |
   frontend-vm1      frontend-vm2        frontend-vm2_b
   10.1.0.4:80      10.1.0.5:8443       10.1.0.21:8443
        |                   |                   |
        +-------------------+-------------------+
                            |
                   App Load Balancer (10.2.0.250)
                            |
        +-------------------+-------------------+
        |                   |                   |
     app-vm1            app-vm2            app-vm2_b
   10.2.0.4:5000     10.2.0.5:5001      10.2.0.21:5002
        |                   |                   |
        +-------------------+-------------------+
                            |
                   Data Load Balancer (10.3.0.250)
                            |
        +-------------------+-------------------+
        |                   |                   |
    data-vm1           data-vm2           data-vm2_b
  10.3.0.4:6000     10.3.0.5:6001     10.3.0.21:6002
```

## 🔧 Configuration des nouveaux serveurs

### App-2_b (`app/app2_b.js`)
```javascript
PORT: 5002
DATA_LAYER: http://10.3.0.250:6002  // Pointe vers le port 6002 du data LB
Endpoints:
  - /whoami   → Retourne { instance: 'app-2_b', address, port }
  - /health   → Retourne 'OK' (pour health probes)
  - /api      → Proxy vers DATA_LAYER/db
  - /metrics  → Métriques de monitoring
```

### Data-2_b (`data/data2_b.js`)
```javascript
PORT: 6002
Endpoints:
  - /db       → Retourne { message: 'DATA-LAYER-2_B: OK', instance, timestamp }
  - /whoami   → Retourne { instance: 'data-2_b', address, port }
  - /health   → Retourne 'OK'
  - /metrics  → Métriques avec compteur de requêtes
```

## 🚀 Déploiement

### Option 1 : Via infra.sh (à ajouter manuellement)

Ajoutez à la fin de `infra.sh` :

```bash
# ============================================================
# VMs supplémentaires pour test de répartition de charge
# ============================================================

# App VM 2_b
az network nic create -g $rg -l $loc -n app-nic-vm2_b \
    --vnet-name app-vnet --subnet vm-subnet --private-ip-address 10.2.0.21

az network nic ip-config address-pool add -g $rg --lb-name app-lb \
    --address-pool app-backpool --nic-name app-nic-vm2_b --ip-config-name ipconfig1

sleep $((RANDOM % 7 + 2))

az vm create -g $rg -l $loc -n app-vm2_b \
    --nics app-nic-vm2_b --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @app/cloud-init-app2_b.yaml --size Standard_B1s

sleep $((RANDOM % 7 + 2))

# Data VM 2_b
az network nic create -g $rg -l $loc -n data-nic-vm2_b \
    --vnet-name data-vnet --subnet vm-subnet --private-ip-address 10.3.0.21

az network nic ip-config address-pool add -g $rg --lb-name data-lb \
    --address-pool data-backpool --nic-name data-nic-vm2_b --ip-config-name ipconfig1

sleep $((RANDOM % 7 + 2))

az vm create -g $rg -l $loc -n data-vm2_b \
    --nics data-nic-vm2_b --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @data/cloud-init-data2_b.yaml --size Standard_B1s
```

### Ajout des health probes et règles LB

Dans la section App Load Balancer, ajoutez :

```bash
# Ajouter après les autres probes app
az network lb probe create -g $rg --lb-name app-lb \
    --name ProbeApp3 --protocol http --path /health --port 5002

# Ajouter après les autres règles app
az network lb rule create -g $rg --lb-name app-lb --name App5002 \
    --protocol TCP --frontend-port 5002 --backend-port 5002 \
    --frontend-ip-name app-front-ip --backend-pool-name app-backpool --probe-name ProbeApp3
```

Dans la section Data Load Balancer, ajoutez :

```bash
# Ajouter après les autres probes data
az network lb probe create -g $rg --lb-name data-lb \
    --name Probe6002 --protocol http --path /health --port 6002

# Ajouter après les autres règles data
az network lb rule create -g $rg --lb-name data-lb --name Data6002 \
    --protocol TCP --frontend-port 6002 --backend-port 6002 \
    --frontend-ip-name data-front-ip --backend-pool-name data-backpool --probe-name Probe6002
```

### Option 2 : Déploiement manuel

```bash
# Variables
rg="votre-resource-group"
loc="francecentral"
adminUser="cloud"
adminPass="VotreMotDePasse123!"

# App VM 2_b
az network nic create -g $rg -l $loc -n app-nic-vm2_b \
    --vnet-name app-vnet --subnet vm-subnet --private-ip-address 10.2.0.21

az network nic ip-config address-pool add -g $rg --lb-name app-lb \
    --address-pool app-backpool --nic-name app-nic-vm2_b --ip-config-name ipconfig1

az vm create -g $rg -l $loc -n app-vm2_b \
    --nics app-nic-vm2_b --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @app/cloud-init-app2_b.yaml --size Standard_B1s

# Data VM 2_b
az network nic create -g $rg -l $loc -n data-nic-vm2_b \
    --vnet-name data-vnet --subnet vm-subnet --private-ip-address 10.3.0.21

az network nic ip-config address-pool add -g $rg --lb-name data-lb \
    --address-pool data-backpool --nic-name data-nic-vm2_b --ip-config-name ipconfig1

az vm create -g $rg -l $loc -n data-vm2_b \
    --nics data-nic-vm2_b --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @data/cloud-init-data2_b.yaml --size Standard_B1s
```

## 🧪 Tests

### 1. Vérifier que les VMs sont créées

```bash
az vm list -g $rg --query "[?contains(name, '_b')].{Name:name,Status:provisioningState}" -o table
```

Expected:
```
Name             Status
---------------  ---------
frontend-vm2_b   Succeeded
app-vm2_b        Succeeded
data-vm2_b       Succeeded
```

### 2. Tester les endpoints individuellement

```bash
# App-2_b
curl -s http://10.2.0.21:5002/whoami | jq .
curl -s http://10.2.0.21:5002/health

# Data-2_b
curl -s http://10.3.0.21:6002/whoami | jq .
curl -s http://10.3.0.21:6002/db | jq .
curl -s http://10.3.0.21:6002/health
```

### 3. Tester via les Load Balancers

```bash
# Test App LB (doit distribuer entre les 3 app VMs)
for i in {1..15}; do
  curl -s http://10.2.0.250:5002/whoami | jq -r '.instance'
  sleep 1
done
```

Expected output (distribution sur 3 backends):
```
app-1
app-2
app-2_b
app-1
app-2_b
app-2
...
```

```bash
# Test Data LB (doit distribuer entre les 3 data VMs)
for i in {1..15}; do
  curl -s http://10.3.0.250:6002/whoami | jq -r '.instance'
  sleep 1
done
```

Expected output:
```
data-1
data-2
data-2_b
data-1
data-2_b
...
```

### 4. Tester la chaîne complète

Depuis frontend-vm2_b, testez que l'appel traverse toutes les couches :

```bash
curl -s http://10.1.0.21:8443/api
```

Le frontend appelle app LB → app LB choisit un app backend → app backend appelle data LB → data LB choisit un data backend

### 5. Vérifier les backend pools

```bash
# App backend pool
az network lb address-pool show -g $rg --lb-name app-lb -n app-backpool \
  --query "length(backendIpConfigurations)" -o tsv
# Expected: 3

# Data backend pool
az network lb address-pool show -g $rg --lb-name data-lb -n data-backpool \
  --query "length(backendIpConfigurations)" -o tsv
# Expected: 3
```

### 6. Vérifier les health probes

```bash
az network lb probe list -g $rg --lb-name app-lb -o table
az network lb probe list -g $rg --lb-name data-lb -o table
```

Vous devriez voir les probes pour les ports 5000, 5001, 5002 (app) et 6000, 6001, 6002 (data).

## 📊 Monitoring

### Vérifier les métriques

```bash
# App-2_b
curl -s http://10.2.0.21:5002/metrics | jq .

# Data-2_b
curl -s http://10.3.0.21:6002/metrics | jq .
```

### Se connecter aux VMs

```bash
# App-vm2_b
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm2_b -g $rg --query id -o tsv)

# Data-vm2_b
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name data-vm2_b -g $rg --query id -o tsv)
```

### Vérifier les logs cloud-init

```bash
sudo tail -f /var/log/cloud-init-output.log
```

### Vérifier que le serveur tourne

```bash
ps aux | grep node
ss -tlnp | grep 5002  # pour app
ss -tlnp | grep 6002  # pour data
```

## 🐛 Troubleshooting

### Le serveur ne démarre pas

```bash
# Sur la VM
cd /home/cloud/app  # ou /home/cloud/data
cat server.js  # Vérifier que le fichier existe
node server.js  # Démarrer manuellement
```

### La VM n'apparaît pas dans le backend pool

```bash
# Vérifier la NIC
az network nic show -g $rg -n app-nic-vm2_b \
  --query "ipConfigurations[0].loadBalancerBackendAddressPools" -o json

# Ajouter manuellement si nécessaire
az network nic ip-config address-pool add -g $rg --lb-name app-lb \
    --address-pool app-backpool --nic-name app-nic-vm2_b --ip-config-name ipconfig1
```

### Health probe échoue

```bash
# Vérifier que le endpoint /health répond
curl -s http://10.2.0.21:5002/health

# Vérifier la config du probe
az network lb probe show -g $rg --lb-name app-lb -n ProbeApp3
```

## ✅ Checklist de validation

- [ ] app-vm2_b créée et running
- [ ] data-vm2_b créée et running
- [ ] NICs attachées aux backend pools
- [ ] Health probes configurés (ports 5002 et 6002)
- [ ] Règles LB créées pour les nouveaux ports
- [ ] Serveurs Node.js tournent sur les VMs
- [ ] `/whoami` retourne les bons noms d'instance
- [ ] `/health` retourne 'OK'
- [ ] Les LB distribuent entre les 3 backends
- [ ] La chaîne complète fonctionne (frontend → app → data)

## 🎯 Résultats attendus

Avec 3 backends par couche, vous devriez observer :
- **Distribution uniforme** du trafic (environ 33% par backend)
- **Failover automatique** si un backend tombe
- **Health checks** qui détectent les backends unhealthy
- **Pas de downtime** lors de l'ajout/suppression de backends

## 📝 Notes

1. **Ports** : Chaque VM utilise un port différent (5000, 5001, 5002 pour app ; 6000, 6001, 6002 pour data) car elles partagent potentiellement le même LB frontend.

2. **IPs privées** : Toutes les VMs `_b` utilisent l'IP `.21` dans leur subnet respectif pour faciliter l'identification.

3. **Cloud-init** : Les fichiers sont automatiquement clonés depuis GitHub lors du démarrage de la VM - assurez-vous que les fichiers `app2_b.js` et `data2_b.js` sont committés !

4. **Commit GitHub** : N'oubliez pas de commit et push les nouveaux fichiers avant de déployer :
   ```bash
   git add app/app2_b.js app/cloud-init-app2_b.yaml
   git add data/data2_b.js data/cloud-init-data2_b.yaml
   git commit -m "Add app2_b and data2_b test VMs"
   git push
   ```

---

**Créé le** : 13 octobre 2025  
**Pour le projet** : Azure Load Balancer POC
