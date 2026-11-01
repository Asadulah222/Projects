from pathlib import Path
import zipfile, textwrap

project = Path("/mnt/data/AAQI-Basic-IT-Helpdesk")
project.mkdir(parents=True, exist_ok=True)

bat = r'''@echo off
setlocal EnableExtensions EnableDelayedExpansion
title AAQI Basic IT Helpdesk Toolkit
color 0A

set "REPORTDIR=%~dp0reports"
if not exist "%REPORTDIR%" mkdir "%REPORTDIR%"
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%I"
set "REPORT=%REPORTDIR%\Helpdesk_Report_%STAMP%.txt"
set "HTML=%REPORTDIR%\Helpdesk_Report_%STAMP%.html"

(
echo BASIC IT HELPDESK REPORT
echo Developed by Muhammad Asadullah - Aaqi Soft Solutions
echo Date: %DATE% %TIME%
echo Computer: %COMPUTERNAME%
echo ==================================================
) > "%REPORT%"

:MENU
color 0A
cls
echo.
echo  BASIC IT HELPDESK TOOLKIT
echo  ------------------------
echo  1. IP Configuration
echo  2. Internet Connection Test
echo  3. Default Gateway Test
echo  4. DNS Lookup Test
echo  5. Flush DNS Cache
echo  6. Renew IP Address
echo  7. Network Adapter Status
echo  8. System Information
echo  9. Disk Space Check
echo 10. Windows System File Scan (SFC)
echo 11. Exit and Generate Reports
echo.
set "CHOICE="
set /p "CHOICE=Enter option number: "

if "%CHOICE%"=="1" goto IP
if "%CHOICE%"=="2" goto INTERNET
if "%CHOICE%"=="3" goto GATEWAY
if "%CHOICE%"=="4" goto DNS
if "%CHOICE%"=="5" goto FLUSHDNS
if "%CHOICE%"=="6" goto RENEW
if "%CHOICE%"=="7" goto ADAPTER
if "%CHOICE%"=="8" goto SYSINFO
if "%CHOICE%"=="9" goto DISK
if "%CHOICE%"=="10" goto SFC
if "%CHOICE%"=="11" goto FINISH
echo Invalid option.
timeout /t 2 >nul
goto MENU

:IP
call :NORMAL "IP CONFIGURATION"
ipconfig /all
ipconfig /all >> "%REPORT%" 2>&1
pause
goto MENU

:INTERNET
call :SCAN "INTERNET CONNECTION TEST"
ping -n 4 1.1.1.1
ping -n 4 1.1.1.1 >> "%REPORT%" 2>&1
if errorlevel 1 (call :WARN "Internet ping test failed.") else call :OK "Internet ping test succeeded."
pause
goto MENU

:GATEWAY
call :SCAN "DEFAULT GATEWAY TEST"
set "GW="
for /f "tokens=3" %%G in ('route print -4 ^| findstr /R /C:"^ *0\.0\.0\.0 *0\.0\.0\.0"') do if not defined GW set "GW=%%G"
if not defined GW (
 call :WARN "No IPv4 default gateway detected."
) else (
 echo Detected gateway: !GW!
 ping -n 4 !GW!
 echo Gateway: !GW!>>"%REPORT%"
 ping -n 4 !GW!>>"%REPORT%" 2>&1
 if errorlevel 1 (call :WARN "Gateway did not respond. Some routers block ping.") else call :OK "Gateway responded."
)
pause
goto MENU

:DNS
call :SCAN "DNS LOOKUP TEST"
nslookup www.microsoft.com
nslookup www.microsoft.com >> "%REPORT%" 2>&1
if errorlevel 1 (call :WARN "DNS lookup failed.") else call :OK "DNS lookup completed. Review the result above."
pause
goto MENU

:FLUSHDNS
call :SCAN "FLUSH DNS CACHE"
call :CONFIRM "Flush the Windows DNS cache?"
if errorlevel 1 goto MENU
ipconfig /flushdns
ipconfig /flushdns >> "%REPORT%" 2>&1
if errorlevel 1 (call :WARN "DNS cache flush failed.") else call :OK "DNS cache flush completed."
pause
goto MENU

:RENEW
call :SCAN "RENEW IP ADDRESS"
echo WARNING: Network may disconnect briefly. DHCP connection recommended.
call :CONFIRM "Release and renew the IP address?"
if errorlevel 1 goto MENU
ipconfig /release
ipconfig /release >> "%REPORT%" 2>&1
ipconfig /renew
ipconfig /renew >> "%REPORT%" 2>&1
if errorlevel 1 (call :WARN "IP renewal reported an error. Check DHCP and adapter status.") else call :OK "IP renewal commands completed."
pause
goto MENU

:ADAPTER
call :NORMAL "NETWORK ADAPTER STATUS"
netsh interface show interface
netsh interface show interface >> "%REPORT%" 2>&1
pause
goto MENU

:SYSINFO
call :NORMAL "SYSTEM INFORMATION"
systeminfo
systeminfo >> "%REPORT%" 2>&1
pause
goto MENU

:DISK
call :SCAN "DISK SPACE CHECK"
powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,@{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}},@{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,2)}} | Format-Table -AutoSize"
powershell -NoProfile -Command "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,@{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}},@{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,2)}} | Format-Table -AutoSize" >> "%REPORT%" 2>&1
pause
goto MENU

:SFC
call :SCAN "WINDOWS SYSTEM FILE SCAN"
call :CONFIRM "Run sfc /scannow? This may take several minutes."
if errorlevel 1 goto MENU
net session >nul 2>&1
if errorlevel 1 (
 call :WARN "Administrator rights required. Reopen this BAT file as administrator."
 pause
 goto MENU
)
sfc /scannow
sfc /scannow >> "%REPORT%" 2>&1
if errorlevel 1 (call :WARN "SFC reported an error. Review the final output.") else call :OK "SFC scan finished. Review its final message."
pause
goto MENU

:NORMAL
color 0A
echo.
echo ==================================================
echo %~1
echo ==================================================
echo [%DATE% %TIME%] %~1>>"%REPORT%"
exit /b

:SCAN
color 0C
echo.
echo ==================================================
echo SCANNING: %~1
echo ==================================================
echo [%DATE% %TIME%] SCANNING: %~1>>"%REPORT%"
exit /b

:CONFIRM
color 0C
echo.
echo %~1
set "ANSWER="
set /p "ANSWER=Type YES to continue: "
if /I not "!ANSWER!"=="YES" (
 echo Cancelled. No repair was run.
 echo CANCELLED: %~1>>"%REPORT%"
 exit /b 1
)
echo CONFIRMED: %~1>>"%REPORT%"
exit /b 0

:OK
color 0A
echo [SUCCESS] %~1
echo [SUCCESS] %~1>>"%REPORT%"
exit /b

:WARN
color 0C
echo [WARNING] %~1
echo [WARNING] %~1>>"%REPORT%"
exit /b

:FINISH
color 0A
echo.
echo Creating HTML report...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$raw=Get-Content -LiteralPath '%REPORT%' -Raw; $safe=[System.Net.WebUtility]::HtmlEncode($raw); $page='<!doctype html><html><head><meta charset=''utf-8''><title>Helpdesk Report</title><style>body{font-family:Arial;background:#f2f5f8;padding:30px;color:#172033}.wrap{max-width:900px;margin:auto;background:white;padding:25px;border-radius:10px}h1{color:#087e8b}pre{white-space:pre-wrap;font:14px/1.5 Consolas;background:#f7f9fc;padding:16px}</style></head><body><div class=''wrap''><h1>Basic IT Helpdesk Report</h1><p>Developed by Muhammad Asadullah - Aaqi Soft Solutions</p><pre>'+$safe+'</pre></div></body></html>'; Set-Content -LiteralPath '%HTML%' -Value $page -Encoding UTF8"
echo TXT report: %REPORT%
if exist "%HTML%" (echo HTML report: %HTML%) else echo HTML report could not be created.
echo.
echo Developed by Muhammad Asadullah - Aaqi Soft Solutions
pause
exit /b
'''
(project / "AAQI_Basic_IT_Helpdesk.bat").write_text(bat, encoding="utf-8")

readme = """# AAQI Basic IT Helpdesk Toolkit

**Author:** Muhammad Asadullah  
**Organization/Project credit:** Aaqi Soft Solutions

A lightweight Windows command-line helpdesk utility built with a single Batch (`.bat`) file. It provides common network, system, and storage checks, plus selected repair actions with explicit confirmation.

## Features

1. IP Configuration
2. Internet Connection Test
3. Default Gateway Test
4. DNS Lookup Test
5. Flush DNS Cache
6. Renew IP Address
7. Network Adapter Status
8. System Information
9. Disk Space Check
10. Windows System File Scan (SFC)

The toolkit uses **green** console text for the main menu and normal output, and **red** for scanning steps, warnings, and repair confirmations. When you exit, it creates TXT and HTML reports in a `reports` folder next to the BAT file.

## Requirements

- Windows 10 or Windows 11
- Command Prompt
- Windows PowerShell (included with Windows)
- Administrator rights for System File Checker; some network repair commands may also require elevation.

## Run

1. Download or clone this repository.
2. Double-click `AAQI_Basic_IT_Helpdesk.bat`.
3. Select an option by entering its number.
4. For repair actions, type `YES` only if you want to proceed.
5. Select option `11` to exit and generate the reports.

To run the SFC scan, right-click the BAT file and select **Run as administrator**.

## Safety notes

- Read each confirmation prompt before typing `YES`.
- Renewing an IP address can temporarily disconnect the computer from the network.
- A failed ping does not always mean the internet is down; some networks block ICMP traffic.
- SFC can take several minutes. Review its final message to understand the result.
- This tool is provided as-is. Review the commands before running it, especially on managed or business computers.

## Reports

Generated reports are saved under `reports/` beside the BAT file. Reports may contain device and network configuration details. Do not publish reports publicly without reviewing and removing private information.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
"""
(project / "README.md").write_text(readme, encoding="utf-8")

license_text = """MIT License

Copyright (c) 2026 Muhammad Asadullah

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"""
(project / "LICENSE").write_text(license_text, encoding="utf-8")

gitignore = """# Generated diagnostic reports may contain private system/network details
reports/
logs/
*.log
Thumbs.db
.DS_Store
"""
(project / ".gitignore").write_text(gitignore, encoding="utf-8")

zip_path = Path("/mnt/data/AAQI-Basic-IT-Helpdesk-GitHub-Project.zip")
with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
    for f in project.rglob("*"):
        if f.is_file():
            zf.write(f, arcname=f"{project.name}/{f.relative_to(project)}")

print("Created project files:")
for f in sorted(project.iterdir()):
    print(f"- {f.name} ({f.stat().st_size:,} bytes)")
print(f"\nZIP package: {zip_path} ({zip_path.stat().st_size:,} bytes)")
