# FM27 Synced Launcher - see README.md for setup, rules and recovery.

# ---------------- Config ----------------
$SaveDir     = ""          # Blank = auto-detect. Or set the full path to your FM27 'games' folder.
$BackupDir   = "$env:USERPROFILE\Saved Games\FM27 Cloud Saves"   # Keep this OUTSIDE OneDrive.
$KeepBackups = 6           # Pre + post per session, so 6 = last 3 sessions.
$SteamAppId  = "4530370"   # FM27 on Steam.
$GameProcess = "fm"        # FM27 process name (fm.exe), without .exe.
$SyncTimeoutMins = 15      # Max time to wait for OneDrive to finish uploading after you quit.
# ----------------------------------------

$ErrorActionPreference = 'Stop'

function Exit-Launcher($msg) {
    Write-Host $msg -ForegroundColor Yellow
    Read-Host "Press Enter to close"
    exit
}

# Find the saves folder
if (-not $SaveDir) {
    $relative   = "Sports Interactive\Football Manager 27\games"
    $candidates = @(
        [Environment]::GetFolderPath('MyDocuments')
        if ($env:OneDrive)           { "$env:OneDrive\Documents" }
        if ($env:OneDriveConsumer)   { "$env:OneDriveConsumer\Documents" }
        if ($env:OneDriveCommercial) { "$env:OneDriveCommercial\Documents" }
        "$env:USERPROFILE\Documents"
    ) | Where-Object { $_ } | ForEach-Object { Join-Path $_ $relative } | Select-Object -Unique

    $SaveDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $SaveDir) {
        Exit-Launcher "Couldn't find your FM27 saves folder. Looked in:`n$($candidates -join "`n")`nSet `$SaveDir at the top of the script."
    }
}
if (-not (Test-Path $SaveDir)) { Exit-Launcher "Save folder not found: $SaveDir" }

# Check whether the saves folder is inside OneDrive
$oneDriveRoots = @($env:OneDrive, $env:OneDriveConsumer, $env:OneDriveCommercial) | Where-Object { $_ }
$UsesOneDrive  = [bool]($oneDriveRoots | Where-Object { $SaveDir.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })

Write-Host ""
Write-Host "Saves folder: $SaveDir" -ForegroundColor DarkGray
if (-not $UsesOneDrive) {
    Write-Host "Note: this folder isn't in OneDrive, so saves won't sync between PCs. Backups will still be taken." -ForegroundColor Yellow
}

# Pin saves as "always keep on this device"
if ($UsesOneDrive) {
    attrib +P -U "$SaveDir" | Out-Null
    attrib +P -U "$SaveDir\*" /S /D | Out-Null
}

# Stop if any save is still cloud-only
$saves = Get-ChildItem $SaveDir -Filter *.fm
$notLocal = $saves | Where-Object { ([int]$_.Attributes -band 0x400000) -or ([int]$_.Attributes -band 0x1000) }
if ($notLocal) {
    Exit-Launcher "These saves aren't fully downloaded yet:`n$($notLocal.Name -join "`n")`nGive OneDrive a minute and try again."
}

# Show the newest save and confirm
$latest = $saves | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latest) {
    Write-Host ""
    Write-Host "Newest save: $($latest.Name)" -ForegroundColor Cyan
    Write-Host "Saved:       $($latest.LastWriteTime.ToString('ddd dd/MM/yyyy HH:mm'))" -ForegroundColor Cyan
    $answer = Read-Host "Is this the save you expect? (Y/N)"
    if ($answer -notmatch '^[Yy]') { Exit-Launcher "Aborted. Let OneDrive finish syncing (check the tray icon), then try again." }
} else {
    Write-Host "No saves yet - launching anyway." -ForegroundColor Yellow
}

# Copy the newest save to $BackupDir, keeping the last $KeepBackups
function Backup-Save($label) {
    $newest = Get-ChildItem $SaveDir -Filter *.fm | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { return }
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    # Skip if this exact save (same name + modified time) is already backed up
    $dupe = Get-ChildItem $BackupDir -Filter "* - $($newest.Name)" |
        Where-Object { $_.Name -match '^\d{8}-\d{6} - ' -and $_.LastWriteTime -eq $newest.LastWriteTime }
    if ($dupe) {
        Write-Host "Save unchanged since last backup - skipping $label-session backup." -ForegroundColor DarkGray
        return
    }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Copy-Item $newest.FullName (Join-Path $BackupDir "$stamp - $label - $env:COMPUTERNAME - $($newest.Name)")
    Get-ChildItem $BackupDir -Filter *.fm |
        Where-Object { $_.Name -match '^\d{8}-\d{6} - ' } |   # Only prune this script's own backups
        Sort-Object Name -Descending |
        Select-Object -Skip $KeepBackups |
        Remove-Item
    Write-Host "Backup taken ($label-session)." -ForegroundColor Green
}

Backup-Save "pre"

# Remember the newest save's timestamp so we can tell later whether anything was saved
$preSave = Get-ChildItem $SaveDir -Filter *.fm | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Stop OneDrive while playing (only if it's running and the saves are in it)
$od = $null
if ($UsesOneDrive) { $od = Get-Process OneDrive -ErrorAction SilentlyContinue | Select-Object -First 1 }
$OneDriveExe = if ($od) { $od.Path } else { $null }

try {
    if ($od) {
        Start-Process $OneDriveExe -ArgumentList '/shutdown'
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Process OneDrive -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep 1 }
        if (Get-Process OneDrive -ErrorAction SilentlyContinue) { Stop-Process -Name OneDrive -Force }
        Write-Host "OneDrive paused." -ForegroundColor Green
    }

    # Launch FM, wait for it to start, then wait for it to close
    Start-Process "steam://rungameid/$SteamAppId"
    $deadline = (Get-Date).AddMinutes(3)
    while (-not (Get-Process $GameProcess -ErrorAction SilentlyContinue)) {
        if ((Get-Date) -gt $deadline) { throw "FM didn't start within 3 minutes - check `$GameProcess / `$SteamAppId." }
        Start-Sleep 3
    }
    Write-Host "FM is running. Leave this window open until you quit FM." -ForegroundColor Cyan
    Wait-Process -Name $GameProcess

    # Let the final save write finish, then back up this session before OneDrive restarts
    Start-Sleep 10
    $postSave = Get-ChildItem $SaveDir -Filter *.fm | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($postSave -and (-not $preSave -or $postSave.FullName -ne $preSave.FullName -or $postSave.LastWriteTime -ne $preSave.LastWriteTime)) {
        Backup-Save "post"
    } else {
        Write-Host "No new save this session - skipping post-session backup." -ForegroundColor DarkGray
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    # Restart OneDrive if we stopped it - it then uploads the finished save
    if ($od) {
        Start-Process $OneDriveExe -ArgumentList '/background'
        Write-Host "OneDrive restarted - waiting for sync confirmation ..." -ForegroundColor Green

        # Poll the newest save's OneDrive state: 2 = in sync, 3 = in sync (pinned), 7/8 = error/warning
        $synced = $false
        $newest = Get-ChildItem $SaveDir -Filter *.fm | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($newest) {
            $shell    = New-Object -ComObject Shell.Application
            $folder   = $shell.Namespace($newest.DirectoryName)
            $deadline = (Get-Date).AddMinutes($SyncTimeoutMins)
            $doneHits = 0
            Start-Sleep 15   # give OneDrive time to notice the changed file
            while ((Get-Date) -lt $deadline) {
                $state = $folder.ParseName($newest.Name).ExtendedProperty('System.StorageProviderState')
                if ($state -in 2, 3)  { $doneHits++ } else { $doneHits = 0 }
                if ($doneHits -ge 2)  { $synced = $true; break }   # two clean checks in a row
                if ($state -in 7, 8)  { Write-Host "`nOneDrive reports a sync problem with $($newest.Name)." -ForegroundColor Red; break }
                Write-Host "." -NoNewline
                Start-Sleep 5
            }
        }

        if ($synced) {
            Write-Host "`nOneDrive sync is live - safe to play on another PC." -ForegroundColor Green
            Start-Sleep 5
        } else {
            Write-Host "`nCouldn't confirm the upload finished. Check the OneDrive icon before playing elsewhere." -ForegroundColor Yellow
            $open = Read-Host "Press O then Enter to open your saves folder, or just Enter to close"
            if ($open -match '^[Oo]') { Invoke-Item $SaveDir }
        }
    } else {
        Start-Sleep 5
    }
}