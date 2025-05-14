# Guide d'utilisation de l'architecture distribuée Fishnet

Ce guide explique comment configurer et utiliser l'architecture de monitoring Fishnet distribuée, qui permet de centraliser les métriques de plusieurs serveurs Fishnet sur un serveur central de statistiques.

## Architecture

L'architecture distribuée se compose de:

1. **Serveur central** - Un serveur qui héberge:
   - Prometheus (pour le stockage des métriques)
   - Grafana (pour la visualisation)
   - Serveur de métriques Fishnet (pour collecter et centraliser les métriques)

2. **Serveurs clients** - Plusieurs serveurs qui exécutent:
   - Des instances Fishnet
   - Un client de métriques qui envoie les statistiques au serveur central

## Installation du serveur central

### Prérequis
- Docker et Docker Compose
- Adresse IP accessible depuis les serveurs clients

### Configuration

1. Clonez le dépôt sur le serveur central:
   ```
   git clone <repository-url> fishnet-monitoring
   cd fishnet-monitoring
   ```

2. Configurez l'adresse IP du serveur central et la clé d'authentification:
   ```
   ./prepare-distribution.sh <adresse-ip-serveur> <clé-auth-optionnelle>
   ```
   
   Ce script va:
   - Configurer le serveur central avec la clé d'authentification spécifiée
   - Préparer une archive pour distribuer aux clients
   - Vous fournir des instructions pour installer les clients

3. Démarrez le serveur central:
   ```
   ./distributed-start.sh
   ```

4. Accédez à:
   - Grafana: http://<adresse-ip-serveur>:3000 (utilisateur: admin, mot de passe: admin)
   - Prometheus: http://<adresse-ip-serveur>:9090
   - Métriques Fishnet: http://<adresse-ip-serveur>:9101/metrics

## Installation des clients

Il existe deux méthodes pour installer les clients:

### Méthode 1: Distribution d'archive

1. Copiez l'archive `fishnet-client-dist.tar.gz` générée par le script `prepare-distribution.sh` sur chaque serveur client.

2. Sur chaque serveur client, exécutez:
   ```
   tar -xzvf fishnet-client-dist.tar.gz
   ./install-client.sh <node-id> <votre-clé-api-fishnet>
   ```
   
   Où:
   - `<node-id>` est un identifiant unique pour ce serveur (par exemple "serveur1", "serveur2", etc.)
   - `<votre-clé-api-fishnet>` est votre clé API Fishnet pour ce serveur

### Méthode 2: Utilisation du script setup-client.sh

Sur le serveur central, vous pouvez utiliser le script `setup-client.sh` pour configurer un client à distance:

```
./setup-client.sh <node-id> <adresse-ip-serveur-central> <votre-clé-api-fishnet>
```

Ce script nécessite un accès SSH au serveur client.

## Monitoring et maintenance

### Tableau de bord Grafana

Après l'installation, accédez à Grafana (http://<adresse-ip-serveur>:3000) et utilisez le tableau de bord "Fishnet Distributed Monitoring" pour visualiser:

- Nombre total de serveurs Fishnet en ligne
- Nombre total de nœuds connectés
- Analyses par seconde globales
- Jobs dans la file d'attente
- Status de chaque serveur
- Graphiques détaillés par serveur

### Ajout d'un nouveau serveur client

Pour ajouter un nouveau serveur client à l'infrastructure:

1. Générez une nouvelle distribution si nécessaire:
   ```
   ./prepare-distribution.sh <adresse-ip-serveur> <clé-auth>
   ```

2. Installez le client sur le nouveau serveur (voir la section "Installation des clients")

3. Les métriques du nouveau serveur apparaîtront automatiquement dans le tableau de bord Grafana

### Troubleshooting

Si un client ne se connecte pas au serveur central:

1. Vérifiez que le client peut accéder au serveur central:
   ```
   curl http://<adresse-ip-serveur-central>:9101/metrics
   ```

2. Vérifiez les logs du client:
   ```
   docker-compose logs -f
   ```

3. Vérifiez que la clé d'authentification configurée dans le client correspond à celle configurée sur le serveur central

4. Assurez-vous que les ports nécessaires sont ouverts dans votre pare-feu:
   - Port 9101 pour le serveur de métriques

## Configuration avancée

### Personnalisation des métriques collectées

Vous pouvez personnaliser les métriques collectées en modifiant le fichier `fishnet_exporter_modified.py`.

### Sécurisation avec HTTPS

Pour sécuriser les communications avec HTTPS, vous pouvez configurer un proxy inverse comme Nginx devant le serveur de métriques.
