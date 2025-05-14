#!/bin/bash

# Script pour démarrer l'infrastructure Fishnet distribuée

# Variables
PROMETHEUS_CONFIG="prometheus/prometheus-distributed.yml"
PROMETHEUS_TARGET="prometheus/prometheus.yml"
EXPORTER_SCRIPT="fishnet-exporter/fishnet_exporter_modified.py"
DOCKER_COMPOSE="docker-compose-distributed.yml"

# Afficher une bannière
echo "==============================================="
echo "   Fishnet Monitoring - Architecture Distribuée   "
echo "==============================================="
echo ""

# Vérifier si Docker est installé
if ! command -v docker &> /dev/null
then
    echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Vérifier si Docker Compose est installé
if ! command -v docker-compose &> /dev/null
then
    echo "❌ Docker Compose n'est pas installé. Veuillez l'installer avant de continuer."
    exit 1
fi

# Vérifier les fichiers nécessaires
echo "🔍 Vérification des fichiers nécessaires..."

if [ ! -f "$PROMETHEUS_CONFIG" ]; then
    echo "❌ Fichier $PROMETHEUS_CONFIG introuvable."
    exit 1
fi

if [ ! -f "$EXPORTER_SCRIPT" ]; then
    echo "❌ Fichier $EXPORTER_SCRIPT introuvable."
    exit 1
fi

if [ ! -f "$DOCKER_COMPOSE" ]; then
    echo "❌ Fichier $DOCKER_COMPOSE introuvable."
    exit 1
fi

echo "✅ Tous les fichiers nécessaires sont présents."

# Copier le fichier prometheus-distributed.yml vers prometheus.yml
echo "📋 Configuration de Prometheus..."
cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_TARGET"

# Remplacer les noms d'hôtes internes par l'adresse IP dans la configuration de Prometheus
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - Récupérer l'IP avant pour la substitution
    SERVER_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")
    
    # Copier le fichier de configuration original
    cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_TARGET"
    
    # Remplacer les noms d'hôtes par l'IP du serveur dans prometheus.yml
    sed -i '' "s/targets: \['localhost:9090'\]/targets: \['$SERVER_IP:9090'\]/g" "$PROMETHEUS_TARGET"
    sed -i '' "s/targets: \['node-exporter:9100'\]/targets: \['$SERVER_IP:9100'\]/g" "$PROMETHEUS_TARGET"
    sed -i '' "s/targets: \['fishnet-stats-server:9101'\]/targets: \['$SERVER_IP:9101'\]/g" "$PROMETHEUS_TARGET"
else
    # Linux - Récupérer l'IP avant pour la substitution
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    # Copier le fichier de configuration original
    cp "$PROMETHEUS_CONFIG" "$PROMETHEUS_TARGET"
    
    # Remplacer les noms d'hôtes par l'IP du serveur dans prometheus.yml
    sed -i "s/targets: \['localhost:9090'\]/targets: \['$SERVER_IP:9090'\]/g" "$PROMETHEUS_TARGET"
    sed -i "s/targets: \['node-exporter:9100'\]/targets: \['$SERVER_IP:9100'\]/g" "$PROMETHEUS_TARGET"
    sed -i "s/targets: \['fishnet-stats-server:9101'\]/targets: \['$SERVER_IP:9101'\]/g" "$PROMETHEUS_TARGET"
fi

echo "✅ Fichier de configuration Prometheus copié et URLs mises à jour avec l'IP du serveur: $SERVER_IP"

# Vérifier si les répertoires de data existent, sinon les créer
echo "📁 Vérification des répertoires de données..."
mkdir -p prometheus/data
mkdir -p grafana/data
echo "✅ Répertoires de données vérifiés."

# Rendre le fichier fishnet_exporter_modified.py exécutable
echo "🔧 Configuration des permissions..."
chmod +x "$EXPORTER_SCRIPT"
echo "✅ Permissions configurées."

# Arrêter les conteneurs existants si demandé ou par défaut dans le mode distribué
echo "🛑 Arrêt des conteneurs existants..."
docker-compose -f "$DOCKER_COMPOSE" down
echo "✅ Conteneurs arrêtés."

# Mettre à jour l'URL de Prometheus dans la configuration Grafana
echo "🔄 Mise à jour de la configuration de la source de données Grafana..."

# Créer ou mettre à jour la configuration prometheus.yml pour Grafana
cat > grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://$SERVER_IP:9090
    isDefault: true
    editable: true
EOF

echo "✅ URL de Prometheus mise à jour dans la configuration Grafana avec l'IP: $SERVER_IP"

# S'assurer que le chemin des dashboards est correct
echo "🔄 Mise à jour de la configuration des dashboards Grafana..."
cat > grafana/provisioning/dashboards/fishnet.yml << EOF
apiVersion: 1

providers:
  - name: 'Fishnet'
    orgId: 1
    folder: 'Fishnet'
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Copier les fichiers de dashboard
echo "📋 Copie des dashboards..."
mkdir -p grafana/dashboards
cp -f grafana/provisioning/dashboards/dashboards/*.json grafana/dashboards/ 2>/dev/null || true

echo "✅ Configuration des dashboards mise à jour"

# Supprimer le dossier de données Grafana pour forcer une réinitialisation des datasources
echo "🧹 Nettoyage du dossier de données Grafana pour appliquer les nouvelles configurations..."
rm -rf grafana/data/*
echo "✅ Dossier de données Grafana nettoyé."

# Lancer l'infrastructure avec Docker Compose
echo "🚀 Démarrage de l'infrastructure..."
docker-compose -f "$DOCKER_COMPOSE" up -d

# Vérifier que tous les conteneurs sont en cours d'exécution
echo "🔍 Vérification du statut des conteneurs..."
EXPECTED_CONTAINERS=("prometheus" "grafana" "node-exporter" "fishnet-stats-server" "fishnet-client-1" "fishnet-client-2")
ALL_UP=true

for container in "${EXPECTED_CONTAINERS[@]}"; do
    status=$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null)
    if [ "$status" != "true" ]; then
        echo "❌ Le conteneur $container n'est pas en cours d'exécution."
        ALL_UP=false
    fi
done

if [ "$ALL_UP" = true ]; then
    echo "✅ Tous les conteneurs sont en cours d'exécution."
else
    echo "⚠️ Certains conteneurs ne sont pas en cours d'exécution. Consultez les logs pour plus d'informations."
    echo "   docker-compose -f $DOCKER_COMPOSE logs"
fi

# L'adresse IP du serveur a déjà été récupérée plus tôt (SERVER_IP)

echo ""
echo "✅ Fishnet Monitoring Infrastructure (Distributed) est en cours d'exécution!"
echo ""
echo "📊 Accès aux interfaces:"
echo "- Grafana: http://$SERVER_IP:3000 (utilisateur: admin, mot de passe: admin)"
echo "- Prometheus: http://$SERVER_IP:9090"
echo "- Métriques Fishnet: http://$SERVER_IP:9101/metrics"
echo ""
echo "📝 Le serveur central de métriques est accessible sur le port 9101"
echo ""
echo "🛠️ Commandes utiles:"
echo "- Voir les logs: docker-compose -f $DOCKER_COMPOSE logs -f"
echo "- Arrêter tous les services: docker-compose -f $DOCKER_COMPOSE down"
echo "- Préparer la distribution pour les clients: ./prepare-distribution.sh $SERVER_IP"
echo ""
echo "📘 Pour plus d'informations, consultez le guide: DISTRIBUTED_GUIDE.md"
