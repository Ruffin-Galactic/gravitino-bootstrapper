#!/bin/bash
set -e

# Start Gravitino in background
/opt/gravitino/bin/start.sh &

# Run the catalog bootstrap script
python3 /opt/bootstrap/init.py

# Wait for Gravitino to exit (optional, if you want to keep container alive)
wait
