#!/bin/bash

# This script creates SSH tunnels to the bastion host for accessing Kubectl and MSSQL in Choreo Dev Control Plane.
# Please read https://docs.google.com/document/d/10u9AFnb52TR6wNSg_Z82TAjayDjJ7JYnmZmwHoqbxR0/edit#heading=h.hyo5f6n0qu4t before using this script.
# Usage: ./ssh-dev-cp.sh [--debug] <username>



SSH_TUNNEL_LOCAL_HOST_IP=0.0.0.0
SSH_TUNNEL_LOCAL_HOST_PORT=5100
VM_USERNAME=azureuser
VM_HOST_IP=172.200.195.203
SSH_PRIVATE_KEY=declarative-api-testing-vm_key.pem
POSTGRES_SERVER=declarative-api-testing-postgresql-server.postgres.database.azure.com:5432
DEBUG_MODE=false
ARGS=()

# ================= Helper functions =================

wait_for_tunnel_port() {
    local tunnel_for="$1"
    local tunnel_via="$2"
    local host="$3"
    local port="$4"

    while ! nc -z "${host}" "${port}"; do
        echo "Waiting for ${tunnel_for} ${tunnel_via} tunnel on ${host}:${port} to be available..."
        sleep 1
    done
    echo "${tunnel_for} ${tunnel_via} tunnel is available on ${host}:${port}"
}

# ================= Argument parsing =================
for arg in "$@"; do
    if [ "$arg" == "--debug" ]; then
        set -x
        DEBUG_MODE=true
    else
        ARGS+=("$arg")
    fi
done

# If debug mode is enabled, enable debug mode for az cli and ssh
if [ "${DEBUG_MODE}" = true ]; then
    AZ_CLI_EXTRA_ARGS+=" --debug"
    SSH_CLI_EXTRA_ARGS+=" -v"
fi

# ================= SSH Tunneling for PostgreSQL Instance =================

# Tunnel to the bastion for MSSQL in background
echo "Creating VM tunnel for POSTGRESQL Instance..."

# SSH Tunnel for MSSQL. -N(Do not execute a remote command.  This is useful for just forwarding ports)
echo "Creating SSH tunnel for MSSQL..."
ssh  ${VM_USERNAME}@${VM_HOST_IP} -i ${SSH_PRIVATE_KEY} \
    -o "StrictHostKeyChecking no" -o 'ServerAliveInterval=30' -o 'ServerAliveCountMax=5' \
    -L ${SSH_TUNNEL_LOCAL_HOST_IP}:${SSH_TUNNEL_LOCAL_HOST_PORT}:${POSTGRES_SERVER} -N ${SSH_CLI_EXTRA_ARGS} &
PID_SSH_TUNNEL_POSTGRES=$!

# Wait for SSH tunnel to be available for POSTGRES
wait_for_tunnel_port "POSTGRES" "SSH" "${SSH_TUNNEL_LOCAL_HOST_IP}" "${SSH_TUNNEL_LOCAL_HOST_PORT}"

# ================= Cleanup =================

# Kill the background processes on Ctrl+C
cleanup() {
  kill ${PID_SSH_TUNNEL_POSTGRES}
  echo "Successfully exited"
}
trap cleanup EXIT

echo "Press Ctrl+C to exit the script"

# Wait for background process to complete
wait ${PID_SSH_TUNNEL_POSTGRES}
