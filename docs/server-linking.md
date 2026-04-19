# Server Linking

Sable uses a Gossip-based mesh protocol for server linking. Every node communicates with every other node directly. If two nodes cannot reach each other, messages are routed via intermediate nodes based on what is currently reachable.

---

## Network Configuration (`network.conf`)

This file must be identical across all nodes. A temporary mismatch during a rolling config update is recoverable, but message delivery may be less reliable during that window.

| Field | Description |
|---|---|
| `fanout` | Number of nodes each node forwards each event to. Tune based on network size and the bandwidth vs. delivery speed trade-off. |
| `ca_file` | Path to a PEM-encoded CA certificate used to validate node TLS certificates. |
| `peers` | Array of peer definitions (see below). |

Each peer entry:

| Field | Description |
|---|---|
| `name` | Server name. Must match the `server_name` field in that node's `server.conf`. |
| `address` | IP address and port of the node's sync listener. Must match `node_config.listen_addr` in that server's config. |
| `fingerprint` | TLS certificate fingerprint for the sync listener (not the client listener, which may differ). |

---

## Peer Authentication

When an incoming sync connection is received, all of the following must be true to accept it:

1. The client certificate is signed by the CA in `ca_file`.
2. The certificate's common name (CN) matches a server name defined in `peers`.
3. The certificate's fingerprint matches the `fingerprint` defined for that server.
4. The source IP matches the IP portion of the `address` defined for that server.

Any failure in these checks causes the connection to be rejected immediately.

---

## Event Propagation

Each server maintains an event log. When an event is received:

- It is held until all of its declared dependencies have been received and applied.
- If dependencies are missing, they are requested from the network.
- Once ready, the event is applied to local state and forwarded to `fanout` peers.

This ensures that all servers eventually reach the same state regardless of the order in which events arrive.
