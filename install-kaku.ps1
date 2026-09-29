$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{"User-Agent"="TomyFovos-Knowledge-Bootstrap";"Accept"="application/vnd.github+json"}
Write-Host "==> Fetching latest Kaku" -ForegroundColor Cyan
$release = Invoke-RestMethod -Headers $headers -Uri "https://api.github.com/repos/callmegema/kaku-official/releases/latest"
$asset = $release.assets | Where-Object { $_.name -match "(?i)^kaku_x64-setup\.exe$" } | Select-Object -First 1
if ($null -eq $asset) { throw "Kaku Windows x64 installer not found." }
$installer = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Headers $headers -Uri $asset.browser_download_url -OutFile $installer
Write-Host "Launching Kaku $($release.tag_name) installer..." -ForegroundColor Cyan
Start-Process -FilePath $installer -Wait
Write-Host "Open the same Knowledge repository folder in Kaku." -ForegroundColor Green
