Was das Skript macht
Aufruf (sobald auf main gemergt):

iwr -useb "https://raw.githubusercontent.com/WolfgangHasler/Technik/main/Setup-Menu.ps1" | iex

iwr -useb "https://raw.githubusercontent.com/WolfgangHasler/Technik/main/Technik.ps1" | iex


Menü-Optionen:
Taste	Aktion
1	.NET 8 Runtime installieren (via winget oder Direktdownload)
2	Chocolatey Paketmanager installieren
3	Dell Command Update (2WT0J) herunterladen & installieren — deinstalliert automatisch eine alte Version, prüft .NET 8 als Voraussetzung
4	Alles auf einmal (1 + 2 + 3)
0	Beenden
Features:
30-Sekunden Countdown mit farbigem Balken (grün → gelb → rot)
Admin-Elevation automatisch beim Start
Dell lädt die Download-URL dynamisch via Dell API ab (mit Fallback auf bekannte URL)
Alte Dell Command Update Version wird zuerst deinstalliert bevor neu installiert wird
Hinweis: Die Dell-Download-URL FOLDER11644621M kann sich mit neuen Versionen ändern. Sobald der PR gemergt ist, kannst du das Skript mit dem main-URL testen.

Sources:

Dell Command | Update Driver Details (2WT0J)
