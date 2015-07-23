########################################################### 
# AUTHOR  : Brian O'Connell  @LifeOfBrianOC
# https://lifeofbrianoc.wordpress.com/
# It will do the following:
# Check for Active Directory Powershell Module and install if not Present
# Create OU's based on csv Input - Checks for existing OU first
# Create Groups based on csv input - Checks for existing Groups first
# Adds Groups to other Groups based on csv input
# Create Users based on csv Input - Checks for existing Users first
# Add Users to specific Groups based on csv Input         
########################################################### 


Write-host "This script will create all required AD users & groups in Active Directory
			" -ForegroundColor Yellow

################################################################################################################################
# 											AD Powershell Module	  													       #
################################################################################################################################

# Checking for Required AD Powershell Module. Importing if not available
Write-host "Checking for Required AD Powershell Module
			" -ForegroundColor Green

$name="ActiveDirectory"
	if(-not(Get-Module -name $name))
	{
		if(Get-Module -ListAvailable | Where-Object { $_.name -eq $name })
	{
# Module is installed so import it
			Import-Module -Name $name
		}
	else
	{
# If Module is not installed
	$false
		}
# Install Module
	write-host "Active Directory powershell Module Not Installed - Installing
			" -ForegroundColor Red
	{
		}
	Import-Module servermanager
	Add-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature | Out-Null
	}
# End if module is not installed
  else
{
# If Module is already installed
	write-host "Active Directory Module Already Installed - Continuing
              " -ForegroundColor Green
}

################################################################################################################################
# 											OU Creation	  																       #
################################################################################################################################

# Set Console ForegroundColor to Yellow for Read-Host as -ForegroundColor doesn't work with Read-Host
[console]::ForegroundColor = "yellow"

# Ask user for csv path 
    $CSVPath = Read-Host "Please enter the full path to your csv with user details"
						
# Reset Console ForegroundColor back to default
[console]::ResetColor()

# Verify CSV Path
	$testCSVPath = Test-Path $CSVPath
		if ($testCSVPath -eq $False) {Write-Host "CSV File Not Found. Please verify the path and retry
								             " -ForegroundColor Red
		Exit
		}
	else
	{

# Continue if CSV is found						
	Write-host "
				Creating Required OU's
					" -ForegroundColor Yellow

# Import CSV and only read lines that have an entry in createOUName column
	$csv = @()
	$csv = Import-Csv -Path $CSVPath |
	Where-Object {$_.createOUName}

# Loop through all items in the CSV
			ForEach ($item in $csv) 
# Check if the OU exists
				{
					$ouName = "OU=" + $item.createOUName
					$ouExists = [ADSI]::Exists("LDAP://$($ouName),$($item.createOUPath)")
  
					If ($ouExists -eq $true)
							{
	Write-Host "OU $($item.createOUName) already exists! OU creation skipped!
				" -ForegroundColor Red
	    }  
  Else
  {	  
# Create The OU
	$createOU = New-ADOrganizationalUnit -Name $item.createOUName -Path $item.createOUPath
	Write-Host "OU $($item.createOUName) created!
				" -ForegroundColor Green
	}
		}
			}
	  
	  Write-Host "OU Creation Complete
			" -ForegroundColor Green 
		
################################################################################################################################
# 											Group Creation	  																   #
################################################################################################################################	
	Write-host "
	Creating Required Groups
				" -ForegroundColor Yellow

# Get Domain Base Path
	$searchbase = Get-ADDomainController | ForEach {  $_.DefaultPartition }
  
# Import CSV and only read lines that have an entry in createGroup column
	$csv = @()
	$csv = Import-Csv -Path $CSVPath |
	Where-Object {$_.createGroup}

# Loop through all items in the CSV
			ForEach ($item In $csv)
				{
# Check if the Group already exists
	  $groupName = "CN=" + $item.createGroup + "," + $item.groupOU
      $groupExists = [ADSI]::Exists("LDAP://$($groupName),$($searchbase)")
	  
				if ($groupExists -eq $true)
				{
		Write-Host "Group $($item.createGroup) already exists! Group creation skipped!
				" -ForegroundColor Red
			}
    else
    {
      # Create the group if it doesn't exist
	  $createGroup = New-ADGroup -Name $item.createGroup -GroupScope $item.GroupType -Path ($($item.groupOU) + "," + $($searchbase))
      Write-Host "Group $($item.createGroup) created!
				" -ForegroundColor Green
    }
	   

# Setup Nested Groups
    # Split comma separated groups and only read lines that have an entry in addToGroup column
	$groupNameSplit = $item.addGroupToGroup.Split(',') |
	Where-Object {$item.addGroupToGroup}	
			ForEach ($group In $groupNameSplit) 
				{
# Check if the Group is already a member of the group
	$groupIsMember = (Get-ADGroupMember -Identity $group).name -contains "$($item.createGroup)"
			If ($groupIsMember -eq $true)
				{
				Write-Host "Group $($item.createGroup) is already a member of $($group). Add to Group skipped!
			" -ForegroundColor Red
		}
	else
		{
	Add-ADGroupMember -Identity $group -Member $item.createGroup;
	Write-Host "Group $($item.createGroup) added to group $($group)!
				" -ForegroundColor Green
					}
					}
   }
  
		Write-Host "Group Creation Complete
			" -ForegroundColor Green 
			
################################################################################################################################
# 											User Creation	  																   #
################################################################################################################################
# Creating Users from csv
	  Write-Host "Creating EHC Users and Adding to Security Groups
				" -ForegroundColor Yellow

  # Import CSV
	$csv = @()
	$csv = Import-Csv -Path $CSVPath 

# Loop through all items in the CSV
			ForEach ($item In $csv)
				{
 #Check if the User exists
	$samAccountName = "CN=" + $item.samAccountName
	$userExists = [ADSI]::Exists("LDAP://$($samAccountName),$($item.ouPath),$($searchbase)")
  
			If ($userExists -eq $true)
				{
	Write-Host "User $($item.samAccountName) Already Exists. User creation skipped!
			" -ForegroundColor Red
		}
	else
		{
# Create The User  
	$userPrincinpal = $item.samAccountName + "@" + $item.domain
	New-ADUser -Name $item.Name `
	-Path  ($($item.ouPath) + "," + $($searchbase)) `
	-SamAccountName  $item.samAccountName `
	-UserPrincipalName  $userPrincinpal `
	-AccountPassword (ConvertTo-SecureString $item.accountPassword -AsPlainText -Force) `
	-ChangePasswordAtLogon $false `
	-PasswordNeverExpires $true `
	-Enabled $true
		Write-Host "User $($item.samAccountName) created!
				" -ForegroundColor Green
			}
# Split comma separated groups and only read lines that have an entry in addToGroup column
	$userGroupNameSplit = $item.addToGroup.Split(',') |
	Where-Object {$item.addToGroup}	
			ForEach ($group In $userGroupNameSplit) 
				{
# Check if the User is already a member of the group
	$userIsMember = (Get-ADGroupMember -Identity $group).name -contains "$($item.samAccountName)"
			If ($userIsMember -eq $true)
				{
				Write-Host "User $($item.samAccountName) is already a member of $($group). Add to Group skipped!
			" -ForegroundColor Red
		}
	else
		{
	Add-ADGroupMember -Identity $group -Member $item.samAccountName;
	Write-Host "User $($item.samAccountName) added to group $($group)!
				" -ForegroundColor Green
					}

						}
							}
Write-host "Creating EHC Users and Adding to Security Groups Complete
			" -ForegroundColor Green
