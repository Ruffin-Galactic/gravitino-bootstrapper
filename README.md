# Gravitino Bootstrapper

This project provides a production-ready containerized version of [Apache Gravitino](https://gravitino.apache.org/) that supports multi-tenant dynamic Iceberg catalog registration on startup—without requiring a static `application.yaml` or external bootstrapping steps.

## Why This Exists — Limitations of Gravitino

Gravitino is a powerful metadata and REST catalog layer for Iceberg, but as of version `0.9.0-incubating`, it has the following key limitations:

* Catalogs registered via the REST API are not persisted across restarts
* Only catalogs declared in `application.yaml` are remembered between sessions
* There's no built-in support for multi-tenant catalog isolation using a shared JDBC database

These constraints make it unsuitable out of the box for multi-tenant SaaS platforms, where each organization needs:

* Its own isolated Iceberg catalog
* Its own GCS bucket and IAM configuration
* A single metadata database backend (PostgreSQL)

## What This Project Adds

This container solves those problems by adding:

1. Schema-based multi-tenant catalog registration:

   * Each tenant gets a unique Iceberg metadata table (e.g., `org1_catalog`)
   * All catalogs share the same PostgreSQL database

2. Automatic catalog initialization at container startup:

   * Catalogs are read from a persistent `iceberg_catalog_registry` table
   * Each one is dynamically registered via Gravitino's REST API

3. Self-initializing schema:

   * If `iceberg_catalog_registry` doesn't exist, it's created automatically

4. GitHub Actions-based Docker image publishing:

   * All commits to `main` trigger a build and push to GHCR under the `latest` tag

## Project Structure

```
gravitino/
├── bootstrap/
│   └── init.py              # Bootstrap script that registers org-specific catalogs
├── entrypoint.sh            # Starts Gravitino and runs the bootstrapper
├── Dockerfile               # Builds the Gravitino image with Python and bootstrap tools
├── docker-compose.yml       # Spins up Gravitino + Postgres
└── .github/
    └── workflows/
        └── docker-build.yml # GitHub Actions workflow to build + push Docker image to GHCR
```

## How It Works

1. On startup, the container waits for Gravitino to become ready.
2. It connects to the PostgreSQL database (via `GRAVITINO_CATALOG_DB_URL`).
3. If needed, it creates the `iceberg_catalog_registry` table.
4. It loads each row from the registry and sends a `POST /v1/catalogs` request to Gravitino.
5. Each catalog is given:

   * A unique name (e.g., `org1`)
   * A dedicated metadata table (e.g., `org1_catalog`)
   * A GCS warehouse path
   * `"create-metadata-table": "true"` so it auto-creates if not yet present

## Example Registry Schema

```sql
CREATE TABLE iceberg_catalog_registry (
  catalog_name TEXT PRIMARY KEY,
  jdbc_url TEXT NOT NULL,
  gcs_warehouse TEXT NOT NULL,
  gcs_credentials JSONB,
  comment TEXT
);
```

Each row in this table defines an org's catalog.

## Using This Project

### 1. Build and push (automatically via GitHub Actions)

Every push to `main`:

* Builds the Docker image
* Pushes it to `ghcr.io/<your-username>/gravitino:latest`

See `.github/workflows/docker-build.yml`

### 2. Pull and run via Docker Compose

```yaml
services:
  gravitino:
    image: ghcr.io/<your-user>/gravitino:latest
    ...
    environment:
      GRAVITINO_CATALOG_DB_URL: postgres://admin:secret@postgres:5432/catalog_config
```

## How It Initializes Metadata

Each catalog is configured with its own metadata table using:

```json
"metadata-table": "<catalog_name>_catalog",
"create-metadata-table": "true"
```

This ensures:

* Per-tenant isolation
* Tables are auto-created as tenants are onboarded
* All catalogs share the same database backend but have logically separated metadata
