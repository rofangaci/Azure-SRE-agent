#Requires -Version 7.0
<#
.SYNOPSIS
    Upload knowledge documents to the SRE Agent knowledge base.
.DESCRIPTION
    Reads all .md files from knowledge/ and uploads them via the ARM API.
.PARAMETER AgentResourceId
    Full ARM resource ID of the agent.
.EXAMPLE
    ./upload-knowledge.ps1 -AgentResourceId "/subscriptions/.../providers/Microsoft.App/agents/networking-audit-agent"
#>

param(
    [Parameter(Mandatory)][string]$AgentResourceId
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

# ── Paths ──────────────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KnowledgeDir = Join-Path $ScriptDir ".." "knowledge"

# ── Token ──────────────────────────────────────────────────────
$token = az account get-access-token --query accessToken -o tsv 2>$null
if (-not $token) {
    throw "Failed to get access token. Run 'az login' first."
}

$apiBase = "https://management.azure.com$AgentResourceId"
$apiVersion = "2025-01-01-preview"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

# ── Upload ─────────────────────────────────────────────────────
Write-Host "`n=== Uploading knowledge documents ===" -ForegroundColor Cyan
Write-Host "Agent: $AgentResourceId`n"

$success = 0
$failed = 0

Get-ChildItem -Path $KnowledgeDir -Filter "*.md" | ForEach-Object {
    $fileName = $_.Name
    Write-Host "  Uploading: $fileName..."

    $content = Get-Content $_.FullName -Raw
    $payload = @{
        properties = @{
            displayName = $fileName
            content     = $content
            contentType = "markdown"
        }
    } | ConvertTo-Json -Depth 5

    try {
        $uri = "$apiBase/knowledge/$($fileName)?api-version=$apiVersion"
        $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $payload
        Write-Host "    Success" -ForegroundColor Green
        $script:success++
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "    Failed (HTTP $statusCode)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "`n=== Upload Complete ===" -ForegroundColor Green
Write-Host "  Success: $success"
Write-Host "  Failed:  $failed"

if ($failed -gt 0) {
    Write-Host "`nIf uploads failed, you can upload manually:" -ForegroundColor Yellow
    Write-Host "  UI: Go to the agent at https://sre.azure.com -> Knowledge -> Upload"
}
