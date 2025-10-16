# Gestion des Services Systemd 🚀

> **Objectif** : Comprendre comment les services Node.js démarrent automatiquement après un redémarrage de VM

---

## 📋 Vue d'ensemble

Avec la nouvelle configuration, chaque serveur Node.js (Frontend, App, Data, Admin) est géré par un **service systemd**. Cela signifie :

✅ Le serveur **démarre automatiquement** au redémarrage de la VM  
✅ Le serveur **redémarre automatiquement** s'il crash  
✅ Les logs sont centralisées dans **journalctl**  
✅ **Plus besoin de node &** après chaque redémarrage !

---

## 📁 Services créés

### Couche Frontend

| VM | Service | Port | Commande |
|-------|---------|------|----------|
| frontend-vm1 | `frontend1.service` | 80 | `/usr/bin/node /home/cloud/frontend/server.js` |
| frontend-vm2 | `frontend2.service` | 8443 | `/usr/bin/node /home/cloud/frontend/server.js` |
| frontend-vm2_b | `frontend2.service` | 8443 | `/usr/bin/node /home/cloud/frontend/server.js` |

### Couche Application

| VM | Service | Port | Commande |
|-------|---------|------|----------|
| app-vm1 | `app1.service` | 5000 | `/usr/bin/node /home/cloud/app/server.js` |
| app-vm2 | `app2.service` | 5001 | `/usr/bin/node /home/cloud/app/server.js` |
| app-vm2_b | `app2_b.service` | 5002 | `/usr/bin/node /home/cloud/app/server.js` |

### Couche Data

| VM | Service | Port | Commande |
|-------|---------|------|----------|
| data-vm1 | `data1.service` | 6000 | `/usr/bin/node /home/cloud/data/server.js` |
| data-vm2 | `data2.service` | 6001 | `/usr/bin/node /home/cloud/data/server.js` |
| data-vm2_b | `data2_b.service` | 6002 | `/usr/bin/node /home/cloud/data/server.js` |

### Admin

| VM | Service | Port | Commande |
|-------|---------|------|----------|
| admin-vm | `admin.service` | 7000 | `/usr/bin/node /home/cloud/admin/server.js` |

---

## 🔧 Commandes de gestion des services

### Vérifier l'état d'un service

```bash
# Vérifier que le service est actif
systemctl status app1.service

# Exemple de sortie :
# ● app1.service - App-1 Node.js Server (Port 5000)
#      Loaded: loaded (/etc/systemd/system/app1.service; enabled; preset: enabled)
#      Active: active (running) since Wed 2025-10-16 14:35:22 UTC; 2min 30s ago
#    Main PID: 1234 (node)
#      Tasks: 12 (limit: 1024)
#     Memory: 45.2M
```

### Redémarrer un service

```bash
# Redémarrer le service app1
sudo systemctl restart app1.service

# Ou redémarrer tous les services frontend
sudo systemctl restart frontend1.service frontend2.service

# Redémarrer tous les services data
sudo systemctl restart data1.service data2.service data2_b.service
```

### Arrêter/Démarrer manuellement

```bash
# Arrêter le service
sudo systemctl stop app1.service

# Démarrer le service
sudo systemctl start app1.service

# Désactiver au démarrage (mais garder actif maintenant)
sudo systemctl disable app1.service

# Réactiver au démarrage
sudo systemctl enable app1.service
```

### Voir les logs en temps réel

```bash
# Voir les logs du service app1
sudo journalctl -u app1.service -f

# Voir les 50 dernières lignes
sudo journalctl -u app1.service -n 50

# Voir les logs depuis les 10 dernières minutes
sudo journalctl -u app1.service --since "10 minutes ago"

# Voir les logs avec timestamps de toutes les couches
sudo journalctl -u "*.service" -f
```

### Voir les services actifs

```bash
# Lister tous les services Node.js de ce système
sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"

# Exemple :
# frontend1.service                        loaded active running   Frontend-1 Node.js Server (Port 80)
# frontend2.service                        loaded active running   Frontend-2 Node.js Server (Port 8443)
# app1.service                             loaded active running   App-1 Node.js Server (Port 5000)
# data1.service                            loaded active running   Data-1 Node.js Server (Port 6000)
# admin.service                            loaded active running   Admin Dashboard Node.js Server (Port 7000)
```

---

## 🔄 Processus de démarrage après redémarrage

Voici ce qui se passe lorsque vous redémarrez une VM :

```
1. VM redémarre
   ↓
2. Système d'exploitation démarre
   ↓
3. Systemd charge les services au boot (WantedBy=multi-user.target)
   ↓
4. ExecStart lance : /usr/bin/node /home/cloud/app/server.js
   ↓
5. Service app1 est active (running)
   ↓
6. Load Balancer détecte la VM ready via /health probe
   ↓
7. Trafic commence à arriver
```

**Temps total** : ~30-45 secondes (y compris les checks du LB)

---

## 🧪 Tests après redémarrage

### Test 1 : Vérifier que le service a redémarré

```bash
# Se connecter à la VM via Bastion
az network bastion ssh --name bastion -g rg-loadbalancer \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# Une fois connecté, vérifier que le service tourne
sudo systemctl status app1.service

# Devrait afficher "active (running)"
```

### Test 2 : Vérifier que le serveur répond

```bash
# Sur la VM ou depuis une autre VM
curl http://localhost:5000/health
# Devrait retourner : OK

curl http://localhost:5000/whoami
# Devrait retourner : { "instance": "app-1", "address": "10.2.0.4", "port": 5000 }
```

### Test 3 : Vérifier que le Load Balancer le voit

```bash
# Via Azure CLI
az network lb address-pool show \
  -g rg-loadbalancer \
  --lb-name app-lb \
  --name app-backpool

# La VM devrait être dans "backendIPConfigurations" avec statut healthy
```

### Test 4 : Simuler un crash et vérifier l'auto-redémarrage

```bash
# Sur la VM, tuer le processus Node.js
sudo pkill -f "node /home/cloud/app/server.js"

# Vérifier que le service le redémarre automatiquement (attendre 5 secondes)
sleep 5
sudo systemctl status app1.service

# Devrait afficher "active (running)" avec un nouveau PID

# Vérifier les logs pour voir le redémarrage
sudo journalctl -u app1.service -n 10
```

---

## 📊 Structure du fichier service

Chaque service utilise cette configuration :

```ini
[Unit]
Description=App-1 Node.js Server (Port 5000)
After=network.target                    # Attendre que le réseau soit prêt

[Service]
Type=simple                              # Processus simple (pas de fork)
User=cloud                               # Lancer en tant qu'utilisateur cloud
WorkingDirectory=/home/cloud/app         # Répertoire de travail
ExecStart=/usr/bin/node /home/cloud/app/server.js  # Commande de démarrage
Restart=always                           # Redémarrer si le processus s'arrête
RestartSec=5                             # Attendre 5 secondes avant redémarrage
StandardOutput=journal                   # Logs vers journalctl
StandardError=journal                    # Erreurs vers journalctl

[Install]
WantedBy=multi-user.target               # Démarrer au boot du système
```

---

## 🐛 Troubleshooting

### Problème 1 : Le service ne démarre pas après un redémarrage

**Symptôme** : La VM redémarre mais le serveur n'écoute pas

**Solutions** :

```bash
# Vérifier que le service est activé au démarrage
sudo systemctl is-enabled app1.service
# Devrait afficher : enabled

# Si disabled, l'activer
sudo systemctl enable app1.service

# Vérifier l'état du service
sudo systemctl status app1.service

# Voir les erreurs dans les logs
sudo journalctl -u app1.service -n 50

# Redémarrer manuellement
sudo systemctl restart app1.service
```

### Problème 2 : Le service reste en "inactive (dead)"

**Cause possible** : Le fichier server.js n'existe pas ou permission insuffisante

**Solutions** :

```bash
# Vérifier que le fichier existe
ls -la /home/cloud/app/server.js

# Vérifier les permissions
sudo chown cloud:cloud /home/cloud/app/server.js
sudo chmod 755 /home/cloud/app/server.js

# Voir les erreurs
sudo journalctl -u app1.service -n 20

# Vérifier que Node.js est installé
which node
node --version

# Redémarrer le service
sudo systemctl restart app1.service
```

### Problème 3 : Les logs ne s'affichent pas

**Solution** :

```bash
# Voir les logs complets
sudo journalctl -u app1.service

# Voir les logs en direct (suit les nouveaux messages)
sudo journalctl -u app1.service -f

# Voir les erreurs uniquement
sudo journalctl -u app1.service -p err
```

### Problème 4 : Redémarrage infini du service

**Symptôme** : Le service redémarre toutes les 5 secondes

**Causes possibles** :
- Dépendances Node.js manquantes
- Code avec erreur au démarrage
- Port déjà occupé

**Solutions** :

```bash
# Arrêter le service temporairement pour investiguer
sudo systemctl stop app1.service

# Tester le serveur manuellement
cd /home/cloud/app
npm install  # Réinstaller les dépendances
node server.js

# Si erreur, corriger le problème
# Puis relancer le service
sudo systemctl start app1.service
```

---

## 📈 Commandes utiles pour tous les services

### Redémarrer TOUS les services

```bash
# Redémarrer tous les services d'une couche
sudo systemctl restart frontend*.service
sudo systemctl restart app*.service
sudo systemctl restart data*.service

# Ou redémarrer tout d'un coup
sudo systemctl restart frontend1.service frontend2.service app1.service app2.service app2_b.service data1.service data2.service data2_b.service admin.service
```

### Voir l'état de TOUS les services

```bash
# État détaillé de tous les services
for service in frontend1 frontend2 app1 app2 app2_b data1 data2 data2_b admin; do
  echo "=== $service.service ==="
  sudo systemctl status ${service}.service | grep -E "Active|Loaded"
done
```

### Afficher les logs de tous les services

```bash
# Tous les logs
sudo journalctl -u "*.service" -f

# Logs de tous les services app
sudo journalctl -u app*.service -f

# Logs avec priorité ERROR ou supérieure
sudo journalctl -p err -f
```

---

## ✨ Avantages des services systemd

Avant (avec `node &`) :
- ❌ Serveur s'arrête au redémarrage
- ❌ Il faut se connecter et relancer manuellement
- ❌ Si le serveur crash, il reste arrêté
- ❌ Les logs sont perdus au logout

Après (avec systemd) :
- ✅ Serveur démarre automatiquement au boot
- ✅ Plus besoin d'intervention manuelle
- ✅ Redémarrage automatique en cas de crash
- ✅ Logs persistants et centralisés dans journalctl

---

## 📚 Ressources complémentaires

- [Systemd Documentation](https://systemd.io/)
- [Systemctl Manual](https://man7.org/linux/man-pages/man1/systemctl.1.html)
- [Journalctl Manual](https://man7.org/linux/man-pages/man1/journalctl.1.html)

---

**Auteur** : VRM  
**Date** : 2025  
**Version** : 1.0
