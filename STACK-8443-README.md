# Stack 8443 - Documentation Complète

## 🎯 Vue d'ensemble

Cette stack (port 8443) représente une architecture 3-tiers complète avec load balancing Azure :

```
Frontend-2 (port 8443)
    ↓
App-LB (10.2.0.250:5001)
    ↓
App-2 (port 5001)
    ↓
Data-LB (10.3.0.250:6001)
    ↓
Data-2 (port 6001)
```

## ✨ Fonctionnalités

### Interface Utilisateur Moderne
- **Design moderne** avec cards et dégradés
- **Animations** lors des changements d'instance (détection automatique)
- **Actualisation automatique** toutes les 3 secondes
- **Health checks visuels** avec badges colorés
- **Responsive design** adapté à tous les écrans

### Architecture Robuste
- ✅ **Timeouts** sur toutes les requêtes HTTP (5 secondes)
- ✅ **Gestion d'erreurs** complète avec logging
- ✅ **Métriques** disponibles sur chaque couche
- ✅ **Écoute sur 0.0.0.0** pour compatibilité maximale
- ✅ **Détection automatique** des changements de backend via Load Balancer

## 📦 Composants

### Frontend-2 (`frontend/frontend2.js`)
- Port : **8443**
- Sert l'interface HTML moderne
- Expose les endpoints :
  - `GET /` - Interface utilisateur
  - `GET /whoami` - Informations sur l'instance frontend
  - `GET /health` - Health check
  - `GET /api` - Proxy vers la couche App
  - `GET /probe/app` - Récupère les infos de l'app via LB
  - `GET /probe/data` - Récupère les infos de la data via LB
  - `GET /metrics` - Métriques de monitoring

### App-2 (`app/app2.js`)
- Port : **5001**
- Couche applicative intermédiaire
- Expose les endpoints :
  - `GET /whoami` - Informations sur l'instance app
  - `GET /health` - Health check
  - `GET /api` - Proxy vers la couche Data
  - `GET /metrics` - Métriques de monitoring

### Data-2 (`data/data2.js`)
- Port : **6001**
- Couche de données (backend)
- Expose les endpoints :
  - `GET /db` - Données principales
  - `GET /whoami` - Informations sur l'instance data
  - `GET /health` - Health check
  - `GET /metrics` - Métriques de monitoring

## 🚀 Déploiement

### Option 1 : Déploiement automatique (Cloud-Init)
Les fichiers cloud-init sont déjà configurés pour automatiser le déploiement lors de la création des VMs :
- `frontend/cloud-init-frontend2.yaml`
- `app/cloud-init-app2.yaml`
- `data/cloud-init-data2.yaml`

### Option 2 : Déploiement manuel

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

## 🔍 Tests et Validation

### Tester les endpoints directement

```bash
# Frontend
curl -s http://10.1.0.5:8443/whoami | jq .
curl -s http://10.1.0.5:8443/health
curl -s http://10.1.0.5:8443/metrics | jq .

# App (via Load Balancer)
curl -s http://10.2.0.250:5001/whoami | jq .
curl -s http://10.2.0.250:5001/health

# Data (via Load Balancer)
curl -s http://10.3.0.250:6001/whoami | jq .
curl -s http://10.3.0.250:6001/db | jq .
curl -s http://10.3.0.250:6001/health
```

### Tester les probes depuis le frontend

```bash
curl -s http://10.1.0.5:8443/probe/app | jq .
curl -s http://10.1.0.5:8443/probe/data | jq .
```

### Tester la chaîne complète

```bash
# Depuis le frontend, appeler l'API qui traverse toutes les couches
curl -s http://10.1.0.5:8443/api
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
curl -s http://10.1.0.5:8443/metrics | jq .
```

## 🎨 Améliorations Implémentées

### 1. Interface Utilisateur
- ✅ Design moderne avec gradient et cards
- ✅ Animations lors des changements d'instance
- ✅ Health checks visuels avec badges colorés
- ✅ Layout responsive (Grid CSS)
- ✅ Auto-refresh toutes les 3 secondes

### 2. Robustesse
- ✅ Timeouts sur toutes les requêtes HTTP (5 secondes)
- ✅ Gestion d'erreurs complète avec messages détaillés
- ✅ Logging structuré avec timestamps
- ✅ Pas de blocage sur erreurs réseau

### 3. Observabilité
- ✅ Endpoint `/metrics` sur chaque service
- ✅ Compteur de requêtes sur data layer
- ✅ Timestamps ISO sur toutes les réponses
- ✅ Logging console avec format structuré

### 4. Sécurité et Compatibilité
- ✅ Écoute sur 0.0.0.0 pour éviter les problèmes de binding
- ✅ Headers Content-Type corrects
- ✅ Gestion des CORS implicite (server-side probes)

## 🔧 Maintenance

### Redémarrer un service

```bash
# Trouver le processus
ps aux | grep node

# Tuer le processus
sudo pkill -f server.js

# Relancer
cd /home/cloud/[frontend|app|data]
nohup node server.js > server.log 2>&1 &
```

### Voir les logs

```bash
# Si lancé avec nohup
tail -f /home/cloud/[frontend|app|data]/server.log

# Sinon, voir les logs système
journalctl -u node --follow
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
  const range = ['10.2.0.4', '10.2.0.5', '10.2.0.6', '10.2.0.7'];
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
const backends = ['10.2.0.4:5001', '10.2.0.5:5001'];
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

## 🆘 Troubleshooting

### L'interface ne se met pas à jour
- Vérifier que le serveur frontend écoute sur 8443 : `ss -tlnp | grep 8443`
- Vérifier les logs : `journalctl -u frontend2 -f`
- Tester les probes manuellement : `curl http://10.1.0.5:8443/probe/app`

### Les health checks échouent
- Vérifier que les backends répondent : `curl http://10.2.0.250:5001/health`
- Vérifier la configuration du Load Balancer Azure
- Vérifier les NSG (Network Security Groups)

### Timeout sur les requêtes
- Augmenter le timeout dans le code (actuellement 5 secondes)
- Vérifier la latence réseau : `ping 10.2.0.250`
- Vérifier que les VMs ne sont pas surchargées : `top`

## 📚 Ressources

- [Express.js Documentation](https://expressjs.com/)
- [Azure Load Balancer](https://docs.microsoft.com/azure/load-balancer/)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)

---

**Auteur** : VRM  
**Date** : Octobre 2025  
**Version** : 2.0
