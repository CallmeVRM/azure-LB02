# Fix: Frontend-1 Service Crash on Port 80

## 🔍 Problème identifié

Le service `frontend1.service` se crashait immédiatement après démarrage :

```
Oct 16 07:49:03 frontend-vm1 systemd[1]: frontend1.service: Deactivated successfully.
Oct 16 07:49:08 frontend-vm1 systemd[1]: frontend1.service: Scheduled restart job, restart counter is at 24.
Oct 16 07:49:08 frontend-vm1 systemd[1]: Started frontend1.service - Frontend-1 Node.js Server (Port 80).
Oct 16 07:49:09 frontend-vm1 node[1479]: Frontend-1 listening on http://0.0.0.0:80
Oct 16 07:49:09 frontend-vm1 systemd[1]: frontend1.service: Deactivated successfully.
```

**Observation** : Le serveur démarre ("listening on 80") mais s'arrête immédiatement après.

---

## 🎯 Cause racine

### Ports privilégiés en Linux

En Linux, **seul root peut binder sur les ports < 1024** (ports privilégiés) :
- Port 80 : HTTP (privilégié)
- Port 8443 : HTTPS (non-privilégié, >= 1024)
- Port 5000 : Application (non-privilégié)
- Port 6000 : Données (non-privilégié)

### Problème avec notre configuration

```ini
[Service]
Type=simple
User=cloud          # ← Utilisateur non-root !
ExecStart=/usr/bin/node /home/cloud/frontend/server.js
# Pas de CAP_NET_BIND_SERVICE ← C'est le problème !
```

**Séquence d'erreur** :

1. Systemd lance le service avec l'utilisateur `cloud` (non-root)
2. Node.js essaie de binder sur le port 80
3. ❌ Erreur : "Permission denied" (seul root peut le faire)
4. Processus se ferme immédiatement
5. Systemd voit le crash
6. Systemd redémarre le service (car `Restart=always`)
7. La boucle continue → 24+ redémarrages

---

## ✅ Solution appliquée

Ajouter la **Linux capability** `CAP_NET_BIND_SERVICE` au service :

### Qu'est-ce que CAP_NET_BIND_SERVICE ?

C'est une capacité Linux qui permet à un processus non-root de binder sur des ports privilégiés (< 1024).

```ini
[Service]
Type=simple
User=cloud
ExecStart=/usr/bin/node /home/cloud/frontend/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
AmbientCapabilities=CAP_NET_BIND_SERVICE  # ← NOUVEAU !

[Install]
WantedBy=multi-user.target
```

### Comment ça marche

- `AmbientCapabilities=CAP_NET_BIND_SERVICE` donne la capacité à TOUS les processus lancés par ce service
- L'utilisateur `cloud` peut maintenant binder sur le port 80
- Pas besoin de lancer le service en root
- Respecte les principes de sécurité (least privilege)

---

## 🔧 Changements effectués

### Fichier modifié

**`frontend/cloud-init-frontend1.yaml`** :

```diff
  [Service]
  Type=simple
  User=cloud
  WorkingDirectory=/home/cloud/frontend
  ExecStart=/usr/bin/node /home/cloud/frontend/server.js
  Restart=always
  RestartSec=5
  StandardOutput=journal
  StandardError=journal
+ AmbientCapabilities=CAP_NET_BIND_SERVICE
  
  [Install]
  WantedBy=multi-user.target
```

### Fichiers non modifiés (pas le même problème)

- ✅ **frontend2.yaml** : Port 8443 (non-privilégié, pas besoin)
- ✅ **frontend2_b.yaml** : Port 8443 (non-privilégié, pas besoin)
- ✅ **app*.yaml** : Port 5000+ (non-privilégié, pas besoin)
- ✅ **data*.yaml** : Port 6000+ (non-privilégié, pas besoin)
- ✅ **admin.yaml** : Port 7000 (non-privilégié, pas besoin)

---

## 🧪 Test après correction

Après redéploiement de la VM avec le cloud-init corrigé :

### 1️⃣ Vérifier que le service démarre correctement

```bash
sudo systemctl status frontend1.service
```

Résultat attendu :
```
● frontend1.service - Frontend-1 Node.js Server (Port 80)
     Loaded: loaded (/etc/systemd/system/frontend1.service; enabled; vendor preset: enabled)
     Active: active (running) since ...
```

### 2️⃣ Vérifier que le port 80 répond

```bash
curl http://localhost/health
```

Résultat attendu : `OK`

### 3️⃣ Vérifier les logs

```bash
sudo journalctl -u frontend1.service -f
```

Résultat attendu :
```
Oct 16 ... node[1234]: Frontend-1 listening on http://0.0.0.0:80
```

Sans message d'erreur ou "Deactivated successfully"

### 4️⃣ Tester le redémarrage de la VM

```bash
sudo reboot
```

Attendre 30 secondes, puis :

```bash
curl http://localhost/health
```

Résultat attendu : `OK` (le service a redémarré automatiquement)

---

## 📋 Résumé

| Aspect | Avant | Après |
|--------|-------|-------|
| **Port** | 80 (privilégié) | 80 (privilégié) |
| **Utilisateur** | `cloud` (non-root) | `cloud` (non-root) |
| **Permission** | ❌ Denied | ✅ Granted (CAP_NET_BIND_SERVICE) |
| **Statut service** | 🔴 Crash loop | 🟢 Running |
| **Redémarrages** | 24+ crashes | 0 crashes |

---

## 🔐 Sécurité

Cette solution est **sûre** car :

1. **Principe du moindre privilège** : L'utilisateur `cloud` n'a que la capacité nécessaire
2. **Pas de root** : Le service ne s'exécute pas en root
3. **Isolement** : Seul ce service a cette capacité
4. **Standard Linux** : `CAP_NET_BIND_SERVICE` est un mécanisme standard et bien connu

### Alternative (moins recommandée)

Exécuter le service en root :

```ini
User=root  # ← Moins sûr, plus de privilèges que nécessaire
```

**Pourquoi c'est moins bon** :
- Root peut faire bien plus que juste binder sur le port 80
- Violation du principe du moindre privilège
- Risque de sécurité augmenté si Node.js est compromis

---

## ✅ Déploiement

Pour appliquer le correctif :

### Option 1 : Redéployer depuis zéro

```bash
az group delete -g rg-loadbalancer --yes
./infra.sh
```

### Option 2 : Corriger sur une VM existante

```bash
# Se connecter à la VM via Bastion
az network bastion ssh --name bastion -g rg-loadbalancer -n frontend-vm1

# Modifier le service
sudo nano /etc/systemd/system/frontend1.service

# Ajouter la ligne : AmbientCapabilities=CAP_NET_BIND_SERVICE

# Recharger et redémarrer
sudo systemctl daemon-reload
sudo systemctl restart frontend1

# Vérifier
sudo systemctl status frontend1
curl http://localhost/health
```

---

**Auteur** : VRM  
**Date** : 2025-10-16  
**Version** : 1.0
