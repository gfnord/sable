# Netsplits

Netsplits in Sable's gossip mesh are rare compared to spanning-tree IRC networks, since a single lost connection does not partition the network. However, if a group of servers becomes fully isolated from the rest, the situation must be resolved deterministically.

---

## Design Principle

Merging two divergent network states — where both sides may have processed different events — is extremely complex to resolve consistently across all servers simultaneously. Sable's approach is to not attempt it.

Instead, once a partition occurs, the two sides remain permanently separated. One side must be designated the authoritative state, and isolated servers must be restarted to rejoin.

---

## How It Works

When a server leaves the network (shutdown or connectivity failure), all servers that process the quit event record that `(server_id, epoch)` pair as departed:

- No future sync messages from that `(server_id, epoch)` are accepted.
- That peer is no longer eligible to receive outgoing sync events.

When a server attempts to rejoin, it is accepted only if its epoch is **different** from any previously seen epoch for that server ID. If accepted, peers will begin syncing events to it and it will adopt the current network state.

---

## Recovery Procedure

1. Determine which partition holds the correct network state.
2. Restart all servers that are not part of that partition. Each restart generates a new epoch.
3. Restarted servers sync from scratch and rejoin the authoritative partition.

---

## Automatic Detection (Future)

User experience could be improved by servers automatically detecting partition via a quorum scheme, and degrading or suspending service when isolated. This is not yet implemented but is not required for consistency — the above mechanism guarantees that no divergent states can silently remerge.
