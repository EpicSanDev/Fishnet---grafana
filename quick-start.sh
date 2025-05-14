#!/bin/bash

# Script de démarrage rapide pour Fishnet Monitoring Dashboard
# Ce script effectue toutes les étapes nécessaires pour démarrer rapidement
# le dashboard de monitoring Fishnet

# Couleurs pour une meilleure lisibilité
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Script de démarrage rapide - Fishnet Monitoring Dashboard ===${NC}"

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker n'est pas installé. Installation requise avant de continuer.${NC}"
    echo -e "Visitez ${BLUE}https://docs.docker.com/get-docker/${NC} pour les instructions d'installation."
    exit 1
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose n'est pas installé. Installation requise avant de continuer.${NC}"
    echo -e "Visitez ${BLUE}https://docs.docker.com/compose/install/${NC} pour les instructions d'installation."
    exit 1
fi

# Vérifier la configuration de l'API key
CONFIG_FILE="./config/fishnet_config.yaml"
if grep -q "YOUR_LICHESS_API_KEY_HERE" "$CONFIG_FILE"; then
    echo -e "${YELLOW}Configuration de l'API Lichess${NC}"
    echo -e "La clé API par défaut est détectée dans votre fichier de configuration."
    echo -e "Voulez-vous configurer votre clé API Lichess maintenant? (o/n)"
    read -r response
    if [[ "$response" =~ ^([oO][uU][iI]|[oO])$ ]]; then
        echo -e "Entrez votre clé API Lichess:"
        read -r api_key
        if [[ -n "$api_key" ]]; then
            sed -i '' "s/YOUR_LICHESS_API_KEY_HERE/$api_key/g" "$CONFIG_FILE"
            echo -e "${GREEN}Clé API configurée avec succès.${NC}"
        else
            echo -e "${YELLOW}Aucune clé fournie. Conservation de la valeur par défaut.${NC}"
        fi
    else
        echo -e "${YELLOW}Conservation de la valeur par défaut. N'oubliez pas de la mettre à jour dans $CONFIG_FILE.${NC}"
    fi
fi

# Démarrer les conteneurs Docker
echo -e "${BLUE}Démarrage des services Docker...${NC}"
docker-compose up -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Démarrage réussi! Votre dashboard Fishnet est maintenant accessible.${NC}"
    echo -e "${YELLOW}URLs d'accès:${NC}"
    echo -e "  - Grafana: ${BLUE}http://localhost:3000${NC} (identifiants: admin/admin)"
    echo -e "  - Prometheus: ${BLUE}http://localhost:9090${NC}"
    echo -e "\n${YELLOW}Pour gérer les services, utilisez:${NC} ./manage.sh"
    echo -e "${YELLOW}Pour vérifier l'état des serveurs Fishnet en ligne de commande:${NC} ./fishnet-exporter/fishnet_cli.py"
else
    echo -e "${RED}Une erreur s'est produite lors du démarrage des services.${NC}"
    echo -e "Consultez les logs pour plus d'informations: ${BLUE}docker-compose logs${NC}"
fi

echo -e "\n${YELLOW}Astuce:${NC} Pour des raisons de sécurité, pensez à changer le mot de passe par défaut de Grafana."
