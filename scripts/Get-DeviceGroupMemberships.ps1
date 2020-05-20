# Basic function that checks if the user is in the administrator group. Warns and stops if the user is not. Sets the global "isAdmin" variable to "true" if admin. 
function CheckIfAdmin {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "You are not running this as local administrator. Run it again in an elevated prompt." ; break }
    else {
        $global:isAdmin = "true" }
}

<# CheckModuleInstalled is a function that verifies if the  Graph Module is installed, and allows the user to install it #>
function CheckModuleInstalled {
    if (Get-Module -ListAvailable -Name AzureAD) {
        Write-Host "Azure AD PowerShell Module found, proceeding with script...`n"
    }

    else {
        Write-Warning "Azure AD PowerShell Module not installed."
        $InstallYesNo = Read-Host "Would you like to install it? Yes/No"

        if($InstallYesNo -like "Yes" -or $InstallYesNo -like "Y") {
            CheckIfAdmin
            if ($global:isAdmin -eq "true") {
                try {
                    Write-Host "Installing the Azure AD PowerShell Module"
                    Write-Warning "This could take some time, possibly even a few minutes"
                    Install-Module -Name AzureAD }
                catch {
                    Write-Warning "Installing the module failed, please try manually running`n    Install-Module -Name AzureAD`n`nin an elevated prompt" }
                }
            else {
                CheckIfAdmin }
        } else {
            Write-Warning "You must have the Azure AD PowerShell Module installed to continue."; break }
    }
}

function ConnectToAAD {
    try {
        Write-Host "Connecting to Azure AD... please login using the appropriate account."  -ForegroundColor White -BackgroundColor Black
        Connect-AzureAD | Out-Null
    } 
    catch {
        Write-Warning "Connecting failed, please try again.";
    }
    $global:AADSession = (Get-AzureADCurrentSessionInfo).Account.Id
    $global:AADSessionTenant = (Get-AzureADCurrentSessionInfo).TenantDomain

    Write-Host "Hello " -NoNewline; Write-Host "$AADSession" -ForegroundColor White -BackgroundColor DarkMagenta -NoNewline; Write-Host "!`n"
    Write-Host "You have connected to the $AADSessionTenant tenant."
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

<# If successful, it will then connect to the Microsoft AAD service #>
    ConnectToAAD

$DeviceId = Read-Host "Please enter the Azure (not Intune) Device Id: "

# Get all groups, only grab their DisplayName and ObjectId.
# This will  be initialized as an array that contains the ObjectId and DisplayName for each group. 
$AADGroups = Get-AzureADGroup -All 1 | Select-Object ObjectId,DisplayName
$AADGroupCount = $AADGroups.Count

# Create a global variable as an array. This will contain the group membership names. 
# The second array ($DeviceMembershipInfoArray) is the actual array that we can modify after it's declared. 
$DeviceMembershipInfo = @()
[System.Collections.ArrayList]$DeviceMembershipInfoArray = $DeviceMembershipInfo

# This takes every group in the tenant (in the $AADGroups array above). 
# It then cycles through every single group looking for a member object with the DeviceId entered at the beginning. 
# If a member is found, it adds the group name to $DeviceMembershipInfoArray. 

ForEach ($group in $AADGroups)
    { 
    $GroupMemberDevice = $group.objectId | Get-AzureADGroupMember | Where-Object {$_.DeviceId -eq "$DeviceId"}
    if ($GroupMemberDevice -ne $null)
        {
            $global:DeviceMembershipInfoArray.Add($group.DisplayName) | Out-Null
        }
   }

# This gathers how many indexes are in the array (which is equivalent to how many group memberships are found)
$MembershipCount = $DeviceMembershipInfoArray.Count

Clear-Host

Write-Host "Your device was found in $MembershipCount groups out of $AADGroupCount total:`n`n"
Out-String -InputObject $DeviceMembershipInfoArray