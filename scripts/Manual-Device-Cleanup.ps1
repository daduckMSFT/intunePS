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
    $deviceOverview = Get-IntuneManagedDeviceOverview
    $totalDeviceCount = $deviceOverview.enrolledDeviceCount
    $totalIOSDeviceCount = $deviceOverview.deviceOperatingSystemSummary.iosCount
    $totalAndroidDeviceCount = $deviceOverview.deviceOperatingSystemSummary.androidCount
    $totalWindowsDeviceCount = $deviceOverview.deviceOperatingSystemSummary.windowsCount

    Write-Host "Your tenant currently has " -NoNewline; Write-Host "$totalDeviceCount total" -NoNewLine -ForegroundColor Yellow -BackgroundColor Black; Write-Host " devices enrolled."
    Write-Host "                          " -NoNewline; Write-Host "$totalIOSDeviceCount iOS" -ForegroundColor White -BackgroundColor Black;
    Write-Host "                          " -NoNewline; Write-Host "$totalAndroidDeviceCount Android" -ForegroundColor Magenta -BackgroundColor Black;
    Write-Host "                          " -NoNewline; Write-Host "$totalWindowsDeviceCount Windows" -ForegroundColor Cyan -BackgroundColor Black;
    SpacingBars
    Write-Host "Note - these numbers are not updated immediately, and are periodically updated." 

<# This gathers the date - aka, if you want to chceck for devices that haven't checked in forr 60 days,  you would enter in 60 
the $dateRange variable simply gets the current date, and subtracts the value entered here (eg; 60) from it #>
    $dateInput = Read-Host "Delete devices that haven't checked in in how many days?"
    $dateRange = (Get-Date).AddDays(-$dateInput)
        if ((Get-IntuneManagedDevice | Where-Object {$_.lastSyncDateTime -lt $dateRange}).count -eq "0") {
            Write-Warning "`nThere are no enrolled devices in your tenant that have checked in more than $dateInput days ago." 
            exit;
        }

<# Prompts you to select a platform to delete - Windows, Android, and iOS are the (3) platforms most commonly used.
    The "do until" loop requires Android, iOS, or Windows (case insensitive) - if you need to accept more, simply edit this!
    It also Builds a variable to gather all of the devices that we wish to delete 
    It also creates another variable for the count of the devices that are targeted to delete #>

    do {
        $platform = Read-Host "What platform do you want to delete? iOS, Android or Windows?"
    }
    until ($platform -like "Windows" -or $platform -like "Android" -or $platform -like "iOS")
    
    $devicesToDelete = Get-IntuneManagedDevice | Where-Object {$_.operatingSystem -eq $platform -and $_.lastSyncDateTime -lt $dateRange}
    $targetDeleteCount = ($devicesToDelete).count

        <# Error checking to see if the platform has any devices to delete - if it isn't 0, then it skips this. If it is 0, this tells them why and exits #>
        if ($targetDeleteCount -eq "0") {
            Clear-Host
            Write-Warning "`nYou have selected $platform, We found no enrolled devices found that have checked in before `n`n$dateRange`n`nThis means there are no devices to delete.`n`nExiting script..."
            break 
        }

    Write-Host "`nYou have chosen to delete " -NoNewline; Write-Host "$targetDeleteCount $platform" -NoNewLine -ForegroundColor Red -BackgroundColor Black; Write-Host " devices.`n"

<# What do you want the file to be named? It will be exported to your desktop with what is entered here as the name #>
    $fileName = Read-Host "What do you want to name the exported CSV? Whatever you enter here will be appended with .csv"

<# Gathers all Intune enrolled devices meeting the platform you have specified, and that have synchronized MORE than the number of days they entered in
    
It then exports this list into a CSV with the name you chose #>
    $devicesToDelete | Select-Object deviceName,lastSyncDateTime,serialNumber,userPrincipalName | Export-CSV -Path "$env:HOMEPATH\Desktop\$fileName.csv"

<# Clear the screen, and prompt the user to review the file on the desktop that was just exported to confirm the devices to delete #>
    Clear-Host
    SpacingBars
    Write-Host "Review the CSV on your desktop named " -NoNewline; Write-Host "$fileName.csv" -ForegroundColor Cyan -BackgroundColor Black -NoNewline; Write-Host " to review the "
    Write-Host "$targetDeleteCount $platform" -NoNewLine -ForegroundColor Yellow -BackgroundColor Black; Write-Host " devices that you have elected to delete."
    SpacingBars

    Write-Host "These devices have not checked-in since before"
    Write-Host "        $dateRange" -ForegroundColor White
    SpacingBars

    Write-Host "Please confirm if you want to delete (Y/N): " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    $deletionConfirm = Read-Host


<# If this looks good, and the CSV is OK, run the below to delete the devices #>
    if($deletionConfirm -like "Yes" -or $deletionConfirm -like "Y") {
        SpacingBars
        Write-Host "Deleting devices..." 
        $devicesToDelete | Remove-IntuneManagedDevice
        Write-Host (Connect-MSGraph).UPN -ForegroundColor Cyan -BackgroundColor DarkMagenta -NoNewline;Write-Host " deleted $targetDeleteCount devices on " -NoNewline; Write-Host (Get-Date) "`n" -ForegroundColor Green
        } 
    else {
        SpacingBars
        Write-Warning "Aborting.."; Exit
        }
