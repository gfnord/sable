#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
echo_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $1"; }

NETWORK_CONF="${SABLE_NETWORK_CONF:-/sable/config/network.conf}"
SERVER_CONF="${SABLE_SERVER_CONF:-/sable/config/services.conf}"
CERT_DIR="${SABLE_CERT_DIR:-/sable/certs}"

check_config() {
    echo_info "Checking configuration files..."

    if [ ! -f "${NETWORK_CONF}" ]; then
        echo_error "Network config not found: ${NETWORK_CONF}"
        exit 1
    fi

    if [ ! -f "${SERVER_CONF}" ]; then
        echo_error "Services config not found: ${SERVER_CONF}"
        exit 1
    fi

    echo_info "Configuration files found"
}

check_certs() {
    echo_info "Checking TLS certificates..."

    local missing=false

    for f in services.crt services.key ca_cert.pem; do
        if [ ! -f "${CERT_DIR}/${f}" ]; then
            echo_error "Missing certificate: ${CERT_DIR}/${f}"
            missing=true
        fi
    done

    if [ "$missing" = true ]; then
        echo_error "Please provide all required certificates in ${CERT_DIR}:"
        echo_error "  services.crt  - Services TLS certificate"
        echo_error "  services.key  - Services private key"
        echo_error "  ca_cert.pem   - CA certificate for inter-node authentication"
        exit 1
    fi

    echo_info "TLS certificates found"
}

trap 'echo_info "Shutting down..."; exit 0' SIGTERM SIGINT

check_config
check_certs

echo_info "Starting Sable Services..."
echo_info "Network config : ${NETWORK_CONF}"
echo_info "Services config: ${SERVER_CONF}"

exec /usr/local/bin/sable_services \
    -n "${NETWORK_CONF}" \
    -s "${SERVER_CONF}" \
    --foreground \
    "$@"
