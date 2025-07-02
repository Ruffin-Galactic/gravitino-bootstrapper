FROM apache/gravitino:0.9.0-incubating

RUN apt-get update && apt-get install -y python3 python3-pip && \
    pip3 install psycopg2-binary requests

COPY bootstrap/init.py /opt/bootstrap/init.py
COPY entrypoint.sh /opt/bootstrap/entrypoint.sh

ENTRYPOINT ["/opt/bootstrap/entrypoint.sh"]
