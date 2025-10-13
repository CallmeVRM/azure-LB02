# Azure Load Balancer - Lab Pédagogique 🎓

> **Objectif** : Apprendre Azure Load Balancer en déployant une architecture 3-tiers avec répartition de charge

## 📚 Table des matières

1. [Introduction](#introduction)
2. [Architecture du projet](#architecture-du-projet)
3. [Prérequis](#prérequis)
4. [Structure des fichiers](#structure-des-fichiers)
5. [Concepts Azure expliqués](#concepts-azure-expliqués)
6. [Déploiement pas à pas](#déploiement-pas-à-pas)
7. [Fonctionnement de l'application](#fonctionnement-de-lapplication)
8. [Tests et validation](#tests-et-validation)
9. [Troubleshooting](#troubleshooting)
10. [Exercices pratiques](#exercices-pratiques)

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