#Requires -Version 7.0
<#
.SYNOPSIS
    Grant RBAC access for the networking-audit-agent managed identity.
.DESCRIPTION
    Assigns Reader and Network Contributor roles on target subscriptions.
    See docs/SECURITY.md for role justification and least-privilege alternatives.
.PARAMETER PrincipalId
    The managed identity's principal (object) ID.
.PARAMETER SubscriptionIds
    One or more subscription IDs to grant access to.
.EXAMPLE
    ./setup-rbac.ps1 -PrincipalId "abc-123" -SubscriptionIds "sub-1", "sub-2"
#>

param(
    [Parameter(Mandatory)][string]$PrincipalId,
    [Parameter(Mandatory)][string[]]$SubscriptionIds
)

$ErrorActionPreference = "Stop"

# ── Prerequisites ──────────────────────────────────────────────
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is required but not installed."
}
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Not logged in to Azure CLI. Run 'az login' first."
}

# ── Roles ──────────────────────────────────────────────────────
$Roles = @(
    @{ Id = "acdd72a7-3385-48ef-bd42-f606fba81ae7"; Name = "Reader" }
    @{ Id = "4d97b98b-1d4f-4787-a291-c67834d212e7"; Name = "Network Contributor" }
)

Write-Host "`n=== Setting up RBAC for networking-audit-agent ===" -ForegroundColor Cyan
Write-Host "Principal ID: $PrincipalId"
Write-Host "Roles: $($Roles.Name -join ', ')"
Write-Host "See docs/SECURITY.md for role justification.`n"

foreach ($subId in $SubscriptionIds) {
    Write-Host "--- Subscription: $subId ---"
    foreach ($role in $Roles) {
        Write-Host "  Assigning: $($role.Name)"
        try {
            az role assignment create `
                --assignee-object-id $PrincipalId `
                --assignee-principal-type ServicePrincipal `
                --role $role.Id `
                --scope "/subscriptions/$subId" `
                --output none 2>$null
        } catch {
            Write-Host "    (already assigned or insufficient permissions)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

Write-Host "=== RBAC setup complete ===" -ForegroundColor Green
Write-Host "`nVerify with:"
Write-Host "  az role assignment list --assignee $PrincipalId --all --output table"
