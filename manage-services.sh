#!/bin/bash

# Script de gestion des services Node.js
# Utilisation : ./manage-services.sh [action] [service]
# 
# Actions :
#   status [service]     - Afficher l'état (par défaut: tous les services)
#   restart [service]    - Redémarrer un service
#   stop [service]       - Arrêter un service
#   start [service]      - Démarrer un service
#   logs [service]       - Afficher les logs en direct
#   enable [service]     - Activer au démarrage
#   disable [service]    - Désactiver au démarrage
#   all-status           - État de tous les services
#   all-restart          - Redémarrer tous les services
#   all-logs             - Logs de tous les services
#
# Services disponibles :
#   frontend1, frontend2, app1, app2, app2_b, data1, data2, data2_b, admin

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Services disponibles
SERVICES=("frontend1" "frontend2" "app1" "app2" "app2_b" "data1" "data2" "data2_b" "admin")

# Fonction pour afficher l'aide
show_help() {
  echo -e "${BLUE}=== Gestionnaire de Services Node.js ===${NC}"
  echo ""
  echo "Usage: $0 [action] [service]"
  echo ""
  echo -e "${GREEN}Actions:${NC}"
  echo "  status [service]     - Afficher l'état"
  echo "  restart [service]    - Redémarrer"
  echo "  stop [service]       - Arrêter"
  echo "  start [service]      - Démarrer"
  echo "  logs [service]       - Voir les logs (en direct)"
  echo "  enable [service]     - Activer au démarrage"
  echo "  disable [service]    - Désactiver au démarrage"
  echo "  all-status           - État de TOUS les services"
  echo "  all-restart          - Redémarrer TOUS les services"
  echo "  all-logs             - Logs de TOUS les services"
  echo ""
  echo -e "${GREEN}Services disponibles:${NC}"
  echo "  ${SERVICES[@]}"
  echo ""
  echo -e "${YELLOW}Exemples:${NC}"
  echo "  $0 status app1"
  echo "  $0 restart app1"
  echo "  $0 logs data1"
  echo "  $0 all-status"
  echo "  $0 all-restart"
}

# Fonction pour vérifier si le service existe
is_valid_service() {
  for s in "${SERVICES[@]}"; do
    if [[ "$s" == "$1" ]]; then
      return 0
    fi
  done
  return 1
}

# Afficher l'état d'un service
show_status() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  sudo systemctl status ${service}.service
}

# Afficher l'état de tous les services
show_all_status() {
  echo -e "${BLUE}=== État de tous les services ===${NC}\n"
  for service in "${SERVICES[@]}"; do
    local status=$(sudo systemctl is-active ${service}.service)
    if [[ "$status" == "active" ]]; then
      echo -e "${GREEN}✓${NC} ${service}.service : ${GREEN}${status}${NC}"
    else
      echo -e "${RED}✗${NC} ${service}.service : ${RED}${status}${NC}"
    fi
  done
}

# Redémarrer un service
restart_service() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  echo -e "${YELLOW}Redémarrage de ${service}.service...${NC}"
  sudo systemctl restart ${service}.service
  sleep 1
  
  local status=$(sudo systemctl is-active ${service}.service)
  if [[ "$status" == "active" ]]; then
    echo -e "${GREEN}✓ ${service}.service redémarré avec succès${NC}"
  else
    echo -e "${RED}✗ Erreur: ${service}.service est ${status}${NC}"
    return 1
  fi
}

# Redémarrer tous les services
restart_all_services() {
  echo -e "${YELLOW}Redémarrage de tous les services...${NC}\n"
  for service in "${SERVICES[@]}"; do
    restart_service "$service"
  done
  echo -e "\n${GREEN}Redémarrage complet terminé${NC}"
}

# Arrêter un service
stop_service() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  echo -e "${YELLOW}Arrêt de ${service}.service...${NC}"
  sudo systemctl stop ${service}.service
  sleep 1
  
  local status=$(sudo systemctl is-active ${service}.service)
  echo -e "${GREEN}✓ ${service}.service arrêté${NC}"
}

# Démarrer un service
start_service() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  echo -e "${YELLOW}Démarrage de ${service}.service...${NC}"
  sudo systemctl start ${service}.service
  sleep 1
  
  local status=$(sudo systemctl is-active ${service}.service)
  if [[ "$status" == "active" ]]; then
    echo -e "${GREEN}✓ ${service}.service démarré${NC}"
  else
    echo -e "${RED}✗ Erreur: ${service}.service est ${status}${NC}"
    return 1
  fi
}

# Afficher les logs d'un service
show_logs() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  echo -e "${BLUE}=== Logs de ${service}.service ===${NC}"
  echo "(Appuyez sur Ctrl+C pour arrêter)\n"
  sudo journalctl -u ${service}.service -f
}

# Afficher les logs de tous les services
show_all_logs() {
  echo -e "${BLUE}=== Logs de tous les services ===${NC}"
  echo "(Appuyez sur Ctrl+C pour arrêter)\n"
  sudo journalctl -u "*.service" -f | grep -E "frontend|app|data|admin"
}

# Activer un service au démarrage
enable_service() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  sudo systemctl enable ${service}.service
  echo -e "${GREEN}✓ ${service}.service activé au démarrage${NC}"
}

# Désactiver un service au démarrage
disable_service() {
  local service=$1
  if ! is_valid_service "$service"; then
    echo -e "${RED}Erreur: Service '$service' non trouvé${NC}"
    return 1
  fi
  
  sudo systemctl disable ${service}.service
  echo -e "${GREEN}✓ ${service}.service désactivé au démarrage${NC}"
}

# Main
ACTION=${1:-help}
SERVICE=${2:-}

case "$ACTION" in
  status)
    if [[ -z "$SERVICE" ]]; then
      show_all_status
    else
      show_status "$SERVICE"
    fi
    ;;
  restart)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Erreur: Veuillez spécifier un service${NC}"
      show_help
      exit 1
    fi
    restart_service "$SERVICE"
    ;;
  stop)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Erreur: Veuillez spécifier un service${NC}"
      show_help
      exit 1
    fi
    stop_service "$SERVICE"
    ;;
  start)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Erreur: Veuillez spécifier un service${NC}"
      show_help
      exit 1
    fi
    start_service "$SERVICE"
    ;;
  logs)
    if [[ -z "$SERVICE" ]]; then
      show_all_logs
    else
      show_logs "$SERVICE"
    fi
    ;;
  enable)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Erreur: Veuillez spécifier un service${NC}"
      show_help
      exit 1
    fi
    enable_service "$SERVICE"
    ;;
  disable)
    if [[ -z "$SERVICE" ]]; then
      echo -e "${RED}Erreur: Veuillez spécifier un service${NC}"
      show_help
      exit 1
    fi
    disable_service "$SERVICE"
    ;;
  all-status)
    show_all_status
    ;;
  all-restart)
    restart_all_services
    ;;
  all-logs)
    show_all_logs
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    echo -e "${RED}Action inconnue: $ACTION${NC}"
    show_help
    exit 1
    ;;
esac
