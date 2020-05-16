<# Script basis here (first 4 functions + calling the CheckIfModuleInstalled and ConnectToGraph functions 
You can find the template and explanation for this here: https://github.com/daduckMSFT/intunePS/wiki/Script-Template #>

# Basic function that checks if the user is in the administrator group. Warns and stops if the user is not. Sets the global "isAdmin" variable to "true" if admin. 
function CheckIfAdmin {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "You are not running this as local administrator. Run it again in an elevated prompt." ; break }
    else {
        $global:isAdmin = "true" }
}

<# CheckModuleInstalled is a function that verifies if the  Graph Module is installed, and allows the user to install it #>
function CheckModuleInstalled {
    if (Get-Module -ListAvailable -Name Microsoft.Graph.Intune) {
        Write-Host "Intune PowerShell SDK Module found, proceeding with script...`n"
    }

    else {
        Write-Warning "Intune PowerShell SDK Module not installed."
        $InstallYesNo = Read-Host "Would you like to install it? Yes/No"

        if($InstallYesNo -like "Yes" -or $InstallYesNo -like "Y") {
            CheckIfAdmin
            if ($global:isAdmin -eq "true") {
                try {
                    Write-Host "Installing the Microsoft.Graph.Intune Module"
                    Write-Warning "This could take some time, possibly even a few minutes"
                    Install-Module Microsoft.Graph.Intune }
                catch {
                    Write-Warning "Installing the module failed, please try manually running`n    Install-Module -Name Microsoft.Graph.Intune`n`nin an elevated prompt" }
                }
            else {
                CheckIfAdmin }
        } else {
            Write-Warning "You must have the Intune PowerShell SDK Module installed to continue."; break }
    }
}

<# ConnectToGraph is a function that connects to Graph, and also defines two variables with the tenantId and UPN of the user you connect with #>
function ConnectToGraph {
    try {
        Write-Host "Connecting to Microsoft Graph... please login using the appropriate account."  -ForegroundColor White -BackgroundColor Black
        Write-Host "If you have previously connected in this window, it will use those cached credentials.`n`n" -ForegroundColor Red -BackgroundColor Black;
        Connect-MSGraph -Quiet } 
    catch {
        Write-Warning "Connecting failed, please try again."; break; }
        
        $global:connectedUser = (Connect-MSGraph).UPN
        $global:connectedTenantId = (Connect-MSGraph).TenantId

        Clear-Host
        Write-Host "Hello " -NoNewline; Write-Host "$global:connectedUser" -ForegroundColor White -BackgroundColor DarkMagenta -NoNewline; Write-Host "!`n"
        Write-Host "You have connected to the directory with the ID of:" $global:connectedTenantId
        SpacingBars
}

<# SpacingBars can be used throughout to add some nice formatting to your output#>
function SpacingBars {
    Write-Host "`n========================================================================================"
    Write-Host "========================================================================================`n"
}

Clear-Host

<# Verify Intune cmdlets are installed #>
    CheckModuleInstalled

<# If successful, it will then connect to the Microsoft Graph service #>
    ConnectToGraph

<# Gather the total count of devices for visibility and write them to the console #>
    $totalDeviceCount = (Get-IntuneManagedDevice).count
    $totalIOSDeviceCount = (Get-IntuneManagedDevice | Where-Object {$_.operatingSystem -eq "iOS"}).count
    $totalAndroidDeviceCount = (Get-IntuneManagedDevice | Where-Object {$_.operatingSystem -eq "Android"}).count
    $totalWindowsDeviceCount = (Get-IntuneManagedDevice | Where-Object {$_.operatingSystem -eq "Windows"}).count

    Write-Host "Your tenant currently has " -NoNewline; Write-Host "$totalDeviceCount total" -NoNewLine -ForegroundColor Yellow -BackgroundColor Black; Write-Host " devices enrolled."
    Write-Host "                          " -NoNewline; Write-Host "$totalIOSDeviceCount iOS" -ForegroundColor White -BackgroundColor Black;
    Write-Host "                          " -NoNewline; Write-Host "$totalAndroidDeviceCount Android" -ForegroundColor Magenta -BackgroundColor Black;
    Write-Host "                          " -NoNewline; Write-Host "$totalWindowsDeviceCount Windows" -ForegroundColor Cyan -BackgroundColor Black;
    SpacingBars

<# Prompts you to select a platform to synchronize - Windows, Android, and iOS are the (3) platforms most commonly used.
    The "do until" loop requires Android, iOS, or Windows (case insensitive) - if you need to accept other platforms, simply edit this!
    It also Builds a variable to store all of the devices that we wish to sync 
    It also creates another variable for the count of the devices that are targeted to sync #>

    do {
        $platform = Read-Host "What platform do you want to synchronize the devices for? iOS, Android or Windows?"
    }
    until ($platform -like "Windows" -or $platform -like "Android" -or $platform -like "iOS")
    
    $devicesToSync = Get-IntuneManagedDevice | Where-Object {$_.operatingSystem -eq $platform}
    $targetSyncCount = ($devicesToSync).count

        <# Error checking to see if the platform has any devices to sync - if it isn't 0, then it skips this. If it is 0, this tells them why and exits #>
        if ($targetSyncCount -eq "0") {
            Clear-Host
            Write-Warning "`nYou have selected $platform, but found no enrolled devices running $platform.`n`nThis means there are no devices to sync.`n`nExiting script..."
            break 
        }

    Write-Host "`nYou have chosen to sync " -NoNewline; Write-Host "$targetSyncCount $platform" -NoNewLine -ForegroundColor Red -BackgroundColor Black; Write-Host " devices.`n"

<# Clear the screen, and prompt the user to confirm the sync of the devices #>
    Clear-Host

    Write-Host "Please confirm that you want to synchronize $targetSyncCount $platform devices (Y/N): " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    $syncConfirm = Read-Host


<# If confirmed to sync, it issues the sync - if not, the script ends #>
    if($syncConfirm -like "Yes" -or $syncConfirm -like "Y") {
        SpacingBars
        Write-Host "Synchronizing $targetSyncCount devices... this might take a while. " 
        $devicesToSync | Invoke-IntuneManagedDeviceSyncDevice
        Write-Host (Connect-MSGraph).UPN -ForegroundColor Cyan -BackgroundColor DarkMagenta -NoNewline;Write-Host " issued a synchronization attempt on $targetSyncCount $platform devices on " -NoNewline; Write-Host (Get-Date) "`n" -ForegroundColor Green
        } 
    else {
        SpacingBars
        Write-Warning "Aborting.."; Exit
        }
