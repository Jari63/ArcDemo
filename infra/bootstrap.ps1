#Requires -Version 7
<#
.SYNOPSIS
    One-time idempotent setup for GitHub Actions OIDC authentication with Azure.

.DESCRIPTION
    Creates (if missing): app registration, service principal, federated credential.
    Prints the values to store as GitHub environment variables.

    Prerequisites:
      - az CLI authenticated with an account that has:
          Application Administrator (or equivalent) in Entra ID
          Owner on the target subscription (needed for role assignments via Bicep)

.EXAMPLE
    ./infra/bootstrap.ps1 `
        -AppName "arcdemo-github-actions" `
        -SubscriptionId "<SUBSCRIPTION_ID>" `
        -GitHubOrg "Jari63" `
        -GitHubRepo "ArcDemo"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppName,
    [Parameter(Mandatory)][string] $SubscriptionId,
    [Parameter(Mandatory)][string] $GitHubOrg,
    [Parameter(Mandatory)][string] $GitHubRepo,
    [string] $Environment = 'production'
)

$ErrorActionPreference = 'Stop'

$tenantId = az account show --subscription $SubscriptionId --query tenantId -o tsv

Write-Host "==> Ensuring app registration exists: $AppName"
$appClientId = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($appClientId) -or $appClientId -eq 'None') {
    Write-Host "    Creating app registration..."
    $appClientId = az ad app create --display-name $AppName --query appId -o tsv
    Write-Host "    Created: $appClientId"
} else {
    Write-Host "    Already exists: $appClientId"
}

Write-Host "==> Ensuring service principal exists"
$spObjectId = az ad sp show --id $appClientId --query id -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($spObjectId) -or $spObjectId -eq 'None') {
    Write-Host "    Creating service principal..."
    $spObjectId = az ad sp create --id $appClientId --query id -o tsv
    Write-Host "    Created SP object ID: $spObjectId"
} else {
    Write-Host "    Already exists: $spObjectId"
}

Write-Host "==> Ensuring federated credential exists for environment: $Environment"
$subject = "repo:${GitHubOrg}/${GitHubRepo}:environment:${Environment}"
$existing = az ad app federated-credential list --id $appClientId `
    --query "[?subject=='$subject'].id" -o tsv 2>$null
if ([string]::IsNullOrWhiteSpace($existing)) {
    Write-Host "    Creating federated credential..."
    $credJson = @{
        name      = "github-$Environment"
        issuer    = 'https://token.actions.githubusercontent.com'
        subject   = $subject
        audiences = @('api://AzureADTokenExchange')
    } | ConvertTo-Json -Compress
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        $credJson | Set-Content -Path $tempFile -Encoding utf8
        az ad app federated-credential create --id $appClientId --parameters "@$tempFile" | Out-Null
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
    Write-Host "    Created."
} else {
    Write-Host "    Already exists."
}

Write-Host ""
Write-Host "==========================================================="
Write-Host "Bootstrap complete. Set these in GitHub:"
Write-Host "  Settings > Environments > $Environment > Environment variables"
Write-Host ""
Write-Host "  AZURE_CLIENT_ID       = $appClientId"
Write-Host "  AZURE_TENANT_ID       = $tenantId"
Write-Host "  AZURE_SUBSCRIPTION_ID = $SubscriptionId"
Write-Host "  AZURE_SP_OBJECT_ID    = $spObjectId"
Write-Host ""
Write-Host "Then run the Bicep template once with an account that has Owner"
Write-Host "on the resource group to establish the Contributor role assignment:"
Write-Host ""
Write-Host "  az deployment group create ``"
Write-Host "    --resource-group <YOUR_RESOURCE_GROUP> ``"
Write-Host "    --template-file infra/main.bicep ``"
Write-Host "    --parameters appName=<YOUR_APP_NAME> spObjectId=$spObjectId"
Write-Host "==========================================================="
