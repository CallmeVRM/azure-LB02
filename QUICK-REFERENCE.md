# Quick Reference - Gestion des Services 📋

## 🚀 Les essentiels

Après chaque redémarrage de VM, **PLUS BESOIN** de relancer manuellement Node.js ! Les services démarrent automatiquement.

### Vérifier que tout fonctionne

```bash
# Voir l'état de tous les services
sudo systemctl status frontend1.service
sudo systemctl status app1.service
sudo systemctl status data1.service

# Tous les services devraient afficher : "active (running)"
```

### Redémarrer un service

```bash
# Redémarrer app1 (par exemple)
sudo systemctl restart app1.service

# Attendre 5 secondes que le service redémarre
sleep 5

# Vérifier qu'il est revenu en ligne
sudo systemctl status app1.service
```

---

## 📊 Tableau des services

Tous les services de votre système :

```bash
# Voir TOUS les services Node.js
sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"

# Exemple de sortie :
# frontend1.service        loaded active running   Frontend-1 Node.js Server
# frontend2.service        loaded active running   Frontend-2 Node.js Server
# app1.service             loaded active running   App-1 Node.js Server
# app2.service             loaded active running   App-2 Node.js Server
# data1.service            loaded active running   Data-1 Node.js Server
# admin.service            loaded active running   Admin Dashboard Node.js Server
```

---

## 🔍 Voir les logs

### Logs en direct (suivi en temps réel)

```bash
# Logs du service app1 (en direct)
sudo journalctl -u app1.service -f

# Appuyez sur Ctrl+C pour arrêter le suivi
```

### Logs historique

```bash
# Voir les 50 dernières lignes
sudo journalctl -u app1.service -n 50

# Voir les logs des 10 dernières minutes
sudo journalctl -u app1.service --since "10 minutes ago"

# Voir TOUS les logs du service depuis le démarrage
sudo journalctl -u app1.service
```

### Voir les erreurs uniquement

```bash
# Afficher uniquement les erreurs du service
sudo journalctl -u app1.service -p err

# Afficher erreurs + warnings
sudo journalctl -u app1.service -p warning..err
```

---

## 🔧 Commandes courantes

### Redémarrer UN service

```bash
# Syntaxe
sudo systemctl restart [SERVICE_NAME].service

# Exemples
sudo systemctl restart frontend1.service
sudo systemctl restart app2.service
sudo systemctl restart data1.service
```

### Redémarrer TOUS les services

```bash
# Redémarrer tous les services frontend
sudo systemctl restart frontend*.service

# Redémarrer tous les services app
sudo systemctl restart app*.service

# Redémarrer tous les services data
sudo systemctl restart data*.service

# Redémarrer TOUS les services d'un coup
sudo systemctl restart frontend*.service app*.service data*.service admin.service
```

### Arrêter un service

```bash
sudo systemctl stop app1.service
```

### Démarrer un service arrêté

```bash
sudo systemctl start app1.service
```

### Désactiver le redémarrage automatique

```bash
# Si vous voulez que le service NE redémarre PLUS après un reboot
sudo systemctl disable app1.service

# Vérifier qu'il est bien désactivé
sudo systemctl is-enabled app1.service
# Affiche : disabled
```

### Réactiver le redémarrage automatique

```bash
# Si vous voulez que le service redémarre à nouveau après un reboot
sudo systemctl enable app1.service

# Vérifier qu'il est bien activé
sudo systemctl is-enabled app1.service
# Affiche : enabled
```

---

## 🧪 Scénarios de test

### Scénario 1 : Redémarrer une VM et vérifier que tout démarre

```bash
# 1. Redémarrer la VM
sudo reboot

# 2. Attendre 30 secondes que la VM redémarre
# (La connexion SSH sera perdue)

# 3. Se reconnecter via Bastion
az network bastion ssh --name bastion -g rg-loadbalancer \
  --auth-type password --username cloud \
  --target-resource-id $(az vm show --name app-vm1 -g rg-loadbalancer --query id -o tsv)

# 4. Vérifier que les services sont automatiquement redémarrés
sudo systemctl status app1.service
# Devrait afficher "active (running)"

# 5. Tester le serveur
curl http://localhost:5000/health
# Devrait retourner "OK"
```

### Scénario 2 : Simuler un crash et vérifier l'auto-redémarrage

```bash
# 1. Tuer le processus Node.js
sudo pkill -f "node /home/cloud/app/server.js"

# 2. Vérifier que le service le redémarre automatiquement (attendre 5 secondes)
sleep 5
sudo systemctl status app1.service
# Devrait afficher "active (running)" avec un NOUVEAU PID

# 3. Vérifier les logs pour voir le redémarrage
sudo journalctl -u app1.service -n 20
```

### Scénario 3 : Mettre à jour le code et redémarrer

```bash
# 1. Mettre à jour le code depuis GitHub
cd /home/cloud/app
git clone https://github.com/CallmeVRM/azure-LB02 /tmp/lab
cp /tmp/lab/app/app1.js /home/cloud/app/server.js

# 2. Redémarrer le service pour charger le nouveau code
sudo systemctl restart app1.service

# 3. Vérifier que le nouveau code est actif
curl http://localhost:5000/whoami
```

---

## 📊 Monitoring - Script simple

Créer un script qui vérifie l'état de tous les services :

```bash
#!/bin/bash
# Sauvegarder en : check-all.sh

echo "=== État des services Node.js ==="
echo ""

for service in frontend1 frontend2 app1 app2 app2_b data1 data2 data2_b admin; do
  STATUS=$(sudo systemctl is-active ${service}.service)
  PORT=$(sudo systemctl show ${service}.service -p ExecStart | grep -oP ':\K\d+' | head -1)
  
  if [ "$STATUS" = "active" ]; then
    echo "✓ ${service}.service - ACTIF"
  else
    echo "✗ ${service}.service - INACTIF"
  fi
done

echo ""
echo "=== Mémoire utilisée ==="
ps aux | grep node | grep -v grep | awk '{sum+=$6} END {print "Total: " sum " KB"}'
```

Utilisation :

```bash
chmod +x check-all.sh
./check-all.sh
```

---

## ⚡ Raccourcis utiles

### Créer des alias pour les commandes fréquentes

Ajouter à `~/.bashrc` ou `~/.zshrc` :

```bash
# Services
alias service-status='sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"'
alias service-logs='sudo journalctl -u "*.service" -f | grep -E "frontend|app|data|admin"'
alias service-restart-all='sudo systemctl restart frontend*.service app*.service data*.service admin.service'
alias service-stop-all='sudo systemctl stop frontend*.service app*.service data*.service admin.service'

# Logs spécifiques
alias logs-app1='sudo journalctl -u app1.service -f'
alias logs-app2='sudo journalctl -u app2.service -f'
alias logs-data1='sudo journalctl -u data1.service -f'

# Tests rapides
alias test-app1='curl http://localhost:5000/whoami'
alias test-data1='curl http://localhost:6000/whoami'
```

Puis relancer le shell :

```bash
source ~/.bashrc
# Ou pour zsh
source ~/.zshrc
```

Maintenant vous pouvez utiliser :

```bash
service-status
service-logs
service-restart-all
logs-app1
test-app1
```

---

## 🎯 Checklist après déploiement

Après avoir déployé les VMs avec `./infra.sh`, vérifier :

- [ ] Les services sont créés sur chaque VM
- [ ] Les services démarrent au boot
- [ ] Les services redémarrent auto après un reboot
- [ ] Les logs sont centralisés dans journalctl
- [ ] Le Load Balancer voit les VMs comme "Healthy"
- [ ] Le round-robin fonctionne

Test complet :

```bash
# 1. Vérifier tous les services
sudo systemctl list-units --type=service | grep -E "frontend|app|data|admin"

# 2. Redémarrer une VM et vérifier que tout redémarre
# (voir scénario 1 ci-dessus)

# 3. Vérifier le Load Balancer
az network lb address-pool show -g rg-loadbalancer --lb-name app-lb --name app-backpool

# 4. Tester le trafic round-robin
for i in {1..10}; do
  curl -s http://10.2.0.250:5000/whoami | grep -o '"instance":"[^"]*"'
done
```

---

**Auteur** : VRM  
**Date** : 2025
