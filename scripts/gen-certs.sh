#!/bin/bash
# Generates all inter-node TLS certificates required for a Sable deployment.
# Run this once from the root of the repository before starting the containers.
#
# Usage:
#   ./scripts/gen-certs.sh [ircd_hostname] [services_hostname]
#
# Examples:
#   ./scripts/gen-certs.sh irc.example.com services.example.com
#   ./scripts/gen-certs.sh irc.the14.xyz services.the14.xyz
#
# These certificates are for the internal gossip network only (port 6668).
# Your public-facing IRC TLS certificate (port 6697) comes from Caddy / Let's Encrypt
# and is NOT generated here.

set -euo pipefail

IRCD_HOST="${1:-irc.example.com}"
SERVICES_HOST="${2:-services.example.com}"
CERT_DIR="$(cd "$(dirname "$0")/.." && pwd)/certs"
DAYS=3650

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

mkdir -p "$CERT_DIR"

# Safety check: don't overwrite existing CA
if [ -f "$CERT_DIR/ca.key" ]; then
    warn "CA key already exists at $CERT_DIR/ca.key"
    warn "Delete it manually if you want to regenerate all certificates."
    warn "Regenerating node certs only (re-signing with existing CA)."
    REGEN_CA=false
else
    REGEN_CA=true
fi

# --- Private CA ---
if [ "$REGEN_CA" = true ]; then
    info "Generating private CA..."
    openssl genrsa -out "$CERT_DIR/ca.key" 4096 2>/dev/null
    openssl req -x509 -new -nodes \
        -key "$CERT_DIR/ca.key" \
        -sha256 -days $DAYS \
        -out "$CERT_DIR/ca_cert.pem" \
        -subj "/CN=sable-ca"
    info "CA certificate: $CERT_DIR/ca_cert.pem"
fi

sign_cert() {
    local name="$1"
    local cn="$2"
    local san="$3"
    local key_file="$CERT_DIR/${name}.key"
    local crt_file="$CERT_DIR/${name}.crt"
    local csr_file="$CERT_DIR/${name}.csr"
    local ext_file
    ext_file="$(mktemp)"

    cat > "$ext_file" <<EOF
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
subjectAltName = DNS:${san}
EOF

    info "Generating ${name} certificate (CN=${cn}, SAN=${san})..."
    openssl genrsa -out "$key_file" 4096 2>/dev/null
    openssl req -new -key "$key_file" -out "$csr_file" -subj "/CN=${cn}" 2>/dev/null
    openssl x509 -req \
        -in "$csr_file" \
        -CA "$CERT_DIR/ca_cert.pem" \
        -CAkey "$CERT_DIR/ca.key" \
        -CAcreateserial \
        -out "$crt_file" \
        -days $DAYS \
        -extfile "$ext_file" 2>/dev/null

    rm -f "$csr_file" "$ext_file"
    info "  Certificate : $crt_file"
    info "  Private key : $key_file"
}

# --- IRC server gossip certificate ---
sign_cert "client" "$IRCD_HOST" "$IRCD_HOST"

# --- Services gossip certificate ---
sign_cert "services" "$SERVICES_HOST" "$SERVICES_HOST"

# --- Print fingerprints for network.conf ---
echo ""
info "SHA-1 fingerprints for network.conf:"

IRCD_FP=$(openssl x509 -in "$CERT_DIR/client.crt" -fingerprint -sha1 -noout \
    | tr -d ':' | sed 's/SHA1 Fingerprint=//' | tr '[:upper:]' '[:lower:]')

SERVICES_FP=$(openssl x509 -in "$CERT_DIR/services.crt" -fingerprint -sha1 -noout \
    | tr -d ':' | sed 's/SHA1 Fingerprint=//' | tr '[:upper:]' '[:lower:]')

echo ""
echo "  ircd (\"$IRCD_HOST\")     : $IRCD_FP"
echo "  services (\"$SERVICES_HOST\") : $SERVICES_FP"
echo ""
info "Update your configs/network.conf with the fingerprints above."
info "Keep certs/ca.key safe — you need it to sign certificates for new nodes."
