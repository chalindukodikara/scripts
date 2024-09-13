#!/bin/bash

export NS_SYSTEM="dev-choreo-system"
export NS_APIM="dev-choreo-apim"
export KUBE_CONTEXT="choreo-dev-cp-cilium-cluster"
export HTTPS_PROXY=http://localhost:3128

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward deployment/app-service 3000:8080 &
PID_APP_SERVICE=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/cp-graphql 3001:9090 --address 0.0.0.0 &
PID_GRAPHQL=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/dp-rudder 3002:80 &
PID_RUDDER=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/configuration-service 3003:8080 --address 0.0.0.0 &
PID_CONFIGURATION_SERVICE=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/configuration-service 3004:8084 --address 0.0.0.0 &
PID_CONFIGURATION_MAPPING_SERVICE=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/devops-portal-api 3005:8089 --address 0.0.0.0 &
PID_DEV_OPS_API=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/subscriptions 3006:9090 --address 0.0.0.0 &
PID_SUBSCRIPTION=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/api-server 3007:80 --address 0.0.0.0 &
PID_API_SERVER=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/dp-secret-manager 3008:80 --address 0.0.0.0 &
PID_SECRET_MANAGER=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/dp-cloud-manager 3009:80 --address 0.0.0.0 &
PID_CLOUD_MANAGER=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/dp-mizzen 3010:80 --address 0.0.0.0 &
PID_MIZZEN=$!

kubectl -n ${NS_SYSTEM} --context=${KUBE_CONTEXT} port-forward service/dp-project-manager 3012:80 --address 0.0.0.0 &
PID_PROJECT_MANAGER=$!

# APIM
kubectl -n ${NS_APIM} --context=${KUBE_CONTEXT} port-forward service/choreo-am-service 3011:9763 --address 0.0.0.0 &
PID_APIM=$!

cleanup() {
  kill ${PID_APP_SERVICE} ${PID_GRAPHQL} ${PID_RUDDER} ${PID_CONFIGURATION_MAPPING_SERVICE} ${PID_CONFIGURATION_SERVICE} ${PID_DEV_OPS_API} ${PID_SUBSCRIPTION} ${PID_API_SERVER} ${PID_SECRET_MANAGER} ${PID_CLOUD_MANAGER} ${PID_MIZZEN} ${PID_APIM}
}
trap cleanup EXIT

wait ${PID_APP_SERVICE} ${PID_GRAPHQL} ${PID_RUDDER} ${PID_CONFIGURATION_MAPPING_SERVICE} ${PID_CONFIGURATION_SERVICE} ${PID_DEV_OPS_API} ${PID_SUBSCRIPTION} ${PID_API_SERVER} ${PID_SECRET_MANAGER} ${PID_CLOUD_MANAGER} ${PID_MIZZEN} ${PID_PROJECT_MANAGER} ${PID_APIM}
