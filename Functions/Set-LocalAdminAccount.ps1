function Set-LocalAdminAccount
{
	param (
		# Username of local account to set
		[Parameter(Mandatory = $true)]
		[String]$Username,
		# Password of local account to set
		[Parameter(Mandatory = $true)]
		[String]$Password,
		# DisplayName to use for account
		[Parameter(Mandatory = $false)]
		[string]$DisplayName = "",
		# Description to use for account
		[Parameter(Mandatory = $false)]
		[String]$Description = ""

	)
	[String]$BuiltInAdministratorsGroupSID = "S-1-5-32-544"
	[ADSI]$LocalMachineADSIInstance = $null
	try
	{
		$LocalMachineADSIInstance = [ADSI]"WinNT://$($env:COMPUTERNAME),Computer"
	}
	catch
	{
		return $Error[0]
	}
	$TargetUserAccountInstance = $null
	[bool]$UserAccountExists = $false
	[int]$UserAccountCreationCounter = 0

	while (($UserAccountCreationCounter -le 1) -and $UserAccountExists -eq $false)
	{
		$UserAccountObject = $null
		try
		{
			$UserAccountObject = Get-CimInstance -ClassName "Win32_UserAccount" -Filter "LocalAccount = '$true' AND Name = '$Username'"
		}
		catch
		{
			return $Error[0]
		}

		if ($null -ne $UserAccountObject)
		{
			$UserAccountExists = $true
		}
		else
		{
			try
			{
				$TargetUserAccountInstance = $LocalMachineADSIInstance.Create("User",$Username)
				$TargetUserAccountInstance.SetInfo()
			}
			catch
			{
				return $Error[0]
			}
			$TargetUserAccountInstance = $null
		}
		$UserAccountCreationCounter = $UserAccountCreationCounter + 1
	}
	if ($UserAccountExists -ne $true)
	{
		return 1
	}
	$TargetUserAccountInstance = $LocalMachineADSIInstance.GetObject("User",$Username)
	Add-Type -AssemblyName System.DirectoryServices.AccountManagement 
	$AccountManagementContextType = [DirectoryServices.AccountManagement.ContextType]::Machine
	$AccountManagementPrincipalContext = [DirectoryServices.AccountManagement.PrincipalContext]::new($AccountManagementContextType)
	[Boolean]$UserAccountPasswordSet = $false
	[int]$UserAccountPasswordSetCounter = 0
	while (($UserAccountPasswordSetCounter -le 1) -and ($UserAccountPasswordSet -eq $false))
	{
		try
		{
			$UserAccountPasswordSet = $AccountManagementPrincipalContext.ValidateCredentials($Username,$Password)
		}
		catch
		{
			return $Error[0]
		}

		if ($UserAccountPasswordSet -ne $true)
		{
			try
			{
				$TargetUserAccountInstance.SetPassword($Password)
				$TargetUserAccountInstance.SetInfo()
			}
			catch
			{
				return $Error[0]
			}
		}
		$UserAccountPasswordSetCounter = $UserAccountPasswordSetCounter + 1
	}
	if ($UserAccountPasswordSet -ne $true)
	{
		#If the password set wasn't successful, return 1 for error
		return 1
	}
	if ($DisplayName -ne "")
	{
		[bool]$UserAccountDisplayNameSet = $false
		[int]$UserAccountDisplayNameCounter = 0
		while (($UserAccountDisplayNameCounter -le 1) -and ($UserAccountDisplayNameSet -eq $false))
		{
			try
			{
				$TargetUserAccountInstance.FullName = $DisplayName
				$TargetUserAccountInstance.SetInfo()
			}
			catch
			{
				return $Error[0]
			}
			if ($TargetUserAccountInstance.FullName -eq $DisplayName)
			{
				$UserAccountDisplayNameSet = $true
			}
			$UserAccountDisplayNameCounter = $UserAccountDisplayNameCounter + 1
		}
		if ($UserAccountDisplayNameSet -ne $true)
		{
			return 1
		}
	}
	if ($Description -ne "")
	{
		[bool]$UserAccountDescriptionSet = $false
		[int]$UserAccountDescriptionCounter = 0
		while (($UserAccountDescriptionCounter -le 1) -and ($UserAccountDescriptionSet -eq $false))
		{
			try
			{
				$TargetUserAccountInstance.Description = $Description
				$TargetUserAccountInstance.SetInfo()
			}
			catch
			{
				return $Error[0]
			}
			if ($TargetUserAccountInstance.Description -eq $Description)
			{
				$UserAccountDescriptionSet = $true
			}
			$UserAccountDescriptionCounter = $UserAccountDescriptionCounter + 1
		}
		if ($UserAccountDescriptionSet -ne $true)
		{
			return 1
		}
	}
	[String]$BuiltInAdministratorsGroupName = ""
	try
	{
		$BuiltInAdministratorsGroupName = (Get-LocalGroup -SID $BuiltInAdministratorsGroupSID -ErrorAction Stop)[0].Name
	}
	catch
	{
		return $Error[0]
	}
	[Bool]$UserIsMemberofAdministratorsGroup = $false
	[int]$AdministratorsGroupMembershipAdditionCounter = 0
	while (($AdministratorsGroupMembershipAdditionCounter -le 1) -and ($UserIsMemberofAdministratorsGroup -eq $false))
	{
		$LocalAdministratorGroupMembership = $null
		try
		{
			$ADSIGroupObject = [ADSI]"WinNT://$env:COMPUTERNAME/$BuiltInAdministratorsGroupName"
			$LocalAdministratorGroupMembership = $ADSIGroupObject.Invoke("Members") | ForEach-Object {
				$ADSIPath = ([ADSI]$_).Path
				$UserSID = $(Split-Path $ADSIPath -Leaf)
				[PSCustomObject]@{
					ComputerName = $env:COMPUTERNAME
					DomainName = $(Split-Path -Path (Split-Path -Path $ADSIPath) -Leaf)
					Username = $(Split-Path -Path $ADSIPath -Leaf)
					UserSID = $UserSID
				}
			}
		}
		catch
		{
			return $Error[0]
		}
		$UserIsMemberofAdministratorsGroup = ($LocalAdministratorGroupMembership.Username -contains $Username)
		if ($UserIsMemberofAdministratorsGroup -eq $false)
		{
			try
			{
				Add-LocalGroupMember -Group $BuiltInAdministratorsGroupName -Member $Username -ErrorAction Stop | Out-Null
			}
			catch
			{
				return $Error[0]
			}
		}
		$AdministratorsGroupMembershipAdditionCounter = $AdministratorsGroupMembershipAdditionCounter + 1
	}
	if ($UserIsMemberofAdministratorsGroup -eq $false)
	{
		return 1
	}
	return 0
}