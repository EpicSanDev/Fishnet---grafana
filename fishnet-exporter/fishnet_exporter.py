#!/usr/bin/env python3
"""
Fishnet Exporter for Prometheus
This script queries the Fishnet API to collect metrics about your Fishnet instances
and exposes them for Prometheus to scrape.
"""

import time
import yaml
import json
import logging
import requests
import threading
import schedule
from prometheus_client import start_http_server, Gauge, Counter

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('fishnet-exporter')

# Prometheus metrics
FISHNET_UP = Gauge('fishnet_up', 'Status of Fishnet instance', ['instance'])
FISHNET_NODES = Gauge('fishnet_nodes_total', 'Number of connected nodes', ['instance'])
FISHNET_JOBS_QUEUED = Gauge('fishnet_jobs_queued', 'Number of jobs in queue', ['instance', 'job_type'])
FISHNET_JOBS_COMPLETED = Counter('fishnet_jobs_completed_total', 'Total number of completed jobs', ['instance', 'job_type'])
FISHNET_JOBS_REJECTED = Counter('fishnet_jobs_rejected_total', 'Total number of rejected jobs', ['instance', 'job_type'])
FISHNET_CLIENT_VERSION = Gauge('fishnet_client_version', 'Version information for each client', ['instance', 'client_id', 'version'])
FISHNET_ANALYSES_SECOND = Gauge('fishnet_analyses_per_second', 'Analyses per second', ['instance'])
FISHNET_MOVE_TIME = Gauge('fishnet_move_time_ms', 'Average time per move in milliseconds', ['instance', 'depth'])

# Default configuration
DEFAULT_CONFIG = {
    'servers': [
        {
            'name': 'main',
            'url': 'https://lichess.org/api/fishnet/status',
            'key': 'YOUR_API_KEY'
        }
    ],
    'exporter': {
        'port': 9101,
        'scrape_interval': 60
    }
}

def load_config():
    """Load configuration from YAML file"""
    try:
        with open('/app/config/fishnet_config.yaml', 'r') as file:
            config = yaml.safe_load(file)
            logger.info("Configuration loaded successfully")
            return config
    except Exception as e:
        logger.warning(f"Error loading config: {e}. Using default configuration")
        return DEFAULT_CONFIG

def collect_metrics():
    """Collect metrics from all configured Fishnet servers"""
    config = load_config()
    
    for server in config['servers']:
        server_name = server['name']
        server_url = server['url']
        api_key = server.get('key', '')
        
        try:
            headers = {}
            if api_key:
                headers['Authorization'] = f'Bearer {api_key}'
                
            response = requests.get(server_url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                FISHNET_UP.labels(instance=server_name).set(1)
                data = response.json()
                
                # Parse and record metrics
                FISHNET_NODES.labels(instance=server_name).set(data.get('nodes', 0))
                
                # Queue stats
                for job_type, count in data.get('queue', {}).items():
                    FISHNET_JOBS_QUEUED.labels(instance=server_name, job_type=job_type).set(count)
                
                # Job stats - these are counters so we need to calculate the delta
                for job_type, count in data.get('jobs', {}).get('completed', {}).items():
                    FISHNET_JOBS_COMPLETED.labels(instance=server_name, job_type=job_type).inc(count)
                
                for job_type, count in data.get('jobs', {}).get('rejected', {}).items():
                    FISHNET_JOBS_REJECTED.labels(instance=server_name, job_type=job_type).inc(count)
                
                # Client versions
                for client_id, info in data.get('clients', {}).items():
                    FISHNET_CLIENT_VERSION.labels(
                        instance=server_name,
                        client_id=client_id,
                        version=info.get('version', 'unknown')
                    ).set(1)
                
                # Performance metrics
                FISHNET_ANALYSES_SECOND.labels(instance=server_name).set(
                    data.get('performance', {}).get('analyses_per_second', 0)
                )
                
                # Move time at different depths
                for depth, time_ms in data.get('performance', {}).get('move_time', {}).items():
                    FISHNET_MOVE_TIME.labels(instance=server_name, depth=depth).set(time_ms)
                
                logger.info(f"Successfully collected metrics from {server_name}")
            else:
                FISHNET_UP.labels(instance=server_name).set(0)
                logger.warning(f"Failed to collect metrics from {server_name}: HTTP {response.status_code}")
                
        except Exception as e:
            FISHNET_UP.labels(instance=server_name).set(0)
            logger.error(f"Error collecting metrics from {server_name}: {e}")

def schedule_collector():
    """Schedule the metrics collector to run at regular intervals"""
    config = load_config()
    interval = config['exporter']['scrape_interval']
    
    # Collect immediately on startup
    collect_metrics()
    
    # Then schedule regular collection
    schedule.every(interval).seconds.do(collect_metrics)
    
    while True:
        schedule.run_pending()
        time.sleep(1)

def main():
    """Main function to start the exporter"""
    config = load_config()
    port = config['exporter']['port']
    
    # Start the HTTP server to expose metrics
    start_http_server(port)
    logger.info(f"Fishnet exporter started on port {port}")
    
    # Start the collector in a separate thread
    collector_thread = threading.Thread(target=schedule_collector)
    collector_thread.daemon = True
    collector_thread.start()
    
    # Keep the main thread running
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
