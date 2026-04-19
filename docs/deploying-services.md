# Deploying sable_services

`sable_services` is a dedicated network node that provides account management, SASL authentication, and channel registration for your Sable IRC network. It runs as a separate process and communicates with IRC servers over the same gossip network used for server-to-server linking.

---

## Overview

Services does **not** accept IRC client connections. It is a backend node only — IRC servers forward requests to it (REGISTER, IDENTIFY, SASL) and receive responses over the gossip network.

A single services instance serves the entire network. It is discovered automatically by name once it joins the gossip mesh.

---

## What You Need

- A private CA certificate and key (for signing inter-node certs)
- A TLS certificate and private key for the services node (`services.crt`, `services.key`)
- A TLS certificate and private key for the IRC server's gossip port (`client.crt`, `client.key`)
- The SHA-1 fingerprint of each cert (for `network.conf`)
- A writable directory for the database and logs

> **Important:** The gossip network uses a **private CA you control** — not Let's Encrypt or any public CA. The inter-node port (6668) is internal Docker-to-Docker communication and never needs a publicly trusted certificate. Your Caddy/Let's Encrypt certificate is only used for IRC client connections on port 6697.

---

## Step 1: Create a Private CA and Sign Node Certificates

All nodes on the gossip network must share the same CA. You create it once and sign a certificate for each node.

```bash
# Create the private CA
openssl genrsa -out certs/ca.key 4096
openssl req -x509 -new -nodes -key certs/ca.key -sha256 -days 3650 \
    -out certs/ca_cert.pem -subj "/CN=sable-ca"

# Sign the IRC server's gossip certificate
# The subjectAltName must match the server's `name` field in network.conf exactly
cat > /tmp/ircd_ext.cnf << 'EOF'
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = DNS:irc.example.com
EOF

openssl genrsa -out certs/client.key 4096
openssl req -new -key certs/client.key -out certs/client.csr -subj "/CN=irc.example.com"
openssl x509 -req -in certs/client.csr -CA certs/ca_cert.pem -CAkey certs/ca.key \
    -CAcreateserial -out certs/client.crt -days 3650 -extfile /tmp/ircd_ext.cnf

# Sign the services certificate
# The subjectAltName must match the services `name` field in network.conf exactly
cat > /tmp/svc_ext.cnf << 'EOF'
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = DNS:services.example.com
EOF

openssl genrsa -out certs/services.key 4096
openssl req -new -key certs/services.key -out certs/services.csr -subj "/CN=services.example.com"
openssl x509 -req -in certs/services.csr -CA certs/ca_cert.pem -CAkey certs/ca.key \
    -CAcreateserial -out certs/services.crt -days 3650 -extfile /tmp/svc_ext.cnf

# Get SHA-1 fingerprints (needed for network.conf)
openssl x509 -in certs/client.crt -fingerprint -sha1 -noout | tr -d ':' | sed 's/SHA1 Fingerprint=//' | tr '[:upper:]' '[:lower:]'
openssl x509 -in certs/services.crt -fingerprint -sha1 -noout | tr -d ':' | sed 's/SHA1 Fingerprint=//' | tr '[:upper:]' '[:lower:]'
```

> **Important:** The `subjectAltName` in each certificate must exactly match the `name` field for that peer in `network.conf`. rustls enforces SAN matching and will reject certificates that only have a CN. The certs must also be X.509 v3 (ensured by the `-extfile` flag above).

Keep `certs/ca.key` safe — you need it to sign certificates for any new nodes.

---

## Step 2: Configure `network.conf`

Every node in the network, including services, must be listed in `network.conf`. This file is **shared** between the IRC server and services — both containers mount the same file.

Add the services entry to the `peers` array:

```json
{
    "fanout": 2,
    "ca_file": "/sable/certs/ca_cert.pem",
    "peers": [
        {
            "name": "irc.example.com",
            "address": "sable-ircd-1:6668",
            "fingerprint": "your-ircd-cert-sha1-fingerprint"
        },
        {
            "name": "services.example.com",
            "address": "sable-services:6668",
            "fingerprint": "your-services-cert-sha1-fingerprint"
        }
    ]
}
```

> **Important:** The `name` field must exactly match the `server_name` in `services.conf`. The `address` uses the Docker service name (`sable-services`) as the hostname, which Docker resolves automatically within the network.

---

## Step 3: Configure `services.conf`

Copy the example and edit it:

```bash
cp configs/services.conf.example configs/services.conf
```

Key fields to update:

| Field | Description |
|---|---|
| `server_name` | Must match the `name` in `network.conf` peers list |
| `server.database` | Path to the database file (writable; created on first run) |
| `tls_config.cert_file` / `key_file` | Paths to the services TLS certificate and key |
| `node_config.listen_addr` | Leave as `0.0.0.0:6668` for Docker |
| `server.password_hash.cost` | bcrypt work factor — 12 is a good production value |

The three `builtin:founder`, `builtin:op`, and `builtin:voice` roles in `default_roles` are **required**. Do not remove them.

---

## Step 4: Configure `network_config.json`

The IRC server's runtime config (`network_config.json`) must declare the virtual service users that clients interact with. Ensure these entries are present:

```json
"alias_users": [
    {
        "nick": "NickServ",
        "user": "NickServ",
        "host": "services.",
        "realname": "Account services compatibility layer",
        "command_alias": "NS"
    },
    {
        "nick": "ChanServ",
        "user": "ChanServ",
        "host": "services.",
        "realname": "Channel services compatibility layer",
        "command_alias": "CS"
    }
]
```

These are already present in `network_config.json.example`.

---

## Step 5: Deploy with Docker Compose

The `docker-compose.yml` includes a `sable-services` service. The IRC server is configured to `depends_on` services, so it starts after services is up.

```bash
DOCKER_BUILDKIT=1 docker compose up -d --build
```

To view services logs:

```bash
docker compose logs -f sable-services
```

---

## Directory Structure

After deployment, your project directory should look like:

```
.
├── configs/
│   ├── network.conf          # Shared between ircd and services
│   ├── server.conf           # IRC server config
│   ├── services.conf         # Services config
│   └── network_config.json   # Runtime config (opers, alias users, cloak key)
├── certs/
│   ├── ca_cert.pem           # Shared CA certificate
│   ├── services.crt          # Services TLS certificate
│   ├── services.key          # Services private key
│   ├── server.crt            # IRC server TLS certificate
│   └── server.key            # IRC server private key
└── data/
    ├── ircd/                 # IRC server logs and state
    └── services/             # Services database and logs
        └── services.json     # Account/channel database (auto-created)
```

---

## How Services Is Discovered

You do not need to configure the IRC server's address for services explicitly. When `sable_services` starts, it joins the gossip network and broadcasts a `NewServer` event. IRC servers automatically detect the services node by its `server_name` and begin routing service requests to it.

If services restarts, IRC servers will reconnect automatically once the new instance joins the network.

---

## Troubleshooting

**Services fails to start with "missing builtin role"**
Ensure `builtin:founder`, `builtin:op`, and `builtin:voice` are all defined in `default_roles` in `services.conf`.

**IRC server cannot reach services**
- Verify both containers are on the same Docker network (`sable-net`).
- Verify the `name` in `network.conf` exactly matches `server_name` in `services.conf`.
- Verify the `address` in `network.conf` uses the Docker service name (`sable-services:6668`).
- Check that the certificate fingerprint in `network.conf` matches the actual cert: `openssl x509 -in certs/services.crt -fingerprint -sha1 -noout`.

**TLS handshake errors between nodes**
- Ensure all nodes use certificates signed by the same CA (`ca_cert.pem`).
- Ensure the CA path in `network.conf` (`ca_file`) is correct inside the container (`/sable/certs/ca_cert.pem`).

**Database permission errors**
- Ensure `./data/services/` exists and is writable by the container user.
- Docker creates volume mount directories as root; you may need: `mkdir -p data/services && chmod 777 data/services`.
