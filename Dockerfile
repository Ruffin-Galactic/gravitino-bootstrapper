FROM openjdk:17-slim

# Install Gravitino manually
RUN curl -sSL https://downloads.apache.org/gravitino/0.9.0-incubating/apache-gravitino-0.9.0-incubating-bin.tar.gz \
  | tar -xz -C /opt/ && \
  ln -s /opt/apache-gravitino-*/ /opt/gravitino

# Install Python and bootstrap tools
RUN apt-get update && apt-get install -y python3 python3-pip && \
    pip3 install psycopg2-binary requests && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy bootstrap scripts
COPY bootstrap/init.py /opt/bootstrap/init.py
COPY entrypoint.sh /opt/bootstrap/entrypoint.sh

WORKDIR /opt/gravitino
ENTRYPOINT ["/opt/bootstrap/entrypoint.sh"]
