ARC Matrix Stack

Self‑hosted Matrix homeserver for endurance.network, packaged with Docker Compose.
Includes Synapse, PostgreSQL (for services that need it), and Sliding Sync. Bridges (e.g., WhatsApp) live alongside as additional services.

Topology (TL;DR)
	•	Synapse (matrix homeserver) — core server on http://arc-matrix:8008 inside the compose network.
	•	PostgreSQL — shared database service (used by sliding‑sync and future bridges). Synapse is currently on SQLite (see note).
	•	Sliding Sync — modern sync API proxy on :8009 (optional for web/Element X).
	•	Bridges — each bridge runs as its own container (e.g., mautrix-whatsapp), with its own volume.

DNS/hosts expected:
	•	matrix.endurance.network → 192.168.0.10
	•	sync.endurance.network → 192.168.0.10

The compose supplies extra_hosts so containers can resolve these names internally.

⸻

Repo Layout

.
├── compose.yml
└── volume/
    ├── arc-matrix/                 # Synapse data dir mounted at /data
    │   ├── data/
    │   │   ├── homeserver.yaml     # Synapse config (edit here)
    │   │   ├── endurance.network.signing.key
    │   │   ├── endurance.network.log.config
    │   │   ├── homeserver.db*      # SQLite DB (Synapse state) + -wal/-shm
    │   │   └── media_store/        # Synapse media
    │   └── media_store/            # (legacy/unused) keep for compatibility
    ├── arc-matrix-db/
    │   └── var_lib_postgresql_data/   # PostgreSQL data dir
    └── arc-matrix-slidingsync/
        └── data/                   # Sliding Sync state

Note on DBs
Synapse is currently running on SQLite (you’ll see homeserver.db* under arc-matrix/data).
A Postgres container is provisioned and used by Sliding Sync (and is ready for bridges / future Synapse migration, if/when we choose).

⸻

Services (compose.yml)

arc-matrix-db (PostgreSQL)
	•	Image: postgres:16
	•	DB: synapse / synapse / change_me
	•	Volume: ./volume/arc-matrix-db/var_lib_postgresql_data → /var/lib/postgresql/data
	•	Healthcheck ensures DB is up before dependents start.

arc-matrix (Synapse)
	•	Image: matrixdotorg/synapse:latest
	•	Ports: 8008:8008 (HTTP, no TLS on the internal network)
	•	Volume: ./volume/arc-matrix/data → /data
	•	Config path: /data/homeserver.yaml
	•	Media: /data/media_store
	•	Depends on Postgres only for start order. Synapse itself uses SQLite right now (configured in homeserver.yaml).

slidingsync
	•	Image: ghcr.io/matrix-org/sliding-sync:latest
	•	Env:
	•	SYNCV3_SERVER=http://arc-matrix:8008
	•	SYNCV3_DB=postgres://synapse:change_me@arc-matrix-db/synapse?sslmode=disable
	•	SYNCV3_BINDADDR=:8009
	•	Volume: ./volume/arc-matrix-slidingsync/data → /data

⸻

Volumes & Data Ownership
	•	Synapse config & state: ./volume/arc-matrix/data
	•	Edit homeserver.yaml here.
	•	Appservice registrations for bridges are placed here too (e.g., /data/whatsapp-registration.yaml).
	•	Synapse media: ./volume/arc-matrix/data/media_store
	•	PostgreSQL: ./volume/arc-matrix-db/var_lib_postgresql_data
	•	Sliding Sync: ./volume/arc-matrix-slidingsync/data
	•	Each Bridge gets its own directory under ./volume/<bridge-name>/… (see below).

Backups you care about:
	•	Synapse: homeserver.yaml, endurance.network.signing.key, homeserver.db* (if staying on SQLite), and media_store/.
	•	PostgreSQL: use pg_dump or snapshot var_lib_postgresql_data (stop container for file‑level copy).
	•	Sliding Sync can be reconstructed; it’s a cache/indexer.

⸻

Lifecycle

# start / update images
docker compose pull
docker compose up -d

# stop
docker compose down

# logs
docker compose logs -f arc-matrix
docker compose logs -f arc-matrix-db
docker compose logs -f arc-matrix-slidingsync

If you edit homeserver.yaml, restart Synapse:

docker compose restart arc-matrix


⸻

Bridges: Layout & Workflow

We standardize on one directory per bridge under ./volume, each with:

./volume/mautrix-<bridge>/
  ├── data/                 # bridge internal state (DB, sessions, etc.)
  ├── config.yaml           # main config (mounted read-only)
  └── registration.yaml     # appservice registration (generated/managed by the bridge)

Registration flow (applies to all bridges):
	1.	Start the bridge container; it (usually) generates /data/registration.yaml.
	2.	Copy that file into Synapse’s data dir and reference it in homeserver.yaml:

app_service_config_files:
  - /data/whatsapp-registration.yaml     # example
  # add one line per bridge


	3.	Restart Synapse and the bridge.

This keeps Synapse’s /data as the single source of truth for which appservices are active, while each bridge owns/refreshes its own registration file in its own volume.

Example: WhatsApp bridge (mautrix‑whatsapp)

Service (to add to compose):

  mautrix-whatsapp:
    image: dock.mau.dev/mautrix/whatsapp:latest
    container_name: mautrix-whatsapp
    depends_on:
      arc-matrix:
        condition: service_started
      arc-matrix-db:
        condition: service_healthy
    environment:
      TZ: "UTC"
      LOG_LEVEL: "info"
    volumes:
      - ./volume/mautrix-whatsapp/data:/data
      - ./volume/mautrix-whatsapp/config.yaml:/data/config.yaml:ro
      - ./volume/mautrix-whatsapp/registration.yaml:/data/registration.yaml
    command: >
      --config /data/config.yaml
      --registration /data/registration.yaml
      --generate-registration
    restart: unless-stopped
    networks: [default]

Config (create ./volume/mautrix-whatsapp/config.yaml):

homeserver:
  address: "http://arc-matrix:8008"
  domain: "endurance.network"
  verify_ssl: false

appservice:
  address: "http://mautrix-whatsapp:29318"
  hostname: "0.0.0.0"
  port: 29318
  database:
    type: sqlite
    uri: /data/mautrix-whatsapp.db
  as_token: ""
  hs_token: ""

bridge:
  bot:
    username: "whatsappbot"
    displayname: "WhatsApp Bot"
  permissions:
    "endurance.network": user
    "@ach9:endurance.network": admin
  encryption:
    allow: true
    default: true

whatsapp:
  device_name: "ARC WhatsApp Bridge"

logging:
  level: info

Bring it up & register:

docker compose up -d mautrix-whatsapp
# After the first start:
cp ./volume/mautrix-whatsapp/registration.yaml ./volume/arc-matrix/data/whatsapp-registration.yaml

# Reference it in homeserver.yaml:
# app_service_config_files:
#   - /data/whatsapp-registration.yaml

docker compose restart arc-matrix
docker compose restart mautrix-whatsapp

User login (from Matrix):
	•	DM @whatsappbot:endurance.network and send login.
	•	Scan the QR from WhatsApp → Settings → Linked devices.

We’ll follow the same pattern for other bridges (e.g., Telegram, iMessage, Signal):
new service + new ./volume/mautrix-<name> dir + copy registration into Synapse /data and list it in app_service_config_files.

⸻

Security & Ops Notes
	•	TLS: Inside the compose network we use plain HTTP. If exposing to the internet, put a reverse proxy (Caddy/NGINX/Traefik) in front of Synapse and Sliding Sync with TLS, and point DNS there.
	•	Secrets: Keep endurance.network.signing.key private. Don’t commit anything under volume/ to VCS unless scrubbed.
	•	Backups: Regularly back up:
	•	Synapse config & signing key
	•	SQLite DB (or Postgres dump if/when Synapse moves)
	•	Media store
	•	Bridge data/ (contains sessions, device IDs, and sometimes small SQLite DBs)
	•	Upgrades: docker compose pull && docker compose up -d. For Synapse major upgrades, check release notes for schema migrations (it handles them automatically).

⸻

Troubleshooting
	•	Synapse boots but can’t decrypt / E2EE weirdness
This is a client/device verification/key‑backup issue, not the server. Verify devices, enable SSSS/recovery keys in your client, and ensure your bot/bridge users are allowed in encrypted rooms if needed.
	•	Bridge not receiving events
	•	Confirm homeserver.yaml has the registration path under app_service_config_files.
	•	Check Synapse logs for appservice connection attempts.
	•	Ensure the bridge’s appservice.address matches the container/port and is reachable from Synapse.
	•	Sliding Sync not serving
	•	Confirm Postgres is healthy and SYNCV3_DB points to it.
	•	Check slidingsync logs; it must reach http://arc-matrix:8008.

⸻

Migration: Synapse SQLite → Postgres (Future)

We provisioned Postgres but Synapse currently uses SQLite. If we decide to migrate:
	1.	Stop Synapse.
	2.	Use synapse_port_db (official tool) to port data to Postgres.
	3.	Update homeserver.yaml database: to Postgres URI.
	4.	Start Synapse and validate.

(We’ll document this when we actually move.)

⸻

Quick Commands

# Bring everything up
docker compose up -d

# Tail logs
docker compose logs -f arc-matrix
docker compose logs -f arc-matrix-slidingsync
docker compose logs -f mautrix-whatsapp

# Restart synapse after config change
docker compose restart arc-matrix

# PostgreSQL shell
docker exec -it arc-matrix-db psql -U synapse -d synapse


⸻

If you’re adding a new bridge, copy the WhatsApp pattern:
	1.	create volume/mautrix-<name>/{data,config.yaml,registration.yaml},
	2.	add a compose service,
	3.	start once to generate registration,
	4.	copy registration into arc-matrix/data/<name>-registration.yaml, reference it in homeserver.yaml,
	5.	restart Synapse + the bridge.
