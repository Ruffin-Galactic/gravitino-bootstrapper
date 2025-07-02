import os
import time
import psycopg2
import requests

def wait_for_gravitino():
    for _ in range(60):
        try:
            if requests.get("http://localhost:8090/api/v1/catalogs").status_code == 200:
                return
        except Exception:
            time.sleep(1)
    raise RuntimeError("Gravitino did not start in time")

def bootstrap_catalogs():
    jdbc_url = os.environ.get("GRAVITINO_CATALOG_DB_URL")
    if not jdbc_url:
        raise RuntimeError("Missing GRAVITINO_CATALOG_DB_URL environment variable")

    conn = psycopg2.connect(jdbc_url)
    cur = conn.cursor()

    #  Ensure the registry table exists
    cur.execute("""
        CREATE TABLE IF NOT EXISTS iceberg_catalog_registry (
            catalog_name TEXT PRIMARY KEY,
            jdbc_url TEXT NOT NULL,
            gcs_warehouse TEXT NOT NULL,
            gcs_credentials JSONB,
            comment TEXT
        )
    """)
    conn.commit()

    #  Load all orgs from the registry
    cur.execute("SELECT catalog_name, jdbc_url, gcs_warehouse FROM iceberg_catalog_registry")
    for catalog_name, jdbc, gcs in cur.fetchall():
        metadata_table = f"{catalog_name}_catalog"

        payload = {
            "name": catalog_name,
            "type": "jdbc",
            "comment": f"Catalog for org '{catalog_name}'",
            "properties": {
                "jdbc-url": jdbc,
                "user": "admin",
                "password": "secret",
                "warehouse": gcs,
                "dialect": "postgresql",
                "metadata-table": metadata_table,
                "create-metadata-table": "true"
            }
        }

        print(f"Registering catalog '{catalog_name}' with metadata table '{metadata_table}'...")
        resp = requests.post("http://localhost:8090/api/v1/catalogs", json=payload)
        if resp.status_code >= 300:
            print(f" Failed to register catalog '{catalog_name}': {resp.status_code} - {resp.text}")

if __name__ == "__main__":
    wait_for_gravitino()
    bootstrap_catalogs()
