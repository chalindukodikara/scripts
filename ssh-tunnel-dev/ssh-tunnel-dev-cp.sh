#!/bin/bash

# This script creates SSH tunnels to the bastion host for accessing Kubectl and MSSQL in Choreo Dev Control Plane.
# Please read https://docs.google.com/document/d/10u9AFnb52TR6wNSg_Z82TAjayDjJ7JYnmZmwHoqbxR0/edit#heading=h.hyo5f6n0qu4t before using this script.
# Usage: ./ssh-dev-cp.sh [--debug] <username>

BASTION_HOSTNAME=choreo-dev-cp-hub-bastion-001
BASTION_CERT_DIR=/tmp/${BASTION_HOSTNAME}

AZ_SUBSCRIPTION=choreo-dev-hub-001
AZ_CLI_EXTRA_ARGS=""

SSH_PRIVATE_KEY=${BASTION_CERT_DIR}/id_rsa
SSH_CERTIFICATE=${BASTION_CERT_DIR}/id_rsa-aadcert.pub

SSH_BASTION_TUNNEL_HOST_KUBECTL=localhost
SSH_BASTION_TUNNEL_PORT_KUBECTL=50222
SSH_TUNNEL_HOST_KUBECTL=0.0.0.0
SSH_TUNNEL_PORT_KUBECTL=3128

SSH_BASTION_TUNNEL_HOST_MSSQL=localhost
SSH_BASTION_TUNNEL_PORT_MSSQL=50223
SSH_TUNNEL_HOST_MSSQL=0.0.0.0
SSH_TUNNEL_PORT_MSSQL=1434

SSH_BASTION_TUNNEL_HOST_MONGO_DB=localhost
SSH_BASTION_TUNNEL_PORT_MONGO_DB=50224
SSH_TUNNEL_HOST_MONGO_DB=0.0.0.0
SSH_TUNNEL_PORT_MONGO_DB=27017

SSH_BASTION_TUNNEL_HOST_POSTGRESQL=localhost
SSH_BASTION_TUNNEL_PORT_POSTGRESQL=50225
SSH_TUNNEL_HOST_POSTGRESQL=0.0.0.0
SSH_TUNNEL_PORT_POSTGRESQL=5435

SSH_CLI_EXTRA_ARGS=""

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

if [ ${#ARGS[@]} -ne 1 ]; then
    echo "Required argument <username> is missing"
    echo "Usage: $0 [--debug] <username>"
    echo -e "\t--debug: Enable debug mode"
    echo -e "\t<username>: Username to login to the bastion. If the email is 'john@wso2.com' then use 'john' as the username"
    echo "Example: $0 --debug john"
    exit 1
fi

USERNAME=${ARGS[0]}
echo "Username: ${USERNAME}"

# If debug mode is enabled, enable debug mode for az cli and ssh
if [ "${DEBUG_MODE}" = true ]; then
    AZ_CLI_EXTRA_ARGS+=" --debug"
    SSH_CLI_EXTRA_ARGS+=" -v"
fi

# ================= Certtificate generation =================

# Delete the bastion cert dir if it exists
if [ -d ${BASTION_CERT_DIR} ]; then
  rm -rf ${BASTION_CERT_DIR}
fi

mkdir -p ${BASTION_CERT_DIR}

# Generate AAD cert
echo "Generating Azure AD certificate for SSH..."
az ssh cert --file ${BASTION_CERT_DIR}/id_rsa-aadcert.pub --subscription ${AZ_SUBSCRIPTION}

# ================= Add /etc/hosts entry if not exists =================

if ! grep -q "${BASTION_HOSTNAME}" /etc/hosts; then
    echo "127.0.0.1 ${BASTION_HOSTNAME}" | sudo tee -a /etc/hosts > /dev/null
    echo "Added entry ${BASTION_HOSTNAME} to /etc/hosts."
fi

# ================= SSH Tunneling for Kubectl =================

# Tunnel to the bastion for Kubectl in background
echo "Creating bastion tunnel for Kubectl..."
az network bastion tunnel --name "choreo-dev-bastion-host" --resource-group "choreo-dev-hub-network-rg" \
    --target-resource-id "/subscriptions/7b752720-628c-42fd-8c1d-14b216d7c520/resourceGroups/choreo-dev-hub-network-rg/providers/Microsoft.Compute/virtualMachines/${BASTION_HOSTNAME}" \
    --subscription choreo-dev-hub-001 --resource-port 22 --port ${SSH_BASTION_TUNNEL_PORT_KUBECTL} ${AZ_CLI_EXTRA_ARGS} &
PID_BASTION_TUNNEL_KUBECTL=$!

# Wait for bastion tunnel to be available for Kubectl
wait_for_tunnel_port "Kubectl" "bastion" "${SSH_BASTION_TUNNEL_HOST_KUBECTL}" "${SSH_BASTION_TUNNEL_PORT_KUBECTL}"


# SSH Tunnel for Kubectl
echo "Creating SSH tunnel for kubectl..."
ssh  -p ${SSH_BASTION_TUNNEL_PORT_KUBECTL} ${USERNAME}@wso2.com@${BASTION_HOSTNAME}  -i ${SSH_PRIVATE_KEY} \
    -o "CertificateFile=${SSH_CERTIFICATE}" -o "StrictHostKeyChecking no" \
    -o 'ServerAliveInterval=30' -o 'ServerAliveCountMax=5' \
    -L ${SSH_TUNNEL_HOST_KUBECTL}:${SSH_TUNNEL_PORT_KUBECTL}:127.0.0.1:${SSH_TUNNEL_PORT_KUBECTL} -N ${SSH_CLI_EXTRA_ARGS} &
PID_SSH_TUNNEL_KUBECTL=$!

# Wait for SSH tunnel to be available for Kubectl
wait_for_tunnel_port "Kubectl" "SSH" "${SSH_TUNNEL_HOST_KUBECTL}" "${SSH_TUNNEL_PORT_KUBECTL}"


# ================= SSH Tunneling for MSSQL =================

# Tunnel to the bastion for MSSQL in background
echo "Creating bastion tunnel for MSSQL..."
az network bastion tunnel --name "choreo-dev-bastion-host" --resource-group "choreo-dev-hub-network-rg" \
    --target-resource-id "/subscriptions/7b752720-628c-42fd-8c1d-14b216d7c520/resourceGroups/choreo-dev-hub-network-rg/providers/Microsoft.Compute/virtualMachines/${BASTION_HOSTNAME}" \
    --subscription choreo-dev-hub-001 --resource-port 22 --port ${SSH_BASTION_TUNNEL_PORT_MSSQL} ${AZ_CLI_EXTRA_ARGS} &
PID_BASTION_TUNNEL_MSSQL=$!

# Wait for bastion tunnel to be available for MSSQL
wait_for_tunnel_port "MSSQL" "bastion" "${SSH_BASTION_TUNNEL_HOST_MSSQL}" "${SSH_BASTION_TUNNEL_PORT_MSSQL}"


# SSH Tunnel for MSSQL
echo "Creating SSH tunnel for MSSQL..."
ssh  -p ${SSH_BASTION_TUNNEL_PORT_MSSQL} ${USERNAME}@wso2.com@${BASTION_HOSTNAME}  -i ${SSH_PRIVATE_KEY} \
    -o "CertificateFile=${SSH_CERTIFICATE}" -o "StrictHostKeyChecking no" \
    -o 'ServerAliveInterval=30' -o 'ServerAliveCountMax=5' \
    -L ${SSH_TUNNEL_HOST_MSSQL}:${SSH_TUNNEL_PORT_MSSQL}:choreo-dev-ctrl-plane-mssql.database.windows.net:1433 -N ${SSH_CLI_EXTRA_ARGS} &
PID_SSH_TUNNEL_MSSQL=$!

# Wait for SSH tunnel to be available for MSSQL
wait_for_tunnel_port "MSSQL" "SSH" "${SSH_TUNNEL_HOST_MSSQL}" "${SSH_TUNNEL_PORT_MSSQL}"


# ================= SSH Tunneling for MongoDB =================

# Tunnel to the bastion for MongoDB in background
echo "Creating bastion tunnel for MongoDB..."
az network bastion tunnel --name "choreo-dev-bastion-host" --resource-group "choreo-dev-hub-network-rg" \
    --target-resource-id "/subscriptions/7b752720-628c-42fd-8c1d-14b216d7c520/resourceGroups/choreo-dev-hub-network-rg/providers/Microsoft.Compute/virtualMachines/${BASTION_HOSTNAME}" \
    --subscription choreo-dev-hub-001 --resource-port 22 --port ${SSH_BASTION_TUNNEL_PORT_MONGO_DB} ${AZ_CLI_EXTRA_ARGS} &
PID_BASTION_TUNNEL_MONGO_DB=$!

# Wait for bastion tunnel to be available for MongoDB
wait_for_tunnel_port "MongoDB" "bastion" "${SSH_BASTION_TUNNEL_HOST_MONGO_DB}" "${SSH_BASTION_TUNNEL_PORT_MONGO_DB}"


# SSH Tunnel for MongoDB
echo "Creating SSH tunnel for MongoDB..."
ssh  -p ${SSH_BASTION_TUNNEL_PORT_MONGO_DB} ${USERNAME}@wso2.com@${BASTION_HOSTNAME}  -i ${SSH_PRIVATE_KEY} \
    -o "CertificateFile=${SSH_CERTIFICATE}" -o "StrictHostKeyChecking no" \
    -o 'ServerAliveInterval=30' -o 'ServerAliveCountMax=5' \
    -L ${SSH_TUNNEL_HOST_MONGO_DB}:${SSH_TUNNEL_PORT_MONGO_DB}:pl-1-eastus2-azure.hu3zq.mongodb.net:1025 -N ${SSH_CLI_EXTRA_ARGS} &
PID_SSH_TUNNEL_MONGO_DB=$!

# Wait for SSH tunnel to be available for MongoDB
wait_for_tunnel_port "MongoDB" "SSH" "${SSH_TUNNEL_HOST_MONGO_DB}" "${SSH_TUNNEL_PORT_MONGO_DB}"

# ================= SSH Tunneling for PostgreSQL =================

# Tunnel to the bastion for PostgreSQL in background
echo "Creating bastion tunnel for PostgreSQL..."
az network bastion tunnel --name "choreo-dev-bastion-host" --resource-group "choreo-dev-hub-network-rg" \
    --target-resource-id "/subscriptions/7b752720-628c-42fd-8c1d-14b216d7c520/resourceGroups/choreo-dev-hub-network-rg/providers/Microsoft.Compute/virtualMachines/${BASTION_HOSTNAME}" \
    --subscription choreo-dev-hub-001 --resource-port 22 --port ${SSH_BASTION_TUNNEL_PORT_POSTGRESQL} ${AZ_CLI_EXTRA_ARGS} &
PID_BASTION_TUNNEL_MONGO_DB=$!

# Wait for bastion tunnel to be available for PostgreSQL
wait_for_tunnel_port "PostgreSQL" "bastion" "${SSH_BASTION_TUNNEL_HOST_POSTGRESQL}" "${SSH_BASTION_TUNNEL_PORT_POSTGRESQL}"


# SSH Tunnel for PostgreSQL
echo "Creating SSH tunnel for PostgreSQL..."
ssh  -p ${SSH_BASTION_TUNNEL_PORT_POSTGRESQL} ${USERNAME}@wso2.com@${BASTION_HOSTNAME}  -i ${SSH_PRIVATE_KEY} \
    -o "CertificateFile=${SSH_CERTIFICATE}" -o "StrictHostKeyChecking no" \
    -o 'ServerAliveInterval=30' -o 'ServerAliveCountMax=5' \
    -L ${SSH_TUNNEL_HOST_POSTGRESQL}:${SSH_TUNNEL_PORT_POSTGRESQL}:postgresql-choreo-dev-eastus2-api-001.postgres.database.azure.com:5432 -N ${SSH_CLI_EXTRA_ARGS} &
PID_SSH_TUNNEL_POSTGRESQL=$!

# Wait for SSH tunnel to be available for PostgreSQL
wait_for_tunnel_port "PostgreSQL" "SSH" "${SSH_TUNNEL_HOST_POSTGRESQL}" "${SSH_TUNNEL_PORT_POSTGRESQL}"

# ================= Cleanup =================

# Kill the background processes on Ctrl+C
cleanup() {
  kill ${PID_SSH_TUNNEL_KUBECTL} ${PID_BASTION_TUNNEL_KUBECTL} ${PID_SSH_TUNNEL_MSSQL} ${PID_BASTION_TUNNEL_MSSQL}
  echo "Successfully exited"
}
trap cleanup EXIT

echo "Press Ctrl+C to exit the script"

# Wait for background process to complete
wait ${PID_SSH_TUNNEL_KUBECTL} ${PID_BASTION_TUNNEL_KUBECTL} ${PID_SSH_TUNNEL_MSSQL} ${PID_BASTION_TUNNEL_MSSQL} ${PID_SSH_TUNNEL_MONGO_DB} ${PID_BASTION_TUNNEL_MONGO_DB} ${PID_SSH_TUNNEL_POSTGRESQL}
