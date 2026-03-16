# Win11-Req-Bypass

## Bypass Windows 11 Installation & Update Restrictions

**Win11-Req-Bypass** is a PowerShell script that allows you to install and update Windows 11 on unsupported hardware by bypassing system requirements. It modifies the registry to remove installation restrictions and ensures compatibility with Windows Update.

### Features
- Bypasses Windows Update compatibility checks to allow updates on unsupported devices.
- Removes "System Requirements Not Met" watermark.
- Enables Windows Update to fetch the latest Windows 11 version (24H2) or a user-specified version.
- Disables Windows telemetry to prevent settings from reverting in the future.
- Offers an interactive menu interface

### How to Use

#### Run Directly from the Web
To execute the script quickly, open PowerShell as **Administrator** and run:
```powershell
iwr -useb "https://raw.githubusercontent.com/Win11Modder/Win11-Req-Bypass/main/Win11_Bypass.ps1" | iex
```

#### Download and Run Manually
1. Download **Win11_Bypass.ps1** from the repository.
2. Open **PowerShell as Administrator**.
3. Navigate to the script directory:
   ```powershell
   cd "C:\path\to\script"
   ```
4. Run the script:
   ```powershell
   .\Win11_Bypass.ps1
   ```

If PowerShell script execution is restricted, you may need to run the following command first:
 ```powershell
  Set-ExecutionPolicy RemoteSigned
   ```

### Notes
- Use at your own risk. This script modifies system settings and registry entries.
- Run PowerShell as **Administrator** for full functionality.
- Restart your computer after execution to apply changes.


### ⚠️ CPU Requirements

Windows 11 24H2 **requires x86-64-v2 CPU features**, including:

* **SSE4.2**
* **POPCNT**

If your CPU doesn’t support these, the script will detect it and **exit automatically**. This is a hard Windows requirement — it cannot be bypassed.

### License
This script is provided as-is, without any warranties. Use it responsibly.
