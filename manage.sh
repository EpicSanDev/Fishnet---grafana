#!/bin/bash

# Fishnet Monitor Control Script

# Couleurs pour une meilleure lisibilité
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker n'est pas installé. Veuillez l'installer avant de continuer.${NC}"
    exit 1
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose n'est pas installé. Veuillez l'installer avant de continuer.${NC}"
    exit 1
fi

# Fonction pour démarrer les services
start_services() {
    echo -e "${BLUE}Démarrage des services de monitoring Fishnet...${NC}"
    docker-compose up -d
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Services démarrés avec succès!${NC}"
        echo -e "${YELLOW}Accès aux dashboards:${NC}"
        echo -e "  - Grafana: http://localhost:3000 (identifiants: admin/admin)"
        echo -e "  - Prometheus: http://localhost:9090"
    else
        echo -e "${RED}Erreur lors du démarrage des services.${NC}"
    fi
}

# Fonction pour arrêter les services
stop_services() {
    echo -e "${BLUE}Arrêt des services de monitoring Fishnet...${NC}"
    docker-compose down
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Services arrêtés avec succès!${NC}"
    else
        echo -e "${RED}Erreur lors de l'arrêt des services.${NC}"
    fi
}

# Fonction pour redémarrer les services
restart_services() {
    echo -e "${BLUE}Redémarrage des services de monitoring Fishnet...${NC}"
    docker-compose restart
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Services redémarrés avec succès!${NC}"
    else
        echo -e "${RED}Erreur lors du redémarrage des services.${NC}"
    fi
}

# Fonction pour afficher les logs
show_logs() {
    echo -e "${BLUE}Affichage des logs des services...${NC}"
    docker-compose logs -f
}

# Fonction pour vérifier l'état des services
check_status() {
    echo -e "${BLUE}État des services de monitoring Fishnet:${NC}"
    docker-compose ps
}

# Fonction pour mettre à jour les images Docker
update_images() {
    echo -e "${BLUE}Mise à jour des images Docker...${NC}"
    docker-compose pull
    docker-compose build --no-cache fishnet-exporter
    echo -e "${GREEN}Images mises à jour. Veuillez redémarrer les services pour appliquer les changements.${NC}"
}

# Afficher le menu
show_menu() {
    echo -e "${YELLOW}=== Fishnet Monitoring Dashboard - Menu de contrôle ===${NC}"
    echo -e "${BLUE}1.${NC} Démarrer les services"
    echo -e "${BLUE}2.${NC} Arrêter les services"
    echo -e "${BLUE}3.${NC} Redémarrer les services"
    echo -e "${BLUE}4.${NC} Afficher les logs"
    echo -e "${BLUE}5.${NC} Vérifier l'état des services"
    echo -e "${BLUE}6.${NC} Mettre à jour les images Docker"
    echo -e "${BLUE}0.${NC} Quitter"
    echo -e "${YELLOW}=================================================${NC}"
    echo -ne "Entrez votre choix [0-6]: "
    read choice
    
    case $choice in
        1) start_services ;;
        2) stop_services ;;
        3) restart_services ;;
        4) show_logs ;;
        5) check_status ;;
        6) update_images ;;
        0) exit 0 ;;
        *) echo -e "${RED}Choix invalide. Veuillez réessayer.${NC}" ;;
    esac
    
    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
    clear
    show_menu
}

# Rendre le script exécutable
chmod +x manage.sh

# Démarrer le menu
clear
show_menu
