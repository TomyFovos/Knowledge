param([string]$VaultPath = $PSScriptRoot)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Install-Plugin([string]$Id, [string]$Repo) {
  $dir = Join-Path $VaultPath ".obsidian\plugins\$Id"
  Ensure-Dir $dir
  Write-Host "==> Installing/updating $Id" -ForegroundColor Cyan
  $headers = @{"User-Agent"="TomyFovos-Knowledge-Bootstrap";"Accept"="application/vnd.github+json"}
  $release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/$Repo/releases/latest"
  foreach ($name in @("main.js","manifest.json","styles.css")) {
    $asset = $release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($null -ne $asset) {
      Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile (Join-Path $dir $name)
    }
  }
  if (-not (Test-Path (Join-Path $dir "main.js"))) { throw "${Id}: main.js missing" }
  if (-not (Test-Path (Join-Path $dir "manifest.json"))) { throw "${Id}: manifest.json missing" }
  Write-Host "    $Id $($release.tag_name)" -ForegroundColor Green
}

if ([string]::IsNullOrWhiteSpace($VaultPath)) { $VaultPath = $PSScriptRoot }
$VaultPath = $VaultPath.Trim('"')
$VaultPath = (Resolve-Path -LiteralPath $VaultPath).Path

foreach ($d in @(
  ".obsidian\plugins",".obsidian\snippets",
  "Inbox","Notes","Sources","Assets\Images","Assets\Files",
  "Workspace\Dashboard","Workspace\Templates","Workspace\System"
)) { Ensure-Dir (Join-Path $VaultPath $d) }

Install-Plugin "hearth" "ondreu/Hearth"
Install-Plugin "dataview" "blacksmithgu/obsidian-dataview"
Install-Plugin "single-html-export" "DDEOK/Obsidian-Single-HTML-Export"

Write-Host ""
Write-Host "Obsidian setup complete." -ForegroundColor Green
Write-Host "Open this repository as both the Obsidian Vault and Kaku Workspace." -ForegroundColor Yellow
