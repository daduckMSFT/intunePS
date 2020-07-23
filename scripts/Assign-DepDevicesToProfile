$PathToCsv = '.\Documents\deviceserials.csv' #can be something such as C:\Users\Username\Documents\ or a relative path! 
# Should simply have a single column - called serialNumber - then each row below it should have a single serial number of a device. 
$csv = Import-Csv -Path $PathToCsv


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

# We must be using the 'beta' endpoint URL's, so this updates that. 
$GraphEnvironment = Get-MSGraphEnvironment

if ($GraphEnvironment.SchemaVersion -eq 'v1.0') {
    Update-MSGraphEnvironment -SchemaVersion beta
}

# Gathers all of the available DEP tokens in the tenant
$depTokens = (Invoke-MSGraphRequest -HttpMethod GET -Url deviceManagement/depOnboardingSettings).value
$depTokenCount = $depTokens.Count
Write-Host "You have" $depTokenCount "Apple Enrollment Token(s) in your environment"

$i = 0;

# Parses through each DEP token and displays some identifying information to the user
ForEach ($token in $depTokens) { 
    $i++
    Write-Host "Token number: " $i -ForegroundColor Cyan
    Write-Host "`tName: " $token.tokenName
    Write-Host "`tEmail: " $token.appleIdentifier
    Write-Host "`tToken ID: " $token.id `n -ForegroundColor Yellow
}

SpacingBars

# Prompt the user to input the token ID (looks like this: 7c33350d-1905-47b2-ae74-6f1948b250dc_e08b4130-5cbb-4527-abe3-57112abc390d)
$tokenSelection = Read-Host "Which token would you like to use? Enter the Token ID (above in Yellow)"

# Parses through what the user entered, and compares it to known dep token ID's
$selectedToken = ForEach ($token in $DepTokens) { 
    if ($token.id -eq $tokenSelection) {
    $token }
}

SpacingBars

# If the value pasted in does not match, exit the script
if ($selectedToken.id -ne $tokenSelection) {
    Write-Warning "The token you entered does not match a token found in the tenant. Please try again."
    exit
}

# Compiles the basis URL that we will be using for our custom Graph API queries
# This will look like: deviceManagement/depOnboardingSettings/7c33350d-1905-47b2-ae74-6f1948b250dc/enrollmentProfiles/
# deviceManagement/depOnboardingSettings/<tokenId>/enrollmentProfiles/
$depUrlBase = 'deviceManagement/depOnboardingSettings/' + $selectedToken.id + '/enrollmentProfiles/'

# Gathers all existing DEP profiles for the selected DEP token
$enrollmentProfiles = (Invoke-MSGraphRequest -HttpMethod GET -Url $depUrlBase).value

# Displays to the user how many profiles exist for this token
Write-Host "Found" $enrollmentProfiles.count "enrollment profiles"

# Lists each profile's name and ID
$i = 0
ForEach ($p in $enrollmentProfiles) { 
    $i++
    write-host "`nProfile #:" $i -ForegroundColor Cyan
    Write-Host "Name: " $p.displayName
    Write-Host "Id: " $p.id -ForegroundColor Yellow
}

# Prompt the user to input the profile ID (looks like this: 7c33350d-1905-47b2-ae74-6f1948b250dc_e08b4130-5cbb-4527-abe3-57112abc390d)
$profileSelection = Read-Host "`nWhich token would you like to use? Enter the Profile ID (above in Yellow)"

SpacingBars

# Parses through the profile ID the user entered, and compares it to known enrollment profile ID's
$selectedProfile = ForEach ($p in $enrollmentProfiles) { 
    if ($p.id -eq $profileSelection) {
    $p }
}

# If the value pasted in does not match, exit the script
if ($selectedProfile.id -ne $profileSelection) {
    Write-Warning "The profile ID you entered does not match a profile found in the tenant. Please try again."
    exit
}

# Puts together a full URL with the token ID, the enrollmentProfile ID, and appends the "updateDeviceProfileAssignment" endpoint to send the serial numbers to
$profilePostUrl = $depUrlBase + $selectedProfile.id + '/updateDeviceProfileAssignment'

Write-Host "Valid profile found: " $selectedProfile.displayName;
Write-Host "Your CSV file at: " $PathToCsv "has" $csv.count "serial numbers in it"

<#
Goes through every serial number in the CSV, and sends a POST to the URL with the body containing the serial number

It will look like: 
deviceManagement/depOnboardingSettings/<tokenId>/enrollmentProfiles/<profileId/updateDeviceProfileAssignment 

The body should look like: 
{"deviceIds":["1234567889"]}

#> 


ForEach ($sn in $csv.serialNumber) {
    $postBody = "{""deviceIds"":[""$sn""]}"
    Invoke-MSGraphRequest -HttpMethod POST -Url $profilePostUrl -Content $postBody
}

SpacingBars

Write-Host "Assigned" $csv.count "devices to" $selectedProfile.displayName
