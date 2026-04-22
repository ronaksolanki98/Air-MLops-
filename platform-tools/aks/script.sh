#!/bin/bash

set -euo pipefail

ACTION=${1:-}

# -------- Config --------
RESOURCE_GROUP="mlops-rg"
LOCATION="centralindia"
AKS_CLUSTER_NAME="mlops-aks-cluster"
NAMESPACE="airflow"
SERVICE_ACCOUNT="airflow-dvc-sa"
STORAGE_ACCOUNT_NAME="mlopsattritionstore"
STORAGE_CONTAINER_NAME="dvc-data"
AZURE_STORAGE_SECRET_NAME="azure-storage"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1"
    exit 1
  }
}

create_resources() {
  require_cmd az
  require_cmd kubectl

  echo "Checking Azure login..."
  az account show >/dev/null

  echo "Loading AKS credentials..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

  echo "Ensuring resource group exists..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

  echo "Ensuring storage account exists..."
  az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --output none

  echo "Fetching storage connection string..."
  STORAGE_CONNECTION_STRING=$(az storage account show-connection-string \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --query connectionString \
    --output tsv)

  echo "Ensuring blob container exists..."
  az storage container create \
    --name "$STORAGE_CONTAINER_NAME" \
    --connection-string "$STORAGE_CONNECTION_STRING" \
    --output none

  echo "Creating namespace and service account..."
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl create serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

  echo "Creating Azure storage secret..."
  kubectl create secret generic "$AZURE_STORAGE_SECRET_NAME" \
    --from-literal=AZURE_STORAGE_CONNECTION_STRING="$STORAGE_CONNECTION_STRING" \
    --from-literal=AZURE_STORAGE_CONTAINER_NAME="$STORAGE_CONTAINER_NAME" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "Create completed."
}

delete_resources() {
  require_cmd az
  require_cmd kubectl

  echo "Loading AKS credentials..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

  echo "Deleting Kubernetes resources..."
  kubectl delete secret "$AZURE_STORAGE_SECRET_NAME" -n "$NAMESPACE" || true
  kubectl delete serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" || true
  kubectl delete namespace "$NAMESPACE" || true

  echo "Deleting Azure blob container..."
  az storage container delete \
    --name "$STORAGE_CONTAINER_NAME" \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --auth-mode login \
    --output none || true

  echo "Delete completed."
}

if [[ "$ACTION" == "create" ]]; then
  create_resources
elif [[ "$ACTION" == "delete" ]]; then
  delete_resources
else
  echo "Usage: $0 {create|delete}"
  exit 1
fi
