#Requires -Version 5.1
<#
.SYNOPSIS
    Setup-Menue - Dell Command Update + Chocolatey + .NET 8
.USAGE
    iwr -useb "https://raw.githubusercontent.com/WolfgangHasler/Technik/main/Setup-Menu.ps1" | iex
#>

# ── Admin-Check ────────────────────────────────────────────────────────────────
$currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-NOT $isAdmin) {
    Write-Host "Starte als Administrator neu..." -ForegroundColor Yellow
    $scriptUrl = "https://raw.githubusercontent.com/WolfgangHasler/Technik/main/Setup-Menu.ps1"
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb '$scriptUrl' | iex`""
    exit
}

# ── Hilfsfunktionen ────────────────────────────────────────────────────────────
function Write-Header {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "WolfgangHasler | Setup-Menue"
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║        W O L F G A N G H A S L E R   S E T U P      ║" -ForegroundColor Cyan
    Write-Host "  ║     Dell Command Update  +  Chocolatey  +  .NET 8   ║" -ForegroundColor DarkCyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Msg, [string]$Color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "  [$ts] $Msg" -ForegroundColor $Color
}

function Pause-Continue {
    Write-Host ""
    Write-Host "  Druecke eine beliebige Taste um fortzufahren..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ── Installations-Funktionen ───────────────────────────────────────────────────
function Install-DotNet8 {
    Write-Header
    Write-Host "  [ .NET 8 RUNTIME INSTALLATION ]" -ForegroundColor Green
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    # Pruefen ob bereits installiert
    $installed = Get-ItemProperty "HKLM:\SOFTWARE\dotnet\Setup\InstalledVersions\x64\sharedhost" `
                     -ErrorAction SilentlyContinue |
                 Where-Object { $_.Version -match "^8\." }

    if ($installed) {
        Write-Status ".NET 8 ist bereits installiert: $($installed.Version)" "Yellow"
        Pause-Continue
        return
    }

    # Winget bevorzugen
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Status "Installiere via winget..." "Cyan"
        winget install Microsoft.DotNet.DesktopRuntime.8 `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements
    } else {
        Write-Status "Lade .NET 8 Installer herunter..." "Cyan"
        # Aktuelle Version von Microsoft API holen
        try {
            $releaseInfo = Invoke-RestMethod `
                "https://dotnetcli.blob.core.windows.net/dotnet/Runtime/8.0/latest.version" `
                -UseBasicParsing
            $version = $releaseInfo.Trim()
        } catch {
            $version = "8.0.14"
        }
        $url  = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$version/windowsdesktop-runtime-$version-win-x64.exe"
        $dest = "$env:TEMP\dotnet8-runtime.exe"

        Write-Status "URL: $url" "DarkGray"
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        Write-Status "Installiere (silent)..." "Cyan"
        Start-Process -FilePath $dest -ArgumentList "/quiet /norestart" -Wait
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Status ".NET 8 wurde erfolgreich installiert!" "Green"
    Pause-Continue
}

function Install-Chocolatey {
    Write-Header
    Write-Host "  [ CHOCOLATEY INSTALLATION ]" -ForegroundColor Magenta
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Status "Chocolatey ist bereits installiert: $(choco --version)" "Yellow"
        Pause-Continue
        return
    }

    Write-Status "Installiere Chocolatey..." "Cyan"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol =
        [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

    iex ((New-Object System.Net.WebClient).DownloadString(
        'https://community.chocolatey.org/install.ps1'))

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Status "Chocolatey $(choco --version) wurde erfolgreich installiert!" "Green"
    } else {
        Write-Status "Installation fehlgeschlagen - bitte manuell pruefen!" "Red"
    }
    Pause-Continue
}

function Install-DellCommandUpdate {
    Write-Header
    Write-Host "  [ DELL COMMAND UPDATE (2WT0J) INSTALLATION ]" -ForegroundColor Yellow
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    # .NET 8 zuerst pruefen (Voraussetzung)
    $dotnet8 = Get-Command dotnet -ErrorAction SilentlyContinue |
               ForEach-Object { & dotnet --list-runtimes 2>$null } |
               Where-Object { $_ -match "^Microsoft\.WindowsDesktop\.App 8\." }

    if (-not $dotnet8) {
        Write-Status ".NET 8 fehlt - wird zuerst installiert..." "Yellow"
        Install-DotNet8
        Write-Header
        Write-Host "  [ DELL COMMAND UPDATE (2WT0J) INSTALLATION ]" -ForegroundColor Yellow
        Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
    }

    # Alte Version deinstallieren
    Write-Status "Suche bestehende Dell Command Update Installation..." "Cyan"
    $existing = Get-WmiObject Win32_Product -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Dell Command*Update*" }

    if ($existing) {
        Write-Status "Deinstalliere: $($existing.Name) $($existing.Version)" "Yellow"
        $existing.Uninstall() | Out-Null
        Write-Status "Alte Version entfernt." "Green"
    } else {
        Write-Status "Keine bestehende Installation gefunden." "DarkGray"
    }

    # Download-URL dynamisch ueber Dell API holen
    Write-Status "Rufe Dell Download-URL ab..." "Cyan"
    $downloadUrl = $null
    try {
        $apiResponse = Invoke-RestMethod `
            "https://www.dell.com/support/driver/en-us/ips/api/driverlist/getdriver?driverid=2WT0J" `
            -UseBasicParsing -ErrorAction Stop
        # Ersten Download-Link extrahieren
        $downloadUrl = $apiResponse.DriverAttributes |
                       Where-Object { $_.Type -eq "LaptopDriver" } |
                       Select-Object -First 1 -ExpandProperty Path
        if (-not $downloadUrl) {
            $downloadUrl = $apiResponse | Select-Object -ExpandProperty DownloadUrl -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Status "Dell API nicht erreichbar - verwende bekannte URL." "DarkYellow"
    }

    # Fallback: bekannte URL
    if (-not $downloadUrl) {
        $downloadUrl = "https://dl.dell.com/FOLDER11644621M/1/Dell-Command-Update-Windows-Universal-Application_2WT0J_WIN64_5.6.0_A00.EXE"
    }

    $dest = "$env:TEMP\DellCommandUpdate.exe"
    Write-Status "Lade herunter von:" "Cyan"
    Write-Host "    $downloadUrl" -ForegroundColor DarkGray

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $dest -UseBasicParsing
    } catch {
        Write-Status "Download fehlgeschlagen: $_" "Red"
        Write-Status "Bitte manuell herunterladen:" "Yellow"
        Write-Host "    https://www.dell.com/support/home/de-at/drivers/driversdetails?driverid=2WT0J" -ForegroundColor Cyan
        Pause-Continue
        return
    }

    Write-Status "Installiere Dell Command Update (silent)..." "Cyan"
    Start-Process -FilePath $dest -ArgumentList "/s" -Wait
    Remove-Item $dest -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Status "Dell Command Update wurde erfolgreich installiert!" "Green"
    Write-Status "Treiber-ID: 2WT0J | https://www.dell.com/support/home/de-at/drivers/driversdetails?driverid=2WT0J" "DarkGray"
    Pause-Continue
}

function Install-All {
    Write-Header
    Write-Host "  [ ALLES INSTALLIEREN: .NET 8 + Chocolatey + Dell Command Update ]" -ForegroundColor Green
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Status "Starte vollstaendige Installation..." "Cyan"
    Start-Sleep -Seconds 1

    Install-DotNet8
    Install-Chocolatey
    # Dell Command Update braucht .NET 8 - bereits installiert
    Write-Header
    Write-Host "  [ DELL COMMAND UPDATE (2WT0J) INSTALLATION ]" -ForegroundColor Yellow
    Write-Host "  ──────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    $existing = Get-WmiObject Win32_Product -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like "*Dell Command*Update*" }
    if ($existing) {
        Write-Status "Deinstalliere alte Version..." "Yellow"
        $existing.Uninstall() | Out-Null
    }
    $downloadUrl = "https://dl.dell.com/FOLDER11644621M/1/Dell-Command-Update-Windows-Universal-Application_2WT0J_WIN64_5.6.0_A00.EXE"
    $dest = "$env:TEMP\DellCommandUpdate.exe"
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $dest -UseBasicParsing
        Start-Process -FilePath $dest -ArgumentList "/s" -Wait
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        Write-Status "Dell Command Update installiert!" "Green"
    } catch {
        Write-Status "Dell Command Update Download fehlgeschlagen: $_" "Red"
    }
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║          ALLE INSTALLATIONEN ABGESCHLOSSEN!          ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
    Pause-Continue
}

# ── HAUPTMENÜ MIT COUNTDOWN ────────────────────────────────────────────────────
$timeout   = 30
$startTime = Get-Date

:mainloop while ($true) {
    $elapsed   = (Get-Date) - $startTime
    $remaining = $timeout - [int]$elapsed.TotalSeconds

    if ($remaining -le 0) {
        Write-Header
        Write-Host "  Timeout erreicht - Skript wird beendet." -ForegroundColor Red
        Start-Sleep -Seconds 2
        break mainloop
    }

    Write-Header
    Write-Host "  Was moechtest du tun?" -ForegroundColor White
    Write-Host ""
    Write-Host "  ┌─────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  [1]  .NET 8 Runtime installieren                   │" -ForegroundColor Yellow
    Write-Host "  │  [2]  Chocolatey (Paketmanager) installieren        │" -ForegroundColor Magenta
    Write-Host "  │  [3]  Dell Command Update (2WT0J) installieren      │" -ForegroundColor Cyan
    Write-Host "  │  [4]  Alles installieren  (.NET 8 + Choco + Dell)   │" -ForegroundColor Green
    Write-Host "  │  [0]  Beenden                                        │" -ForegroundColor Red
    Write-Host "  └─────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""

    # Countdown-Balken
    $barWidth = 50
    $filled   = [int](($remaining / $timeout) * $barWidth)
    $empty    = $barWidth - $filled
    $bar      = "█" * $filled + "░" * $empty
    $color    = if ($remaining -gt 15) { "Green" } elseif ($remaining -gt 8) { "Yellow" } else { "Red" }
    Write-Host "  [$bar] $remaining s" -ForegroundColor $color
    Write-Host ""
    Write-Host "  Auswahl: " -NoNewline -ForegroundColor White

    # Tastatureingabe (non-blocking)
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        switch ($key.KeyChar.ToString()) {
            "1" { Install-DotNet8;            $startTime = Get-Date }
            "2" { Install-Chocolatey;         $startTime = Get-Date }
            "3" { Install-DellCommandUpdate;  $startTime = Get-Date }
            "4" { Install-All;                $startTime = Get-Date }
            "0" { break mainloop }
        }
    }

    Start-Sleep -Milliseconds 200
}

Write-Host ""
Write-Host "  Auf Wiedersehen!" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1
