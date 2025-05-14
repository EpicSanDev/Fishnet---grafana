#!/bin/bash

# Script pour configurer un client Fishnet sur un nouveau serveur

# Paramètres
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <node_id> <central_server_ip> [api_key]"
    echo "  node_id: Identifiant unique pour ce nœud"
    echo "  central_server_ip: Adresse IP du serveur central de métriques"
    echo "  api_key: (Optionnel) Clé API Fishnet pour ce serveur"
    exit 1
fi

NODE_ID=$1
CENTRAL_SERVER_IP=$2
API_KEY=${3:-"YOUR_API_KEY_HERE"}

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null
then
    echo "Docker n'est pas installé. Installation..."
    
    # Installer Docker
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Ajouter l'utilisateur actuel au groupe docker
    sudo usermod -aG docker $USER
    echo "Docker installé. Veuillez vous déconnecter et vous reconnecter pour appliquer les modifications de groupe."
    exit 0
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose n'est pas installé. Installation..."
    
    # Installer Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    echo "Docker Compose installé."
fi

# Créer les répertoires nécessaires
mkdir -p fishnet-exporter
mkdir -p config

# Télécharger les fichiers nécessaires du serveur central
echo "Téléchargement des fichiers depuis le serveur central..."

# Télécharger le Dockerfile et les scripts
scp -r user@${CENTRAL_SERVER_IP}:/Users/bastienjavaux/Desktop/MCP/Fishnet/fishnet-exporter .

# Télécharger le template de configuration client
scp user@${CENTRAL_SERVER_IP}:/Users/bastienjavaux/Desktop/MCP/Fishnet/config/client_template_config.yaml ./config/

# Télécharger le docker-compose pour client
scp user@${CENTRAL_SERVER_IP}:/Users/bastienjavaux/Desktop/MCP/Fishnet/docker-compose-client.yml ./docker-compose.yml

# Configurer le client
echo "Configuration du client..."

# Remplacer les valeurs dans le template
sed -e "s/NODE_ID/$NODE_ID/g" \
    -e "s/CENTRAL_SERVER_IP/$CENTRAL_SERVER_IP/g" \
    -e "s/YOUR_API_KEY_HERE/$API_KEY/g" \
    ./config/client_template_config.yaml > ./config/client_config.yaml

# Démarrer les services
echo "Démarrage des services..."
docker-compose up -d

echo ""
echo "Client Fishnet configuré et démarré!"
echo "Ce client est configuré pour envoyer ses métriques au serveur central: $CENTRAL_SERVER_IP"
echo ""
echo "Pour vérifier l'état des services: docker-compose ps"
echo "Pour voir les logs: docker-compose logs -f"
echo "Pour arrêter les services: docker-compose down"
