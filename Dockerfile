# Stage 1: Python build layer
FROM python:3.11-slim as bootstrapper

# Install required Python packages
RUN pip install --no-cache-dir psycopg2-binary requests

# Copy bootstrap script
COPY bootstrap/init.py /opt/bootstrap/init.py
COPY entrypoint.sh /opt/bootstrap/entrypoint.sh

# Stage 2: Gravitino base + bootstrap
FROM apache/gravitino:0.9.0-incubating

# Copy Python runtime from Stage 1
COPY --from=bootstrapper /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=bootstrapper /usr/local/bin/python3 /usr/local/bin/python3
COPY --from=bootstrapper /usr/local/bin/pip /usr/local/bin/pip
COPY --from=bootstrapper /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages

# Copy bootstrap script
COPY --from=bootstrapper /opt/bootstrap/ /opt/bootstrap/

# Set permissions (optional)
RUN chmod +x /opt/bootstrap/entrypoint.sh

# Entrypoint includes Gravitino startup + Python bootstrap
ENTRYPOINT ["/opt/bootstrap/entrypoint.sh"]
