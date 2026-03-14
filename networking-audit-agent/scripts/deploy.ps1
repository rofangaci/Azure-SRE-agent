#Requires -Version 7.0
<#
.SYNOPSIS
    Deploy networking-audit-agent infrastructure.
.DESCRIPTION
    Deploys the managed identity and supporting resources via Bicep.
.PARAMETER Environment
    Target environment (dev or prod).
.PARAMETER SubscriptionId
    Azure subscription ID.
.PARAMETER ResourceGroup
    Target resource group name.
.PARAMETER Location
    Azure region. Defaults to eastus2. Allowed: eastus2, swedencentral, australiaeast.
.EXAMPLE
    ./deploy.ps1 -Environment dev -SubscriptionId "12345678-..." -ResourceGroup "rg-networking-audit"
#>

param(
    [Parameter(Mandatory)][ValidateSet("dev", "prod")][string]$Environment,
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [ValidateSet("eastus2", "swedencentral", "australiaeast")]
    [string]$Location = "eastus2"
)

$ErrorActionPreference = "Stop"

# ── Prerequisites ──────────────────────────────────────────────
function Test-Prerequisites {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is required but not installed. Install from https://aka.ms/installazurecli"
    }
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in to Azure CLI. Run 'az login' first."
    }
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
}

Test-Prerequisites

# ── Paths ──────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InfraDir = Join-Path $ScriptDir ".." "infra"
$ParamsFile = Join-Path $InfraDir "parameters" "$Environment.bicepparam"

if (-not (Test-Path $ParamsFile)) {
    $available = Get-ChildItem (Join-Path $InfraDir "parameters") -Filter "*.bicepparam" | ForEach-Object { $_.BaseName }
    throw "Parameter file not found: $ParamsFile. Available: $($available -join ', ')"
}

# ── Deploy ─────────────────────────────────────────────────────
Write-Host "`n=== Deploying networking-audit-agent ===" -ForegroundColor Cyan
Write-Host "Environment:    $Environment"
Write-Host "Subscription:   $SubscriptionId"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location:       $Location`n"

az account set --subscription $SubscriptionId

Write-Host "Ensuring resource group exists..."
az group create `
    --name $ResourceGroup `
    --location $Location `
    --tags project=networking-audit-agent environment=$Environment `
    --output none 2>$null

Write-Host "Deploying infrastructure..."
$output = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file (Join-Path $InfraDir "main.bicep") `
    --parameters $ParamsFile `
    --parameters location=$Location `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

$principalId = $output.managedIdentityPrincipalId.value
$clientId = $output.managedIdentityClientId.value
$miResourceId = $output.managedIdentityResourceId.value

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Managed Identity Client ID:    $clientId"
Write-Host "Managed Identity Principal ID: $principalId"
Write-Host "Managed Identity Resource ID:  $miResourceId"
Write-Host "`nNext steps:"
Write-Host "  1. Create the agent at https://sre.azure.com"
Write-Host "  2. Assign the user-assigned managed identity: $miResourceId"
Write-Host "  3. Run ./setup-rbac.ps1 -PrincipalId $principalId -SubscriptionIds <sub-id>"
Write-Host "  4. Run ./upload-knowledge.ps1 -AgentResourceId <agent-resource-id>"
