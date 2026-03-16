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
1 - Apply registry tweaks (bypass Windows 11 restrictions)
2 - Set Windows Update target release version
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
    Write-Host "`n*** Installing Dell Update & .NET Framework... ***" -ForegroundColor Cyan
    
    # Installiert .NET Runtime 8 silently
    Write-Host "Installing .NET Runtime 8 via winget..."
    winget install -e --id Microsoft.DotNet.Runtime.8 --silent --accept-package-agreements --accept-source-agreements
    
    # Pfade definieren
    # ACHTUNG: Hier muss der direkte Download-Link der EXE rein, nicht die Support-Page!
    $downloadUrl = "https://dl.dell.com/FOLDER13922692M/1/Dell-Command-Update-Windows-Universal-Application_2WT0J_WIN64_5.6.0_A00.EXE?uid=f9e185ae-f9f9-4ad8-5f13-2dcba57c3402&fn=Dell-Command-Update-Windows-Universal-Application_2WT0J_WIN64_5.6.0_A00.EXE" 
    $installerPath = "$env:TEMP\DellCommandUpdate_5.6.0.exe"

    # Dell Command Update herunterladen
    Write-Host "Downloading Dell Command Update..."
    Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

    # Installation ausführen (Parameter /s für Silent-Install)
    Write-Host "Installing Dell Command Update..."
    Start-Process -FilePath $installerPath -ArgumentList "/s" -Wait -NoNewWindow

    # Temporäre Datei aufräumen
    Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue

    Write-Host "*** Installation completed ***" -ForegroundColor Green
    Write-Host "" -ForegroundColor Yellow
    Read-Host "Press Enter to return to main menu"
    Show-MainMenu
}


function Reset-WindowsUpdate {
    Write-Host "`n*** Executing Windows Update reset and network settings reset... ***" -ForegroundColor Cyan

    Write-Host "1. Stopping Windows Update services..."
    Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Stop-Service -Name appidsvc -Force -ErrorAction SilentlyContinue
    Stop-Service -Name cryptsvc -Force -ErrorAction SilentlyContinue

    Write-Host "2. Deleting QMGR files..."
    Remove-Item "$env:ALLUSERSPROFILE\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue

    Write-Host "3. Renaming folders: SoftwareDistribution and Catroot2..."
    Rename-Item "$env:systemroot\SoftwareDistribution" "SoftwareDistribution.bak" -ErrorAction SilentlyContinue
    Rename-Item "$env:systemroot\System32\Catroot2" "catroot2.bak" -ErrorAction SilentlyContinue

    Write-Host "4. Deleting WindowsUpdate.log file..."
    Remove-Item "$env:systemroot\WindowsUpdate.log" -ErrorAction SilentlyContinue

    Write-Host "5. Registering DLL files..."
    Set-Location $env:systemroot\System32

    $dlls = @(
        "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll",
        "jscript.dll", "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll",
        "actxprxy.dll", "softpub.dll", "wintrust.dll", "dssenh.dll", "rsaenh.dll", "gpkcsp.dll",
        "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "oleaut32.dll", "ole32.dll", "shell32.dll",
        "initpki.dll", "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll",
        "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll", "muweb.dll", "wuwebv.dll"
    )

    foreach ($dll in $dlls) {
        try {
            regsvr32.exe /s $dll
        } catch {
            Write-Host "Failed to register $dll" -ForegroundColor Yellow
        }
    }

    Write-Host "6. Executing network reset commands..."
    arp -d *
    nbtstat -R
    nbtstat -RR
    ipconfig /flushdns
    ipconfig /registerdns
    netsh winsock reset
    netsh int ip reset c:\resetlog.txt

    Write-Host "7. Restarting Windows Update services..."
    Start-Service -Name BITS -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Start-Service -Name appidsvc -ErrorAction SilentlyContinue
    Start-Service -Name cryptsvc -ErrorAction SilentlyContinue

    Write-Host "`n*** Windows Update reset and network settings reset completed. ***" -ForegroundColor Green
    Write-Host "It is recommended to restart your computer before continuing." -ForegroundColor Yellow
    Read-Host "Press Enter to return to main menu"
    Show-MainMenu
}

function Set-WUTargetRelease {
    Write-Host "`n*** Configure Windows Update Target Release Version ***" -ForegroundColor Cyan
    Write-Host "1 (or press Enter) - Set default target release version to 24H2"
    Write-Host "2 - Set a custom target release version"

    $choice = Read-Host "Select an option (1-2)"
    $WinUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

    if ($choice -eq "" -or $choice -eq "1") {
        $targetRelease = "24H2"
    } elseif ($choice -eq "2") {
        $targetRelease = Read-Host "Enter the Windows 11 target release version (e.g 23H2, 24H2)"
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        return
    }

    Write-Host "Setting Windows Update target release to $targetRelease..." -ForegroundColor Cyan
    if (!(Test-Path $WinUpdatePath)) {
        New-Item -Path $WinUpdatePath -Force | Out-Null
    }
    New-ItemProperty -Path $WinUpdatePath -Name "ProductVersion" -Value "Windows 11" -PropertyType String -Force
    New-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersion" -Value 1 -PropertyType DWord -Force
    New-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersionInfo" -Value $targetRelease -PropertyType String -Force
}

function Remove-WUTargetRelease {
    Write-Host "`n*** Removing Windows Update Target Release Version ***" -ForegroundColor Cyan
    $WinUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    
    if (Test-Path $WinUpdatePath) {
        Remove-ItemProperty -Path $WinUpdatePath -Name "ProductVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $WinUpdatePath -Name "TargetReleaseVersionInfo" -ErrorAction SilentlyContinue
        Write-Host "Target release version settings removed." -ForegroundColor Green
    } else {
        Write-Host "No target release version settings found." -ForegroundColor Yellow
    }
}

function Set-BypassRegistryTweaks {
    Write-Host "`n*** Applying registry tweaks to bypass Windows 11 hardware restrictions ***" -ForegroundColor Cyan
    $moSetupPath = "HKLM:\SYSTEM\Setup\MoSetup"
    $appCompatFlagsPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags"
    $hwReqChkPath = "$appCompatFlagsPath\HwReqChk"

    @($moSetupPath, $hwReqChkPath) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -Path $_ -Force | Out-Null
        }
    }

    New-ItemProperty -Path $moSetupPath -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWord -Force

    @(
        "$appCompatFlagsPath\CompatMarkers",
        "$appCompatFlagsPath\Shared",
        "$appCompatFlagsPath\TargetVersionUpgradeExperienceIndicators"
    ) | ForEach-Object {
        Remove-Item -Path $_ -Force -Recurse -ErrorAction SilentlyContinue
    }

    New-ItemProperty -Path $hwReqChkPath -Name "HwReqChkVars" -PropertyType MultiString -Value @(
        "SQ_SecureBootCapable=TRUE",
        "SQ_SecureBootEnabled=TRUE",
        "SQ_TpmVersion=2",
        "SQ_RamMB=8192"
    ) -Force

    $systemPolicyKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $systemPolicyKey)) {
        New-Item -Path $systemPolicyKey -Force | Out-Null
    }
    New-ItemProperty -Path $systemPolicyKey -Name "HideUnsupportedHardwareNotifications" -PropertyType DWord -Value 1 -Force | Out-Null

    $uhncKey = "HKCU:\Control Panel\UnsupportedHardwareNotificationCache"
    if (-not (Test-Path $uhncKey)) {
        New-Item -Path $uhncKey -Force | Out-Null
    }
    New-ItemProperty -Path $uhncKey -Name "SV2" -Value 0 -PropertyType DWord -Force | Out-Null

    try {
        Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -Force
        Write-Host "Telemetry disabled." -ForegroundColor Green
    } catch {
        Write-Host ("Failed to modify telemetry settings: $($_)") -ForegroundColor Red
    }

    $telemetryTasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
        "\Microsoft\Windows\Application Experience\StartupAppTask"
    )

    foreach ($task in $telemetryTasks) {
        schtasks /query /tn "$task" 2>$null
        if ($LASTEXITCODE -eq 0) {
            schtasks /change /disable /tn "$task" | Out-Null
            Write-Host "Disabled task: $task" -ForegroundColor Green
        }
    }
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
            Set-WUTargetRelease
            Set-BypassRegistryTweaks
            Wait-AfterInfo
        }
        "2" {
            Set-WUTargetRelease
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