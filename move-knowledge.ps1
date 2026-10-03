param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string]$FolderList,
    [switch]$Execute
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$totalFiles = 0L
$totalBytes = 0L
$logPath = $null
try {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Source directory does not exist: $Source" }
    $sourceFullPath = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')
    $destinationFullPath = [System.IO.Path]::GetFullPath($Destination).TrimEnd('\')
    if ($sourceFullPath -eq $destinationFullPath -or $destinationFullPath.StartsWith($sourceFullPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Destination must differ from source and must not be inside it.'
    }
    foreach ($folder in $FolderList.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $sourceFolder = Join-Path $Source $folder
        $destinationFolder = Join-Path $Destination $folder
        if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) {
            Write-Host ('{0,-20} SKIP (source folder missing)' -f $folder)
            continue
        }
        $logPath = [System.IO.Path]::GetTempFileName()
        # Copy and overwrite only. Never use /MOVE, /MOV, /MIR, or /PURGE.
        # /IS /IT also overwrite identical/tweaked files; older source files are
        # copied too. /XJ excludes junctions. Unicode logs preserve Japanese names.
        $copyArguments = @($sourceFolder, $destinationFolder, '/E', '/IS', '/IT', '/XJ', '/R:2', '/W:2', '/BYTES', '/NP', "/UNILOG:$logPath")
        if (-not $Execute) { $copyArguments += @('/L', '/NFL', '/NDL', '/NJH') } else { Write-Host "Processing: $folder" }
        & robocopy.exe @copyArguments *> $null
        $copyExitCode = $LASTEXITCODE
        $output = @(Get-Content -LiteralPath $logPath -Encoding Unicode)
        Remove-Item -LiteralPath $logPath -Force
        $logPath = $null
        if ($Execute) { Write-Host ($output -join [Environment]::NewLine) }
        if ($copyExitCode -ge 8) {
            if (-not $Execute) { Write-Host ($output -join [Environment]::NewLine) }
            throw "Robocopy failed for $folder (exit code $copyExitCode)."
        }
        if ($Execute) { continue }
        $summary = @(
            foreach ($line in $output) {
                if ([string]$line -match '^\s*[^:]+:\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*$') { [long]$Matches[2] }
            }
        )
        if ($summary.Count -ne 3) { throw "Could not read Robocopy summary for $folder." }
        $totalFiles += $summary[1]
        $totalBytes += $summary[2]
        Write-Host ('{0,-20} {1,6} files  {2,10:N2} MiB' -f $folder, $summary[1], ($summary[2] / 1MB))
    }
    if (-not $Execute) { Write-Host ('{0,-20} {1,6} files  {2,10:N2} MiB' -f 'TOTAL', $totalFiles, ($totalBytes / 1MB)) }
    exit 0
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message)
    exit 1
} finally {
    if ($logPath -and (Test-Path -LiteralPath $logPath)) { Remove-Item -LiteralPath $logPath -Force }
}
