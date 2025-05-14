#!/usr/bin/env python3
"""
Fishnet CLI Status Tool
Ce script permet de consulter l'état des serveurs Fishnet en ligne de commande
"""

import argparse
import yaml
import json
import requests
import os
import sys
from tabulate import tabulate
from colorama import Fore, Style, init

# Initialisation de colorama
init()

def load_config():
    """Charge la configuration depuis le fichier YAML"""
    config_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 
                               'config', 'fishnet_config.yaml')
    try:
        with open(config_path, 'r') as file:
            return yaml.safe_load(file)
    except Exception as e:
        print(f"{Fore.RED}Erreur lors du chargement de la configuration: {e}{Style.RESET_ALL}")
        return None

def get_server_status(server):
    """Récupère le statut d'un serveur Fishnet"""
    server_name = server['name']
    server_url = server['url']
    api_key = server.get('key', '')
    
    print(f"{Fore.BLUE}Interrogation du serveur {server_name}...{Style.RESET_ALL}")
    
    try:
        headers = {}
        if api_key:
            headers['Authorization'] = f'Bearer {api_key}'
            
        response = requests.get(server_url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            return response.json()
        else:
            print(f"{Fore.RED}Erreur HTTP {response.status_code} pour {server_name}{Style.RESET_ALL}")
            return None
    except Exception as e:
        print(f"{Fore.RED}Erreur de connexion à {server_name}: {e}{Style.RESET_ALL}")
        return None

def format_nodes_info(data):
    """Affiche les informations sur les nœuds connectés"""
    print(f"\n{Fore.GREEN}=== Nœuds connectés ==={Style.RESET_ALL}")
    print(f"Total: {Fore.YELLOW}{data.get('nodes', 0)}{Style.RESET_ALL} nœuds")

def format_queue_info(data):
    """Affiche les informations sur les files d'attente"""
    print(f"\n{Fore.GREEN}=== Files d'attente ==={Style.RESET_ALL}")
    queue = data.get('queue', {})
    
    if not queue:
        print("Aucune information de file d'attente disponible")
        return
    
    table_data = []
    for job_type, count in queue.items():
        table_data.append([job_type, count])
    
    print(tabulate(table_data, headers=["Type de job", "Nombre en attente"], tablefmt="simple"))

def format_performance_info(data):
    """Affiche les informations de performance"""
    print(f"\n{Fore.GREEN}=== Performance ==={Style.RESET_ALL}")
    perf = data.get('performance', {})
    
    if not perf:
        print("Aucune information de performance disponible")
        return
    
    print(f"Analyses par seconde: {Fore.YELLOW}{perf.get('analyses_per_second', 0):.2f}{Style.RESET_ALL}")
    
    move_times = perf.get('move_time', {})
    if move_times:
        print("\nTemps de calcul par profondeur:")
        table_data = []
        for depth, time_ms in move_times.items():
            table_data.append([depth, f"{time_ms} ms"])
        
        print(tabulate(table_data, headers=["Profondeur", "Temps moyen"], tablefmt="simple"))

def format_client_info(data):
    """Affiche les informations sur les clients connectés"""
    print(f"\n{Fore.GREEN}=== Clients connectés ==={Style.RESET_ALL}")
    clients = data.get('clients', {})
    
    if not clients:
        print("Aucun client connecté")
        return
    
    table_data = []
    for client_id, info in clients.items():
        table_data.append([
            client_id[:8] + "..." if len(client_id) > 10 else client_id,
            info.get('version', 'inconnu'),
            info.get('engine', 'inconnu'),
            info.get('cores', 'inconnu'),
            info.get('memory', 'inconnu')
        ])
    
    print(tabulate(table_data, 
                  headers=["ID Client", "Version", "Moteur", "Cœurs", "Mémoire"], 
                  tablefmt="simple"))

def format_jobs_info(data):
    """Affiche les informations sur les jobs traités"""
    print(f"\n{Fore.GREEN}=== Statistiques des jobs ==={Style.RESET_ALL}")
    jobs = data.get('jobs', {})
    
    if not jobs:
        print("Aucune information sur les jobs disponible")
        return
    
    # Jobs complétés
    completed = jobs.get('completed', {})
    if completed:
        print(f"\n{Fore.CYAN}Jobs complétés:{Style.RESET_ALL}")
        table_data = []
        for job_type, count in completed.items():
            table_data.append([job_type, count])
        
        print(tabulate(table_data, headers=["Type", "Nombre"], tablefmt="simple"))
    
    # Jobs rejetés
    rejected = jobs.get('rejected', {})
    if rejected:
        print(f"\n{Fore.CYAN}Jobs rejetés:{Style.RESET_ALL}")
        table_data = []
        for job_type, count in rejected.items():
            table_data.append([job_type, count])
        
        print(tabulate(table_data, headers=["Type", "Nombre"], tablefmt="simple"))

def display_server_status(server_name, data):
    """Affiche le statut complet d'un serveur Fishnet"""
    print(f"\n{Fore.GREEN}{'=' * 50}{Style.RESET_ALL}")
    print(f"{Fore.GREEN}Statut du serveur: {Fore.YELLOW}{server_name}{Style.RESET_ALL}")
    print(f"{Fore.GREEN}{'=' * 50}{Style.RESET_ALL}")
    
    if not data:
        print(f"{Fore.RED}Aucune donnée disponible pour ce serveur{Style.RESET_ALL}")
        return
    
    # Afficher les informations organisées par section
    format_nodes_info(data)
    format_queue_info(data)
    format_performance_info(data)
    format_client_info(data)
    format_jobs_info(data)

def main():
    parser = argparse.ArgumentParser(description='Outil CLI pour visualiser le statut des serveurs Fishnet')
    parser.add_argument('-s', '--server', help='Nom du serveur spécifique à vérifier')
    parser.add_argument('-j', '--json', action='store_true', help='Afficher la sortie au format JSON brut')
    args = parser.parse_args()
    
    config = load_config()
    if not config:
        sys.exit(1)
    
    servers = config.get('servers', [])
    if not servers:
        print(f"{Fore.RED}Aucun serveur configuré{Style.RESET_ALL}")
        sys.exit(1)
    
    if args.server:
        # Vérifier un serveur spécifique
        server_found = False
        for server in servers:
            if server['name'] == args.server:
                server_found = True
                data = get_server_status(server)
                
                if args.json and data:
                    print(json.dumps(data, indent=4))
                else:
                    display_server_status(server['name'], data)
                break
        
        if not server_found:
            print(f"{Fore.RED}Serveur '{args.server}' non trouvé dans la configuration{Style.RESET_ALL}")
            print(f"{Fore.YELLOW}Serveurs disponibles: {', '.join([s['name'] for s in servers])}{Style.RESET_ALL}")
    else:
        # Vérifier tous les serveurs
        for server in servers:
            data = get_server_status(server)
            
            if args.json and data:
                print(f"\n{Fore.YELLOW}{server['name']}:{Style.RESET_ALL}")
                print(json.dumps(data, indent=4))
            else:
                display_server_status(server['name'], data)

if __name__ == '__main__':
    main()
