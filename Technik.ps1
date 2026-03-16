<#
.SYNOPSIS
Bypasses Windows 11 installation and update restrictions on unsupported hardware.

.DESCRIPTION
This PowerShell script modifies the Windows Registry to allow installation and updates of Windows 11 on systems that do not meet Microsoft's official hardware requirements.
- Bypasses hardware compatibility checks used by Windows Update
- Optionally resets Windows Update and network settings
- Disables Windows telemetry to reduce tracking and avoid enforcement of restrictions in the future

.EXAMPLE
Run the script:
    .\Win11_Bypass.ps1

OR execute it directly from the web:
    iwr -useb "https://raw.githubusercontent.com/Win11Modder/Win11-Req-Bypass/main/Win11_Bypass.ps1" | iex

.NOTES
- This script enables the installation and updating of Windows 11 on devices that are not officially supported by Microsoft.
- Use at your own risk. The author is not responsible for any issues that may result from running this script.
- Must be run with administrator privileges.
#>

function Show-MainMenu {
    Clear-Host
    $menu = @'
 __   __  ___   __    _____  ___        ____     ____        _______  ___  ___  _______     __        ________  ________  
|"  |/  \|  "| |" \  ("   \|"  \      /  " \   /  " \      |   _  "\|"  \/"  ||   __ "\   /""\      /"       )/"       ) 
|'  /    \:  | ||  | |.\\   \    |    /__|| |  /__|| |      (. |_)  :)\   \  / (. |__) :) /    \    (:   \___/(:   \___/  
|: /'        | |:  | |: \\   \\  |       |: |     |: |      |:     \/  \\  \/  |:  ____/ /' /\  \    \___  \   \___  \    
 \//  /'    | |.  | |.  \    \\ |      _\  |    _\  |      (|  _  \\  /   /   (|  /    //  __'  \    __/  \\   __/  \\   
 /   /  \\   | /\  |\|    \    \ |     /" \_|\  /" \_|\     |: |_)  :)/   /   /|__/ \  /   /  \\  \  /" \   :) /" \   :)  
|___/    \___|(__\_|_)\___|\____\)    (_______)(_______)    (_______/|___/   (_______)(___/    \___)(_______/ (_______/   
----------------------------------------------------------------------------------------
                    Windows 11 Bypass & Update Tool
----------------------------------------------------------------------------------------
0 - Install Dell Update & Netframwork 
1 - Rename Computer
2 - Install Office 64-bit de-de
3 - Remove Windows Update target release version
4 - Exit
'@
    Write-Host $menu -ForegroundColor Cyan
}

# Ensure script is running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "The script is not running as an administrator. Attempting to elevate privileges..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Check if CPU supports SSE4.2 (required for Windows 11 24H2 and x86-64-v2 baseline)
Add-Type -MemberDefinition @'
    [DllImport("kernel32.dll")]
    public static extern bool IsProcessorFeaturePresent(uint feature);
'@ -Name "Kernel32" -Namespace "Win32" -PassThru | Out-Null

if (-not [Win32.Kernel32]::IsProcessorFeaturePresent(38)) {
    Write-Host "`n============================================================" -ForegroundColor Red
    Write-Host " FATAL: This CPU does not support required SSE4.2 and POPCNT" -ForegroundColor Red
    Write-Host " Windows 11 24H2 requires x86-64-v2 instructions (non-optional)" -ForegroundColor Red
    Write-Host " This is a hard requirement – the OS will fail to boot!" -ForegroundColor Red
    Write-Host " There is NO workaround. Exiting the script." -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    exit 1
}

function Install-DellUpdate {
    Write-Host "`n*** Installing Dell Command Update & .NET Framework... ***" -ForegroundColor Cyan
    
    # .NET Runtime 8 silent installieren
    Write-Host "Installing .NET Runtime 8 via winget..."
    winget install -e --id Microsoft.DotNet.Runtime.8 --silent --accept-package-agreements --accept-source-agreements
    
    # Download
    $downloadUrl = "https://dl.dell.com/FOLDER13922692M/1/Dell-Command-Update-Windows-Universal-Application_2WT0J_WIN64_5.6.0_A00.EXE"
    $installerPath = "$env:TEMP\DellCommandUpdate_5.6.0.exe"
    
    Write-Host "Downloading Dell Command Update..."
    curl.exe -L --max-redirs 10 `
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36" `
        -o $installerPath $downloadUrl 2>$null
    
    $size = (Get-Item $installerPath -ErrorAction SilentlyContinue)?.Length
    if (-not $size -or $size -lt 1MB) {
        Write-Host "Download fehlgeschlagen (Datei fehlt oder zu klein)!" -ForegroundColor Red
        Read-Host "Press Enter to return to main menu"
        Show-MainMenu
        return
    }
    Write-Host "Downloaded: $([math]::Round($size/1MB,1)) MB" -ForegroundColor Green
    
    # Installation
    Write-Host "Installing Dell Command Update..."
    Start-Process -FilePath $installerPath -ArgumentList "/s" -Wait -NoNewWindow
    
    # Cleanup
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue
    
    Write-Host "*** Installation completed ***" -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to return to main menu"
    Show-MainMenu
}


function Rename-PCName {
    Write-Host "`n*** Rename Local Computer ***" -ForegroundColor Cyan
    
    # Aktuellen Hostnamen zur Orientierung anzeigen
    Write-Host "Current Hostname: $env:COMPUTERNAME" -ForegroundColor Gray
    
    # Schöne Frage-Funktion für den neuen Namen
    $newName = Read-Host "Bitte gib den neuen PC-Namen ein (Enter zum Abbrechen)"

    # Validierung der Eingabe
    if ([string]::IsNullOrWhiteSpace($newName)) {
        Write-Host "Abbruch: Es wurde kein neuer Name eingegeben." -ForegroundColor Yellow
    }
    elseif ($newName.Length -gt 15) {
        # IT-Standard: NetBIOS Namen dürfen max 15 Zeichen haben
        Write-Host "Fehler: Der Name darf für NetBIOS-Kompatibilität maximal 15 Zeichen lang sein." -ForegroundColor Red
    }
    elseif ($newName -eq $env:COMPUTERNAME) {
        Write-Host "Hinweis: Der PC heißt bereits '$newName'." -ForegroundColor Yellow
    }
    else {
        # Eigentliche Umbenennung
        try {
            Write-Host "Benenne Client um in '$newName'..." -ForegroundColor Cyan
            
            # Führt die Umbenennung durch (benötigt administrative Rechte)
            Rename-Computer -NewName $newName -ErrorAction Stop
            
            Write-Host "Erfolgreich! Der neue Name greift nach dem nächsten Neustart." -ForegroundColor Green
            
            # Optionaler direkter Reboot
            $restart = Read-Host "Möchtest du den Client jetzt neu starten? (J/N)"
            if ($restart -match '^[JjYy]') {
                Write-Host "Initiating Reboot..." -ForegroundColor Cyan
                Restart-Computer -Force
            }
        }
        catch {
            Write-Host "Fehler beim Umbenennen (als Admin gestartet?): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`n***" -ForegroundColor Green
    Read-Host "Press Enter to return to main menu"
    Show-MainMenu
}

function Install-Office-64bit-de-de {
    Write-Host "`n*** Installing Microsoft 365 Business (64-bit, de-de)... ***" -ForegroundColor Cyan

    # Chocolatey prüfen / installieren
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey nicht gefunden – wird installiert..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey gefunden: $(choco --version)" -ForegroundColor Green
    }

    # Office installieren (ohne OneDrive)
    Write-Host "Installing Microsoft 365 Business Retail 64-bit de-de..."
    choco install microsoft-office-deployment -y `
        --params="'/Product:O365BusinessRetail /Language:de-de /64bit /Exclude:OneDrive'"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "*** Installation completed ***" -ForegroundColor Green
    } else {
        Write-Host "*** Installation fehlgeschlagen (Exit Code: $LASTEXITCODE) ***" -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "Press Enter to return to main menu"
    Show-MainMenu
}





function Wait-AfterInfo {
    param ($seconds = 3)
    Write-Host "`n[Pause for $seconds seconds...]" -ForegroundColor DarkGray
    Start-Sleep -Seconds $seconds
}


# Main Menu Loop
while ($true) {
    Show-MainMenu
    $choice = Read-Host "Select an option (0-4)"

    switch ($choice) {
        "0" {
            Install-DellUpdate
            Wait-AfterInfo

        }
        "1" {
            Rename-PCNames
            Wait-AfterInfo
        }
        "2" {
            Install-Office-64bit-de-de
            Wait-AfterInfo
        }
        "3" {
            Remove-WUTargetRelease
            Wait-AfterInfo
        
        }
        "4" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit
        }
        default {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    }
}