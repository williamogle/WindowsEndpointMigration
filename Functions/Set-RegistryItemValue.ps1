function Set-RegistryItemValue
{
	param (
		#The full path of the registry key
		[Parameter(Mandatory = $true)]
		[String]$RegistryKeyPath,
		# The name of the registry item
		[Parameter(Mandatory = $true)]
		[string]$RegistryItemName,
		# The value of the registry item
		[Parameter(Mandatory = $true)]
		[String]$RegistryItemValue,
		# The type of registry value
		[Parameter(Mandatory = $true)]
		[String]$RegistryItemType
	)
	[int]$RegistryKeyExistsCounter = 0
	[bool]$RegistryKeyCurrentlyExists = $false
	while(($RegistryKeyExistsCounter -le 1) -and ($RegistryKeyCurrentlyExists -eq $false))
	{
		[bool]$TestPathResult = $false
		try
		{
			$TestPathResult = Test-Path -Path "Registry::$($RegistryKeyPath)" -ErrorAction Stop
		}
		catch
		{
			return $Error[0]
		}
		if($TestPathResult -eq $true)
		{
			$RegistryKeyCurrentlyExists = $true
		}
		else
		{
			try
			{
				New-Item -Path "Registry::$($RegistryKeyPath)" -ErrorAction Stop | Out-Null
			}
			catch
			{
				return $Error[0]
			}
		}
		$RegistryKeyExistsCounter = $RegistryKeyExistsCounter + 1
	}
	if ($RegistryKeyCurrentlyExists -eq $false)
	{
		return 1
	}
	[int]$RegistryItemExistsCounter = 0
	[Bool]$RegistryItemCurrentlyExists = $false
	while(($RegistryItemCurrentlyExists -le 1) -and ($RegistryItemCurrentlyExists -eq $false))
	{
		$CurrentRegistryItemValue = $null
		try
		{
			$CurrentRegistryItemValue = Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryItemName -ErrorAction Stop
		}
		catch
		{
			return $Error[0]
		}
		if ($null -ne $CurrentRegistryItemValue)
		{
			$RegistryItemCurrentlyExists -eq $true
		}
		else
		{
			try
			{
				New-ItemProperty -Path $RegistryKeyPath -Name $RegistryItemName -Value $RegistryItemValue -PropertyType $RegistryItemType -ErrorAction Stop
			}
			catch
			{
				return $Error[0]
			}
		}
		$RegistryItemExistsCounter = $RegistryItemExistsCounter + 1
	}
	if ($RegistryItemCurrentlyExists -eq $false)
	{
		return 1
	}
	[int]$RegistryItemTypeCorrectCounter = 0
	[bool]$RegistryItemTypeCorrect = $false
	while (($RegistryItemTypeCorrectCounter -le 1) -and ($RegistryItemTypeCorrect -eq $false))
	{
		$CurrentRegistryItemValue = $null
		try
		{
			$CurrentRegistryItemValue = Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryItemName -ErrorAction Stop
		}
		catch
		{
			return $Error[0]
		}
		if (($CurrentRegistryItemValue."$($RegistryItemName)").GetType() -eq $RegistryItemType)
		{
			$RegistryItemTypeCorrect = $true
		}
		else
		{
			try
			{
				Remove-ItemProperty -Path "Registry::$($RegistryKeyPath)" -Name $RegistryItemName -ErrorAction Stop | Out-Null
			}
			catch
			{
				return $Error[0]
			}

			try
			{
				New-ItemProperty -Path $RegistryKeyPath -Name $RegistryItemName -Value $RegistryItemValue -PropertyType $RegistryItemType -ErrorAction Stop | Out-Null
			}
			catch
			{
				return $Error[0]
			}
		}
		$RegistryItemTypeCorrectCounter = $RegistryItemTypeCorrectCounter + 1
	}
	if ($RegistryItemTypeCorrect -eq $false)
	{
		return 1
	}
	[int]$RegistryItemSetValueCounter = 0
	[bool]$RegistryItemValueSet = $false
	while(($RegistryItemSetValueCounter -le 1) -and ($RegistryItemValueSet -eq $false))
	{
		$CurrentRegistryItemValue = $null
		try
		{
			$CurrentRegistryItemValue = Get-ItemProperty -Path $RegistryKeyPath -Name $RegistryItemName -ErrorAction Stop
		}
		catch
		{
			return $Error[0]
		}
		if ($CurrentRegistryItemValue -eq $RegistryItemValue)
		{
			$RegistryItemValueSet = $true
		}
		else
		{
			try
			{
				Set-ItemProperty -Path "Registry::$($RegistryKeyPath)" -Name $RegistryItemName -Value $RegistryItemValue -ErrorAction Stop | Out-Null
			}
			catch
			{
				return $Error[0]
			}
		}
		$RegistryItemSetValueCounter = $RegistryItemSetValueCounter + 1
	}
	if ($RegistryItemValueSet -eq $false)
	{
		return 1
	}
	return 0
}