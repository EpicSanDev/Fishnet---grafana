# Fishnet Monitoring Dashboard

Ce projet permet de surveiller vos serveurs Fishnet pour Lichess en utilisant une pile de surveillance complète basée sur Prometheus et Grafana.

## Caractéristiques

- **Surveillance Fishnet complète** : métriques spécifiques pour suivre les nœuds connectés, les analyses par seconde, les files d'attente, etc.
- **Métriques système** : surveillance des ressources du serveur (CPU, mémoire, disque, réseau)
- **Tout containerisé** : la solution complète s'exécute dans Docker pour faciliter le déploiement
- **Tableaux de bord pré-configurés** : des tableaux de bord Grafana prêts à l'emploi
- **Alertes intégrées** : notifications automatiques en cas de problème
- **Interface CLI** : consultez rapidement l'état de vos serveurs depuis la ligne de commande
- **Architecture distribuée** : collectez les métriques de plusieurs serveurs Fishnet et centralisez-les sur un seul serveur de statistiques

## Prérequis

- Docker
- Docker Compose

## Démarrage rapide

```bash
./quick-start.sh
```

Le script de démarrage rapide effectue toutes les étapes nécessaires pour configurer et lancer le dashboard.

## Architecture distribuée

Pour une infrastructure avec plusieurs serveurs Fishnet, vous pouvez utiliser l'architecture distribuée qui permet de:

- Collecter les métriques de tous vos serveurs Fishnet
- Centraliser toutes les métriques sur un serveur principal
- Visualiser l'ensemble de votre infrastructure sur un seul tableau de bord

Pour démarrer avec l'architecture distribuée:

```bash
./distributed-start.sh
```

Pour plus de détails, consultez le [Guide d'utilisation de l'architecture distribuée](DISTRIBUTED_GUIDE.md).

## Configuration manuelle

1. **Configurer les serveurs Fishnet** :
   - Modifier le fichier `/config/fishnet_config.yaml` pour ajouter vos propres serveurs Fishnet.
   - Ajouter votre clé API Lichess et configurer les URL de vos serveurs Fishnet.

2. **Démarrer les services**:
```bash
docker-compose up -d
```

## Accès aux tableaux de bord

- **Grafana** : http://localhost:3000 (identifiants par défaut : admin/admin)
- **Prometheus** : http://localhost:9090

## Utilitaires inclus

### Script de gestion

Le script `manage.sh` permet de :
- Démarrer/arrêter/redémarrer les services
- Afficher les logs
- Vérifier l'état des services
- Mettre à jour les images Docker

```bash
./manage.sh
```

### Client CLI Fishnet

Pour vérifier rapidement l'état de vos serveurs Fishnet en ligne de commande :

```bash
./fishnet-exporter/fishnet_cli.py
```

Options disponibles :
- `-s, --server NOM` : vérifier un serveur spécifique
- `-j, --json` : afficher la sortie au format JSON brut

## Tableaux de bord disponibles

1. **Fishnet Dashboard** : surveillance spécifique des serveurs Fishnet
   - Nœuds connectés
   - Statut des serveurs
   - Jobs en file d'attente
   - Analyses par seconde
   - Temps de calcul par profondeur
   - Jobs complétés

2. **System Resources** : surveillance des ressources système
   - Utilisation CPU
   - Utilisation mémoire
   - Utilisation disque
   - Trafic réseau

## Alertes

Le système inclut des alertes préconfigurées pour :
- Serveurs Fishnet hors ligne
- Files d'attente trop chargées
- Nombre insuffisant de nœuds connectés
- Baisse du taux d'analyse

Les seuils d'alerte peuvent être personnalisés dans le fichier `prometheus/alert_rules.yml`.

## Structure du projet

```
.
├── docker-compose.yml        # Configuration Docker Compose
├── quick-start.sh            # Script de démarrage rapide
├── manage.sh                 # Script de gestion des services
├── config/
│   └── fishnet_config.yaml   # Configuration des serveurs Fishnet
├── prometheus/
│   ├── prometheus.yml        # Configuration Prometheus
│   └── alert_rules.yml       # Règles d'alerte
├── grafana/
│   ├── provisioning/         # Configuration auto-provisionnement
│   │   ├── datasources/      # Sources de données
│   │   └── dashboards/       # Configuration des tableaux de bord
│   └── dashboards/           # Définitions des tableaux de bord
├── node-exporter/            # Collecte des métriques système
└── fishnet-exporter/         # Collecteur spécifique pour Fishnet
    ├── Dockerfile
    ├── fishnet_exporter.py   # Script d'exportation des métriques
    ├── fishnet_cli.py        # Outil CLI
    └── requirements.txt      # Dépendances Python
```

## Personnalisation

Pour ajouter plus de serveurs Fishnet à surveiller, modifiez le fichier `config/fishnet_config.yaml` :

```yaml
servers:
  - name: lichess-main
    url: https://lichess.org/api/fishnet/status
    key: YOUR_LICHESS_API_KEY_HERE
  - name: lichess-secondary
    url: https://second-instance.example.com/api/fishnet/status
    key: YOUR_SECOND_API_KEY_HERE
```

## Notes importantes

- Les clés API Fishnet doivent avoir les permissions suffisantes pour accéder aux statistiques.
- Pour une utilisation en production, il est recommandé de changer les identifiants Grafana par défaut.
- Les métriques sont collectées toutes les 60 secondes par défaut, ce paramètre peut être ajusté dans le fichier de configuration.
