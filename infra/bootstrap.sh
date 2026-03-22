#!/usr/bin/env bash
# infra/bootstrap.sh
#
# One-time idempotent setup for GitHub Actions OIDC authentication with Azure.
# Creates (if missing): app registration, service principal, federated credential.
# Prints the values to store as GitHub environment variables.
#
# Prerequisites:
#   - az CLI authenticated with an account that has:
#       Application Administrator (or equivalent) in Entra ID
#       Owner on the target subscription (needed for role assignments via Bicep)
#
# Usage:
#   chmod +x infra/bootstrap.sh
#   ./infra/bootstrap.sh \
#     --app-name    "arcdemo-github-actions" \
#     --subscription-id "<SUBSCRIPTION_ID>" \
#     --github-org  "Jari63" \
#     --github-repo "ArcDemo"

set -euo pipefail

APP_DISPLAY_NAME=""
SUBSCRIPTION_ID=""
GITHUB_ORG=""
GITHUB_REPO=""
ENVIRONMENT="production"

while [[ $# -gt 0 ]]; do
  case $1 in
    --app-name)        APP_DISPLAY_NAME="$2"; shift 2 ;;
    --subscription-id) SUBSCRIPTION_ID="$2";  shift 2 ;;
    --github-org)      GITHUB_ORG="$2";       shift 2 ;;
    --github-repo)     GITHUB_REPO="$2";      shift 2 ;;
    --environment)     ENVIRONMENT="$2";      shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$APP_DISPLAY_NAME" || -z "$SUBSCRIPTION_ID" || -z "$GITHUB_ORG" || -z "$GITHUB_REPO" ]]; then
  echo "Usage: $0 --app-name NAME --subscription-id ID --github-org ORG --github-repo REPO" >&2
  exit 1
fi

TENANT_ID=$(az account show --subscription "$SUBSCRIPTION_ID" --query tenantId -o tsv)

echo "==> Ensuring app registration exists: $APP_DISPLAY_NAME"
APP_CLIENT_ID=$(az ad app list --display-name "$APP_DISPLAY_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)
if [[ -z "$APP_CLIENT_ID" || "$APP_CLIENT_ID" == "None" ]]; then
  echo "    Creating app registration..."
  APP_CLIENT_ID=$(az ad app create --display-name "$APP_DISPLAY_NAME" --query appId -o tsv)
  echo "    Created: $APP_CLIENT_ID"
else
  echo "    Already exists: $APP_CLIENT_ID"
fi

echo "==> Ensuring service principal exists"
SP_OBJECT_ID=$(az ad sp show --id "$APP_CLIENT_ID" --query id -o tsv 2>/dev/null || true)
if [[ -z "$SP_OBJECT_ID" || "$SP_OBJECT_ID" == "None" ]]; then
  echo "    Creating service principal..."
  SP_OBJECT_ID=$(az ad sp create --id "$APP_CLIENT_ID" --query id -o tsv)
  echo "    Created SP object ID: $SP_OBJECT_ID"
else
  echo "    Already exists: $SP_OBJECT_ID"
fi

echo "==> Ensuring federated credential exists for environment: $ENVIRONMENT"
SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${ENVIRONMENT}"
EXISTING=$(az ad app federated-credential list --id "$APP_CLIENT_ID" \
  --query "[?subject=='$SUBJECT'].id" -o tsv 2>/dev/null || true)
if [[ -z "$EXISTING" ]]; then
  echo "    Creating federated credential..."
  az ad app federated-credential create --id "$APP_CLIENT_ID" \
    --parameters "{
      \"name\": \"github-${ENVIRONMENT}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"$SUBJECT\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" > /dev/null
  echo "    Created."
else
  echo "    Already exists."
fi

echo ""
echo "==========================================================="
echo "Bootstrap complete. Set these in GitHub:"
echo "  Settings > Environments > ${ENVIRONMENT} > Environment variables"
echo ""
echo "  AZURE_CLIENT_ID       = $APP_CLIENT_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  AZURE_SP_OBJECT_ID    = $SP_OBJECT_ID"
echo ""
echo "Then run the Bicep template once with an account that has Owner"
echo "on the resource group to establish the Contributor role assignment:"
echo ""
echo "  az deployment group create \\"
echo "    --resource-group <YOUR_RESOURCE_GROUP> \\"
echo "    --template-file infra/main.bicep \\"
echo "    --parameters appName=<YOUR_APP_NAME> spObjectId=$SP_OBJECT_ID"
echo "==========================================================="
