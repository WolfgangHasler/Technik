# Technik - Windows 11 Bypass & Setup Tool

PowerShell-Script zur Einrichtung von Windows-Clients auf nicht offiziell unterstützter Hardware.

## Aufruf

```powershell
iwr -useb "https://raw.githubusercontent.com/WolfgangHasler/Technik/main/Technik.ps1" | iex
```

## Menü-Optionen

| Taste | Aktion |
|-------|--------|
| 0 | Dell Command Update & .NET 8 Runtime installieren |
| 1 | Computer umbenennen |
| 2 | Microsoft 365 Business (64-bit, de-de) installieren |
| 3 | Beenden |

## Features

- Automatische Admin-Elevation (auch bei `iwr | iex`)
- SSE4.2 / x86-64-v2 Check vor Start (Pflicht ab Windows 11 24H2)
- Dell Command Update: Download & Silent-Install
- .NET 8 Runtime via winget
- Office-Installation via Chocolatey (wird bei Bedarf mitinstalliert)
- NetBIOS-konforme PC-Umbenennung mit Validierung
