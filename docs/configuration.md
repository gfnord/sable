# Configuration Reference

A Sable network is composed of one or more nodes, each sharing common configuration structure with node-type-specific sections.

---

## Configuration Files

| File | Scope | Purpose |
|---|---|---|
| `network.conf` | Shared across all nodes | Static network topology (server addresses, TLS fingerprints) |
| `server.conf` | Per-node | Node identity, TLS, management API, logging |
| `network_config.json` | Runtime, shared | Operators, cloaking key, channel roles |

`network.conf` and `network_config.json` must be identical across all nodes. `server.conf` is unique to each server.

---

## `server.conf` — Top-Level Fields

| Field | Type | Description |
|---|---|---|
| `server_id` | integer | Unique numeric ID for this node. Must be unique across the network at all times. |
| `server_name` | string | Textual name of the server (typically its DNS hostname). |

---

## `management` Block

Configures the out-of-band HTTPS management interface.

| Field | Description |
|---|---|
| `address` | Socket address (`IP:port`) for the management listener. |
| `client_ca` | Path to a PEM-encoded CA certificate used to validate client certificates. |
| `authorised_fingerprints` | List of authorised management users (see below). |

Each entry in `authorised_fingerprints` requires:

| Field | Description |
|---|---|
| `name` | Username recorded in audit logs. |
| `fingerprint` | Certificate fingerprint. The certificate must also be signed by `client_ca`. |

---

## `tls_config` Block

TLS settings for publicly-facing client connections.

| Field | Description |
|---|---|
| `key_file` | Path to the PEM-encoded private key. |
| `cert_file` | Path to the PEM-encoded certificate. |

---

## `node_config` Block

Settings for server-to-server synchronisation.

| Field | Description |
|---|---|
| `listen_addr` | Socket address for the sync listener. Must match the `address` defined for this server in `network.conf`. |
| `cert_file` | Path to the PEM-encoded certificate used to identify this node to peers. Must be signed by the CA in `network.conf` and have a CN matching `server_name`. |
| `key_file` | Path to the PEM-encoded private key for the node certificate. |

---

## `log` Block

| Field | Description |
|---|---|
| `dir` | Parent directory for log files. All other paths in this block are relative to it. |
| `stdout` | File for stdout redirection when running in background mode. |
| `stderr` | File for stderr redirection when running in background mode. |
| `pidfile` | File to store the process ID when running in background mode. |
| `module-levels` | Map of module names to maximum log levels. An empty string key sets the default for all unspecified modules. |
| `targets` | Array of log target definitions (see below). |

Each `targets` entry:

| Field | Description |
|---|---|
| `target` | `"stdout"`, `"stderr"`, or `{ "filename": "path" }`. |
| `level` | Maximum log level for this target. |
| `modules` | Optional array of module names to include. Omit to include all modules. |

---

## `server` Block

### Client Server

| Field | Description |
|---|---|
| `listeners` | Array of listener definitions. |

Each listener entry:

| Field | Description |
|---|---|
| `address` | Listen address (`IP:port`). |
| `tls` | Optional boolean. If `true`, this is a TLS listener using the certificate from `tls_config`. |

### Services Node

| Field | Description |
|---|---|
| `database` | Path to the account data store. |
| `default_roles` | Map of role names to arrays of permission strings. Applied to newly registered channels. |

---

## `network_config.json` — Runtime Configuration

| Field | Type | Description |
|---|---|---|
| `opers` | array | List of IRC operator credentials (see below). |
| `debug_mode` | boolean | Enables debug output. Set to `false` in production. |
| `object_expiry` | integer | Seconds before unused objects are expired. |
| `pingout_duration` | integer | Seconds after a server ping before a client is disconnected. Default: `240`. |
| `cloak_key` | string | Secret key for hostname cloaking. Generate with `openssl rand -hex 32`. |
| `default_roles` | object | Default channel role permissions assigned to newly registered channels. |
| `alias_users` | array | Virtual service users (e.g. ChanServ, NickServ). |

Each entry in `opers`:

| Field | Description |
|---|---|
| `name` | Operator username. |
| `hash` | Password hash. Generate with `openssl passwd -6`. |
