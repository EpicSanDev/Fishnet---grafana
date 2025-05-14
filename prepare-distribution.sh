#!/bin/bash

# Script pour préparer la distribution des clients Fishnet
# Ce script doit être exécuté sur le serveur central

# Paramètres
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <central_server_ip> [auth_key]"
    echo "  central_server_ip: Adresse IP publique du serveur central"
    echo "  auth_key: (Optionnel) Clé d'authentification pour sécuriser les communications"
    exit 1
fi

CENTRAL_SERVER_IP=$1
AUTH_KEY=${2:-"votre_cle_secrete"}

# Mettre à jour la configuration du serveur central
echo "Mise à jour de la configuration du serveur central..."

# Remplacer la clé d'authentification dans la configuration du serveur central
sed -i '' "s/auth_key: '.*'/auth_key: '$AUTH_KEY'/g" ./config/stats_server_config.yaml

# Mettre à jour le template client avec la nouvelle clé d'authentification
echo "Mise à jour du template client..."
sed -i '' "s/auth_key: '.*'/auth_key: '$AUTH_KEY'/g" ./config/client_template_config.yaml

# Préparation de l'archive pour la distribution
echo "Préparation de l'archive pour distribution..."

mkdir -p ./dist
rm -rf ./dist/*

# Copier les fichiers nécessaires pour les clients
cp -r ./fishnet-exporter ./dist/
cp ./docker-compose-client.yml ./dist/docker-compose.yml
cp ./config/client_template_config.yaml ./dist/

# Créer le script d'installation pour le client
cat << EOF > ./dist/install-client.sh
#!/bin/bash

# Script d'installation pour un client Fishnet

# Paramètres
if [ "\$#" -lt 1 ]; then
    echo "Usage: \$0 <node_id> [api_key]"
    echo "  node_id: Identifiant unique pour ce nœud"
    echo "  api_key: (Optionnel) Clé API Fishnet pour ce serveur"
    exit 1
fi

NODE_ID=\$1
CENTRAL_SERVER_IP=$CENTRAL_SERVER_IP
API_KEY=\${2:-"YOUR_API_KEY_HERE"}

# Créer les répertoires nécessaires
mkdir -p config

# Configurer le client
echo "Configuration du client..."

# Remplacer les valeurs dans le template
sed -e "s/NODE_ID/\$NODE_ID/g" \\
    -e "s/CENTRAL_SERVER_IP/\$CENTRAL_SERVER_IP/g" \\
    -e "s/YOUR_API_KEY_HERE/\$API_KEY/g" \\
    ./client_template_config.yaml > ./config/client_config.yaml

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null
then
    echo "Docker n'est pas installé. Installation..."
    
    # Installer Docker (pour Ubuntu/Debian)
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Ajouter l'utilisateur actuel au groupe docker
    sudo usermod -aG docker \$USER
    echo "Docker installé. Veuillez vous déconnecter et vous reconnecter pour appliquer les modifications de groupe."
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose n'est pas installé. Installation..."
    
    # Installer Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    echo "Docker Compose installé."
fi

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
EOF

chmod +x ./dist/install-client.sh

# Créer une archive pour faciliter la distribution
tar -czvf fishnet-client-dist.tar.gz -C ./dist .

echo ""
echo "Distribution prête: fishnet-client-dist.tar.gz"
echo ""
echo "Pour installer sur un nouveau serveur:"
echo "1. Copiez fishnet-client-dist.tar.gz sur le serveur"
echo "2. Extrayez avec: tar -xzvf fishnet-client-dist.tar.gz"
echo "3. Exécutez: ./install-client.sh <node_id> [api_key]"
echo ""
echo "Serveur central configuré avec:"
echo "- Adresse IP: $CENTRAL_SERVER_IP"
echo "- Clé d'authentification: $AUTH_KEY"
