# Requires administrative privileges to run

# -- Configuration --
$targetPackageFragment = "AdvancedMicroDevicesInc-RSXCM"
$restorePointName = "AMD_CM_Reset_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# 1. Check for administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$currentUser
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red

    exit 1
}

Write-Host "`n=== Remove AMD Adrenaline Context Menu Entry ===`n" -ForegroundColor Cyan

# Create a system restore point
$createRestore = Read-Host "Do you want to create a system restore point before proceeding? (1 = Yes, 2 = No)"
if ($createRestore -eq "1") {
    Write-Host "`nAttempting to create system restore point '$restorePointName'..." -ForegroundColor Yellow
    try {
        Checkpoint-Computer -Description $restorePointName -RestorePointType "MODIFY_SETTINGS"
        Write-Host "System restore point created successfully." -ForegroundColor Green
    } catch {
        Write-Host "Error creating the restore point: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Proceeding with the reset anyway..." -ForegroundColor DarkYellow
    }
} elseif ($createRestore -eq "2") {
    Write-Host "Skipped system restore point creation." -ForegroundColor DarkYellow
} else {
    Write-Host "Invalid choice, proceeding without a restore point." -ForegroundColor DarkYellow
}

# Check if RSXCM package exists
Write-Host "`nSearching for package: '$targetPackageFragment'..." -ForegroundColor Cyan
$package = Get-AppxPackage | Where-Object {$_.Name -match $targetPackageFragment}

if (-not $package) {
    Write-Host "`nError: No package matching '$targetPackageFragment' was found." -ForegroundColor Red
    Write-Host "The AMD Context Menu component may not be installed or the name has changed." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Package found: $($package.Name) - Version: $($package.Version)" -ForegroundColor Green
}

# Remove package
Write-Host "`n--- Removing package (This may take a moment) ---" -ForegroundColor Yellow
try {
    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction Stop
    Start-Sleep -Seconds 2

    # Verify removal
    $checkRemoval = Get-AppxPackage | Where-Object {$_.Name -match $targetPackageFragment}
    if (-not $checkRemoval) {
        Write-Host "Package removed successfully." -ForegroundColor Green
    } else {
        Write-Host "Verification failed: Package is still present after removal attempt." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Critical Error during package removal: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Wait before re-registering
Write-Host "'re-registering' the package restores system functions like 'Open in Terminal' and other context menu items." -ForegroundColor DarkCyan

Start-Sleep -Seconds 4

# Re register package
Write-Host "`n--- Re-registering package ---" -ForegroundColor Yellow
try {
    # Re-register using the manifest file from the original install location
    Add-AppxPackage -Register "$($package.InstallLocation)\AppxManifest.xml" -DisableDevelopmentMode -ErrorAction Stop
    Start-Sleep -Seconds 2

    # Verify re-addition
    $checkAdd = Get-AppxPackage | Where-Object {$_.Name -match $targetPackageFragment}
    if ($checkAdd) {
        Write-Host "Package re-registered successfully." -ForegroundColor Green
    } else {
        Write-Host "Verification failed: Package is missing after re-registration attempt." -ForegroundColor Red
    }
} catch {
    Write-Host "Critical Error during package registration: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "Operation completed. The AMD Context Menu should now be reset." -ForegroundColor Cyan
Write-Host "If the changes don't appear immediately, please restart Windows Explorer or log out and log back in." -ForegroundColor DarkYellow
        Write-Host " -Option 1: Open Task Manager (CTRL + SHIFT + ESC) > Run new task > type 'explorer.exe' > press Enter."
        Write-Host " -Option 2: Press Win + R > type 'explorer.exe' > press Enter."
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Press any key to exit..." -ForegroundColor DarkCyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
