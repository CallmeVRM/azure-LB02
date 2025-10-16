# Test Load Balancer - Frontend 2_b

## 🎯 Objectif

Cette configuration ajoute une **troisième VM frontend** (frontend-vm2_b) pour tester le Load Balancer frontend. Elle permet de vérifier que :
- Le Load Balancer distribue correctement le trafic entre les 3 frontends
- Chaque frontend peut appeler l'app layer via le Load Balancer app
- La détection automatique de changement fonctionne

## 📊 Architecture

```
                  Load Balancer Frontend (Public IP)
                            |
        +-------------------+-------------------+
        |                   |                   |
   frontend-vm1      frontend-vm2        frontend-vm2_b
   (10.1.0.4:80)    (10.1.0.5:8443)    (10.1.0.21:8443)
   index1.html       index2.html        index2_b.html
        |                   |                   |
        +-------------------+-------------------+
                            |
                   App Load Balancer (10.2.0.250)
                            |
                    +-------+-------+
                    |               |
                app-vm1         app-vm2
              (10.2.0.4:5000) (10.2.0.5:5001)
                    |               |
                    +-------+-------+
                            |
                   Data Load Balancer (10.3.0.250)
                            |
                    +-------+-------+
                    |               |
                data-vm1        data-vm2
              (10.3.0.4:6000) (10.3.0.5:6001)
```

## 🔧 Configuration

### Frontend 2_b
- **VM Name**: frontend-vm2_b
- **NIC**: front-nic-vm2_b
- **Private IP**: 10.1.0.21
- **Port**: 8443
- **Instance Name**: frontend-2_b
- **Fichiers**:
  - `frontend/frontend2_b.js` - Serveur Node.js
  - `frontend/index2_b.html` - Interface utilisateur
  - `frontend/cloud-init-frontend2_b.yaml` - Configuration cloud-init

### Points clés
- ✅ Écoute sur **0.0.0.0:8443**
- ✅ Pointe vers **App Layer LB** (10.2.0.250:5001)
- ✅ Pointe vers **Data Layer LB** (10.3.0.250:6001)
- ✅ Timeouts de 5 secondes sur toutes les requêtes
- ✅ Endpoint `/metrics` pour monitoring
- ✅ Attachée au backend pool du Load Balancer frontend

## 🚀 Déploiement

### Via infra.sh (automatique)
Le fichier `infra.sh` contient déjà la création de cette VM :

```bash
# Exécuter le script complet
./infra.sh
```

### Création manuelle de la VM
Si vous voulez créer uniquement cette VM :

```bash
# Variables
rg="votre-resource-group"
loc="francecentral"
adminUser="cloud"
adminPass="VotreMotDePasse123!"

# Créer la NIC
az network nic create -g $rg -l $loc -n front-nic-vm2_b \
    --vnet-name front-vnet --subnet vm-subnet \
    --private-ip-address 10.1.0.21

# Attacher au backend pool du LB
az network nic ip-config address-pool add -g $rg --lb-name front-lb \
    --address-pool front-backpool --nic-name front-nic-vm2_b \
    --ip-config-name ipconfig1

# Créer la VM
az vm create -g $rg -l $loc -n frontend-vm2_b \
    --nics front-nic-vm2_b --image Ubuntu2404 \
    --admin-username $adminUser --admin-password $adminPass \
    --custom-data @frontend/cloud-init-frontend2_b.yaml \
    --size Standard_B1s
```

## 🧪 Tests

### 1. Vérifier que la VM est créée
```bash
az vm list -g $rg --query "[?name=='frontend-vm2_b'].{Name:name,Status:provisioningState}" -o table
```

### 2. Se connecter à la VM
```bash
az network bastion ssh --name bastion --resource-group $rg \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name frontend-vm2_b -g $rg --query id -o tsv)
```

### 3. Vérifier que le serveur tourne
```bash
# Sur la VM
ps aux | grep node
ss -tlnp | grep 8443
curl -s http://localhost:8443/whoami | jq .
```

Expected output:
```json
{
  "instance": "frontend-2_b",
  "address": "10.1.0.21",
  "port": 8443,
  "timestamp": "2025-10-13T..."
}
```

### 4. Tester depuis le réseau
```bash
# Depuis une autre VM ou machine qui peut joindre 10.1.0.21
curl -s http://10.1.0.21:8443/whoami | jq .
curl -s http://10.1.0.21:8443/health
curl -s http://10.1.0.21:8443/probe/app | jq .
curl -s http://10.1.0.21:8443/probe/data | jq .
```

### 5. Tester le Load Balancer
```bash
# Obtenir l'IP publique du LB
frontLbIp=$(az network public-ip show -g $rg -n front-lb-pip --query ipAddress -o tsv)

# Faire plusieurs requêtes pour voir la répartition
for i in {1..10}; do
  curl -s http://$frontLbIp:8443/whoami | jq -r '.instance'
  sleep 1
done
```

Expected output (distribution entre les 3 frontends):
```
frontend-1
frontend-2
frontend-2_b
frontend-1
frontend-2_b
frontend-2
...
```

### 6. Tester la chaîne complète
```bash
# Appel qui traverse toutes les couches
curl -s http://$frontLbIp:8443/api
```

Expected: Réponse de la couche data (peut varier selon le backend actif)

## 📊 Monitoring

### Endpoints disponibles
- `GET /` - Interface utilisateur
- `GET /whoami` - Informations sur l'instance frontend
- `GET /health` - Health check (retourne "OK")
- `GET /api` - Proxy vers app layer (traverse toute la stack)
- `GET /probe/app` - Informations sur l'app via LB
- `GET /probe/data` - Informations sur la data via LB
- `GET /metrics` - Métriques de monitoring

### Vérifier les métriques
```bash
curl -s http://10.1.0.21:8443/metrics | jq .
```

Output:
```json
{
  "instance": "frontend-2_b",
  "port": 8443,
  "uptime": 1234.56,
  "memory": {
    "rss": 45678912,
    "heapTotal": 12345678,
    "heapUsed": 8901234
  },
  "timestamp": "2025-10-13T..."
}
```

## 🔍 Vérification du Load Balancer

### Vérifier la configuration du backend pool
```bash
az network lb address-pool show -g $rg --lb-name front-lb -n front-backpool \
  --query "backendIpConfigurations[].{Name:id}" -o table
```

Expected: 3 NICs (front-nic-vm1, front-nic-vm2, front-nic-vm2_b)

### Vérifier les health probes
```bash
az network lb probe list -g $rg --lb-name front-lb -o table
```

### Voir les règles de load balancing
```bash
az network lb rule list -g $rg --lb-name front-lb -o table
```

## 🐛 Troubleshooting

### Le serveur ne démarre pas
```bash
# Sur la VM, vérifier les logs cloud-init
sudo tail -f /var/log/cloud-init-output.log

# Redémarrer manuellement
cd /home/cloud/frontend
node server.js
```

### Le LB ne route pas vers cette VM
```bash
# Vérifier que la NIC est bien dans le backend pool
az network nic ip-config address-pool list -g $rg --nic-name front-nic-vm2_b \
  --ip-config-name ipconfig1 -o table

# Vérifier le health probe
az network lb show -g $rg -n front-lb \
  --query "probes[].{Name:name,Protocol:protocol,Port:port,Path:requestPath}" -o table
```

### Erreurs 502 Bad Gateway
```bash
# Vérifier que l'app layer est accessible
curl -s http://10.2.0.250:5001/whoami

# Vérifier les timeouts dans le code
grep REQUEST_TIMEOUT /home/cloud/frontend/server.js
```

## 📝 Différences avec frontend-vm2

| Paramètre | frontend-vm2 | frontend-vm2_b |
|-----------|--------------|----------------|
| IP Privée | 10.1.0.5 | 10.1.0.21 |
| Port | 8443 | 8443 |
| Fichier JS | frontend2.js | frontend2_b.js |
| Fichier HTML | index2.html | index2_b.html |
| Instance Name | frontend-2 | frontend-2_b |
| App Target | 10.2.0.250:5001 | 10.2.0.250:5001 |
| Data Target | 10.3.0.250:6001 | 10.3.0.250:6001 |

## ✅ Checklist de validation

- [ ] VM créée et running
- [ ] NIC attachée au backend pool du LB
- [ ] Serveur Node.js écoute sur port 8443
- [ ] `/whoami` retourne "frontend-2_b"
- [ ] `/health` retourne "OK"
- [ ] `/probe/app` retourne les infos de l'app layer
- [ ] `/probe/data` retourne les infos de la data layer
- [ ] Interface web accessible via l'IP publique du LB
- [ ] Le LB distribue entre les 3 frontends

## 🎯 Prochaines étapes

1. **Tester la répartition de charge** : Faire beaucoup de requêtes et vérifier la distribution
2. **Simuler une panne** : Arrêter une VM et vérifier que le LB redirige automatiquement
3. **Ajouter des métriques** : Implémenter Prometheus pour suivre la distribution
4. **Configurer des alertes** : Azure Monitor pour détecter les pannes

---

**Note** : Cette VM est identique aux autres frontends en termes de fonctionnalités, elle sert uniquement à augmenter le nombre de backends pour tester le Load Balancer.
