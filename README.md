# Sable IRC Server

> **This is a fork of [Libera-Chat/sable](https://github.com/Libera-Chat/sable) and is moving in a different direction.**
> Development here focuses on production deployability, privacy features, and IRC protocol completeness.
> Upstream changes may be selectively merged, but this fork is not intended to track upstream exactly.

---

## What's New in This Fork

### IRC Commands

- **`LIST`** — Lists all channels on the server. Shows channel name, visible member count, and topic. Respects secret (`+s`) mode by hiding secret channels from non-members.

### Privacy

- **Hash-based hostname cloaking** — Client IP addresses are automatically replaced with a deterministic SHA-256 cloak (`<32-hex-chars>.cloaked`), keyed by a server-configured secret. Users are never exposed to other clients, and the same IP always receives the same cloak within a network.

### Deployment

- **Docker Compose setup** — Production-ready containerized deployment with BuildKit cache mounts for fast rebuilds.
- **Configuration templates** — Config files ship as `.example` templates to prevent accidental credential commits.

---

## Overview

Sable is an experimental IRC server designed to address fundamental limitations of legacy IRC software:

- **No spanning tree** — Servers communicate via a Gossip-like mesh protocol. A single lost connection does not disrupt the network.
- **Unique event IDs** — Every state change is an `Event` with a globally unique ID and dependency tracking. Duplicate or out-of-order processing cannot occur.
- **Persistent user presence** — Complete network history allows users to remain online when clients disconnect, and to connect from multiple clients simultaneously.
- **Zero-disruption upgrades** — Instead of module loading, upgrades are handled by re-executing the server in-place and resuming from saved state.

---

## Architecture

- Every network object (user, channel, ban, topic, etc.) has a unique identifier.
- Every state change is an `Event` with a globally unique ID, dependency clock, and typed details struct.
- Events propagate between servers via gossip. Each server maintains an event log that ensures events are applied only after all dependencies are met.
- Network state is read-only except via event processing. Any valid application order for a set of events produces the same final state.
- There are no netjoins. A server will not accept clients until it has fully synced to the network, unless bootstrapping a new one.

See [`docs/state-events-and-history.md`](docs/state-events-and-history.md) for a detailed explanation.

---

## Crate Structure

| Crate | Purpose |
|---|---|
| `sable_network` | Network data model, event log, state tracking, gossip sync |
| `sable_ircd` | IRC client protocol server |
| `sable_services` | Services node — account and registration data |
| `sable_server` | Generic network node runner |
| `sable_history` | Long-term channel history (SQL-backed) |
| `client_listener` | Split-out client listener process |
| `auth_client` | Split-out DNS/ident lookup process |
| `sable_ipc` | IPC channel types for split-out processes |
| `sable_macros` | Procedural macros |

---

## Building

**Requirements:** Rust (install via [rustup](https://www.rust-lang.org/tools/install))

```bash
git clone https://github.com/gfnord/sable
cd sable
cargo build --release
```

For faster incremental rebuilds with Docker:

```bash
DOCKER_BUILDKIT=1 docker compose up -d --build
```

---

## Running

### Local (development)

```bash
# Bootstrap a new single-node network
./target/debug/sable_ircd \
  -n configs/network.conf \
  -s configs/server.conf \
  --bootstrap-network configs/network_config.json
```

### Docker

See [`INSTALLATION.md`](INSTALLATION.md) for full Docker deployment instructions including TLS, certificate management, and multi-server setups.

---

## Configuration

There are two configuration layers:

- **`network.conf`** — Static network topology (server addresses, TLS fingerprints). Shared across all nodes. Read only at startup.
- **`network_config.json`** — Runtime config (oper credentials, cloaking key, channel roles). Can be updated at runtime via the `config_loader` utility.

Copy the `.example` files to get started:

```bash
cp configs/network.conf.example configs/network.conf
cp configs/network_config.json.example configs/network_config.json
```

See [`docs/configuration.md`](docs/configuration.md) for full configuration reference.

---

## Documentation

- [`docs/configuration.md`](docs/configuration.md) — Configuration reference
- [`docs/server-linking.md`](docs/server-linking.md) — Server linking and gossip protocol
- [`docs/state-events-and-history.md`](docs/state-events-and-history.md) — Network state, events, and history internals
- [`docs/netsplits.md`](docs/netsplits.md) — How netsplits are handled
- [`docs/command-handlers.md`](docs/command-handlers.md) — Writing IRC command handlers
- [`docs/deploying-services.md`](docs/deploying-services.md) — Deploying the services node (NickServ/ChanServ)

---

## License

See upstream [Libera-Chat/sable](https://github.com/Libera-Chat/sable) for license information.
