#!/bin/bash

# Script de test pour frontend-vm2_b et Load Balancer
# Ce script teste la répartition de charge entre les 3 frontends

set -e

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Load Balancer - Frontend 2_b                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Variables
rg="${1:-lb-poc-rg}"
echo -e "${YELLOW}Resource Group: $rg${NC}"
echo ""

# 1. Vérifier que la VM existe
echo -e "${BLUE}[1/8]${NC} Vérification de la VM frontend-vm2_b..."
vmStatus=$(az vm show -g $rg -n frontend-vm2_b --query provisioningState -o tsv 2>/dev/null || echo "NotFound")

if [ "$vmStatus" == "Succeeded" ]; then
    echo -e "${GREEN}✓${NC} VM frontend-vm2_b est running"
else
    echo -e "${RED}✗${NC} VM frontend-vm2_b n'existe pas ou n'est pas running"
    echo -e "${YELLOW}Créez-la avec: ./infra.sh${NC}"
    exit 1
fi

# 2. Récupérer l'IP privée
echo -e "${BLUE}[2/8]${NC} Récupération de l'IP privée..."
privateIp=$(az vm show -g $rg -n frontend-vm2_b -d --query privateIps -o tsv)
echo -e "${GREEN}✓${NC} IP privée: $privateIp"

# 3. Vérifier que la NIC est dans le backend pool
echo -e "${BLUE}[3/8]${NC} Vérification du backend pool..."
backendCount=$(az network lb address-pool show -g $rg --lb-name front-lb -n front-backpool \
    --query "length(backendIpConfigurations)" -o tsv 2>/dev/null || echo "0")
echo -e "${GREEN}✓${NC} Backend pool contient $backendCount NICs"

if [ "$backendCount" -lt 3 ]; then
    echo -e "${YELLOW}⚠${NC}  Attendu 3 NICs minimum (frontend-vm1, vm2, vm2_b)"
fi

# 4. Tester l'endpoint whoami depuis le bastion (si possible)
echo -e "${BLUE}[4/8]${NC} Test de l'endpoint /whoami (nécessite accès réseau)..."
# Note: Ce test peut échouer si vous n'avez pas accès direct au réseau privé
if command -v curl &> /dev/null; then
    response=$(curl -s -m 5 "http://${privateIp}:8443/whoami" 2>/dev/null || echo "")
    if [ -n "$response" ]; then
        instance=$(echo $response | jq -r '.instance' 2>/dev/null || echo "error")
        if [ "$instance" == "frontend-2_b" ]; then
            echo -e "${GREEN}✓${NC} Endpoint /whoami accessible - Instance: $instance"
        else
            echo -e "${YELLOW}⚠${NC}  Réponse reçue mais instance incorrect: $instance"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Impossible d'atteindre l'endpoint (normal si pas sur le réseau Azure)"
    fi
else
    echo -e "${YELLOW}⚠${NC}  curl non installé, test skipped"
fi

# 5. Récupérer l'IP publique du Load Balancer
echo -e "${BLUE}[5/8]${NC} Récupération de l'IP publique du Load Balancer..."
frontLbIp=$(az network public-ip show -g $rg -n front-lb-pip --query ipAddress -o tsv 2>/dev/null || echo "")

if [ -n "$frontLbIp" ]; then
    echo -e "${GREEN}✓${NC} IP publique du LB: $frontLbIp"
else
    echo -e "${RED}✗${NC} Impossible de récupérer l'IP publique du LB"
    exit 1
fi

# 6. Tester la répartition de charge (10 requêtes)
echo -e "${BLUE}[6/8]${NC} Test de la répartition de charge (10 requêtes)..."
echo -e "${YELLOW}Cela peut prendre 10-15 secondes...${NC}"

declare -A distribution
total=0
success=0

for i in {1..10}; do
    # Tester sur le port 8443 (frontend-2 et frontend-2_b)
    response=$(curl -s -m 5 "http://${frontLbIp}:8443/whoami" 2>/dev/null || echo "")
    if [ -n "$response" ]; then
        instance=$(echo $response | jq -r '.instance' 2>/dev/null || echo "error")
        if [ "$instance" != "error" ] && [ "$instance" != "null" ]; then
            ((distribution[$instance]++))
            ((success++))
            echo -e "  Requête $i: ${GREEN}$instance${NC}"
        else
            echo -e "  Requête $i: ${RED}Erreur parsing${NC}"
        fi
    else
        echo -e "  Requête $i: ${RED}Timeout${NC}"
    fi
    ((total++))
    sleep 1
done

echo ""
echo -e "${BLUE}Résultats de la distribution:${NC}"
for instance in "${!distribution[@]}"; do
    count=${distribution[$instance]}
    percentage=$((count * 100 / total))
    echo -e "  $instance: ${GREEN}$count requêtes${NC} (${percentage}%)"
done
echo -e "${YELLOW}Succès: $success/$total${NC}"

# 7. Vérifier que frontend-2_b apparaît dans la distribution
echo -e "${BLUE}[7/8]${NC} Vérification de la présence de frontend-2_b..."
if [ "${distribution[frontend-2_b]}" ]; then
    echo -e "${GREEN}✓${NC} frontend-2_b a reçu ${distribution[frontend-2_b]} requêtes"
else
    echo -e "${RED}✗${NC} frontend-2_b n'a reçu aucune requête"
    echo -e "${YELLOW}Vérifiez:${NC}"
    echo "  - Que le serveur Node.js tourne sur la VM"
    echo "  - Que le health probe est configuré correctement"
    echo "  - Que la NIC est bien dans le backend pool"
fi

# 8. Afficher les commandes pour débugger
echo -e "${BLUE}[8/8]${NC} Commandes de debugging..."
echo ""
echo -e "${YELLOW}Pour se connecter à la VM:${NC}"
echo "az network bastion ssh --name bastion --resource-group $rg \\"
echo "  --auth-type password --username cloud \\"
echo "  --target-resource-id \$(az vm show --name frontend-vm2_b -g $rg --query id -o tsv)"
echo ""
echo -e "${YELLOW}Pour vérifier le serveur sur la VM:${NC}"
echo "ps aux | grep node"
echo "ss -tlnp | grep 8443"
echo "curl -s http://localhost:8443/whoami | jq ."
echo ""
echo -e "${YELLOW}Pour vérifier les logs:${NC}"
echo "sudo tail -f /var/log/cloud-init-output.log"
echo ""
echo -e "${YELLOW}Pour redémarrer le serveur:${NC}"
echo "cd /home/cloud/frontend"
echo "pkill -f server.js"
echo "nohup node server.js > server.log 2>&1 &"
echo ""

# Résumé final
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
if [ "$success" -gt 5 ] && [ "${distribution[frontend-2_b]}" ]; then
    echo -e "${GREEN}║  ✓ Test réussi ! Le Load Balancer fonctionne          ║${NC}"
else
    echo -e "${YELLOW}║  ⚠ Test partiel - Vérifications recommandées          ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
