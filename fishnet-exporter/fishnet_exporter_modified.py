#!/usr/bin/env python3
"""
Fishnet Exporter for Prometheus
This script queries the Fishnet API to collect metrics about your Fishnet instances
and exposes them for Prometheus to scrape. It can run in two modes:
- Central mode: Collects metrics from Fishnet servers and also receives metrics from client instances
- Client mode: Collects metrics from Fishnet servers and pushes them to a central server
"""

import time
import yaml
import json
import logging
import requests
import threading
import schedule
from flask import Flask, request, jsonify, Response
from prometheus_client import start_http_server, Gauge, Counter, generate_latest, REGISTRY
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from prometheus_client.exposition import make_wsgi_app

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
    },
    'metrics_server': {
        'enabled': False,
        'mode': 'central',
        'central_url': 'http://stats-server:9101/metrics/push',
        'auth_key': ''
    }
}

# Flask app for handling API requests (only used in central mode)
app = Flask(__name__)
app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {
    '/metrics': make_wsgi_app()
})

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

def push_to_central(metrics):
    """Push collected metrics to the central server"""
    config = load_config()
    central_url = config['metrics_server']['central_url']
    auth_key = config['metrics_server'].get('auth_key', '')
    
    headers = {'Content-Type': 'text/plain'}
    if auth_key:
        headers['Authorization'] = f'Bearer {auth_key}'
    
    try:
        response = requests.post(central_url, data=metrics, headers=headers, timeout=10)
        if response.status_code == 200:
            logger.info("Successfully pushed metrics to central server")
        else:
            logger.warning(f"Failed to push metrics to central server: HTTP {response.status_code}")
    except Exception as e:
        logger.error(f"Error pushing metrics to central server: {e}")

def schedule_collector():
    """Schedule the metrics collector to run at regular intervals"""
    config = load_config()
    interval = config['exporter']['scrape_interval']
    mode = config['metrics_server'].get('mode', 'central')
    
    # Collect immediately on startup
    collect_metrics()
    
    # If in client mode, push metrics to central server
    if mode == 'client':
        metrics = generate_latest(REGISTRY)
        push_to_central(metrics)
    
    # Then schedule regular collection
    def collect_and_maybe_push():
        collect_metrics()
        if mode == 'client':
            metrics = generate_latest(REGISTRY)
            push_to_central(metrics)
    
    schedule.every(interval).seconds.do(collect_and_maybe_push)
    
    while True:
        schedule.run_pending()
        time.sleep(1)

@app.route('/metrics/push', methods=['POST'])
def receive_metrics():
    """Endpoint for receiving metrics from client instances"""
    config = load_config()
    auth_key = config['metrics_server'].get('auth_key', '')
    
    # Check authentication if configured
    if auth_key:
        auth_header = request.headers.get('Authorization', '')
        if auth_header != f'Bearer {auth_key}':
            return jsonify({"error": "Unauthorized"}), 401
    
    try:
        # Get client IP for logging
        client_ip = request.remote_addr
        client_metrics = request.data.decode('utf-8')
        
        # Process the received metrics - parse them to extract values
        # In a production environment, you would want to implement a more sophisticated
        # approach to merge metrics from various sources
        
        # Example parsing to extract and store key metrics
        for line in client_metrics.split('\n'):
            if line and not line.startswith('#') and '{' in line:
                # This is a metric line with labels
                try:
                    # Parse the metric name and value
                    metric_parts = line.split('{')
                    metric_name = metric_parts[0].strip()
                    
                    # Extract labels and value
                    labels_part = metric_parts[1].split('}')[0]
                    value = float(line.split('} ')[1].strip())
                    
                    # Log the received metric
                    logger.debug(f"Received metric: {metric_name}, labels: {labels_part}, value: {value}")
                    
                    # Here you would store this in your local registry
                    # This is a simplified example - proper implementation would need
                    # to carefully handle all metric types and avoid conflicts
                except Exception as e:
                    logger.warning(f"Could not parse metric line: {line}, error: {e}")
        
        logger.info(f"Received metrics from client {client_ip}")
        return jsonify({"status": "success"}), 200
    except Exception as e:
        logger.error(f"Error processing received metrics: {e}")
        return jsonify({"error": str(e)}), 500

def main():
    """Main function to start the exporter"""
    config = load_config()
    port = config['exporter']['port']
    metrics_server_enabled = config['metrics_server'].get('enabled', False)
    mode = config['metrics_server'].get('mode', 'central')
    
    if mode == 'central' and metrics_server_enabled:
        # In central mode, start Flask to handle incoming metrics
        logger.info(f"Starting central server mode on port {port}")
        app.run(host='0.0.0.0', port=port)
    else:
        # In client or standalone mode, just expose metrics
        start_http_server(port)
        logger.info(f"Fishnet exporter started on port {port} in {'client' if mode == 'client' else 'standalone'} mode")
    
    # Start the collector in a separate thread
    collector_thread = threading.Thread(target=schedule_collector)
    collector_thread.daemon = True
    collector_thread.start()
    
    # Keep the main thread running
    while True:
        time.sleep(1)

if __name__ == "__main__":
    main()
