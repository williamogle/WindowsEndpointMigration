function Set-ScriptAsScheduledTask
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)]
		[ValidateLength(5, 100)]
		[ValidateScript({
			if ($_ -match "\.ps1$")
			{
				$true
			}
			else
			{
				throw "ScriptName must end with '.ps1'"
			}
		})]
		[String]$ScriptName,

		[Parameter(Mandatory=$true)]
		[String]$ScriptPath,

		[Parameter(Mandatory=$true)]
		[ValidateSet("AtBoot", "AtLogon")]
		[String]$StartType
	)
	[String]$FullScriptPath = Join-Path -Path $ScriptPath -ChildPath $ScriptName #The full path of the script file
	[String]$ScheduledTaskName = $ScriptName.Replace(".ps1", "") #The name of the scheduled task to be created
	[String]$ScheduledTaskFolderDestination = "\"
	[String]$WindowsPowerShellExecutablePath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
	[String]$PowerShellExecutableArguments = "-ExecutionPolicy Bypass -File '$($FullScriptPath)'"

	#First we check if the function is being run as admin
	[Bool]$RunFromAdminContext = $false
	try
	{
		$RunFromAdminContext = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}
	catch
	{
		return $Error[0]
	}

	if ($RunFromAdminContext -eq $false)
	{
		throw "This function requires elevated privileges. Please ensure it is being run as an administrator."
	}


	#Now we need to validate that a file actually exists at the specified path with the specified name.
	[Bool]$ScriptFileExists = $false
	try
	{
		$ScriptFileExists = Test-Path -Path $FullScriptPath -PathType Leaf
	}
	catch
	{
		return $Error[0]
	}
	if ($ScriptFileExists -eq $false)
	{
		throw "The specified script file $($ScriptName) could not be found at $($ScriptPath)."
	}

	# Now we can interface with the Windows Task Scheduler API through Com
	$ScheduledTaskComObject = $null
	try
	{
		$ScheduledTaskComObject = New-Object -ComObject Schedule.Service -ErrorAction Stop
	}
	catch
	{
		return $Error[0]
	}
	if ($null -eq $ScheduledTaskComObject)
	{
		throw "Could not create Windows Task Scheduler API object."
	}
	# Attempt to connect to the Windows Task Scheduler API
	try
	{
		$ScheduledTaskComObject.Connect()
	}
	catch
	{
		return $Error[0]
	}

	# Create a Windows Task Scheduler task definition object
	$ScheduledTaskDefinitionObject = $null
	try
	{
		$ScheduledTaskDefinitionObject = $ScheduledTaskComObject.NewTask(0)
	}
	catch
	{
		return $Error[0]
	}
	if ($null -eq $ScheduledTaskDefinitionObject)
	{
		throw "Could not create Windows Scheduled Task definition object."
	}

	# Create a Windows Task Scheduler action object
	$ScheduledTaskActionObject = $null
	try
	{
		$ScheduledTaskActionObject = $ScheduledTaskDefinitionObject.Actions.Create(0)
	}
	catch
	{
		return $Error[0]
	}
	if ($null -eq $ScheduledTaskActionObject)
	{
		throw "Could not create Windows Scheduled Task action object."
	}
	try
	{
		$ScheduledTaskActionObject.Path = $WindowsPowerShellExecutablePath
		$ScheduledTaskActionObject.Arguments = $PowerShellExecutableArguments
	}
	catch
	{
		return $Error[0]
	}

	# Determine the trigger type based on StartType and rename it
	$ScheduledTaskTriggerType = switch ($StartType)
	{
		"AtBoot"
		{
			8
		} # TASK_TRIGGER_BOOT
		"AtLogon"
		{
			9
		} # TASK_TRIGGER_LOGON
		Default
		{
			throw "Specified value of $($StartType) is invalid."
		}
	}
	try
	{
		$ScheduledTaskDefinitionObject.Triggers.Create($ScheduledTaskTriggerType) | Out-Null
		$ScheduledTaskDefinitionObject.Settings.Enabled = $true
		$ScheduledTaskDefinitionObject.Settings.StartWhenAvailable = $true
	}
	catch
	{
		return $Error[0]
	}

	$ScheduledTaskFolderObject = $null
	try
	{
		$ScheduledTaskFolderObject = $ScheduledTaskComObject.GetFolder($ScheduledTaskFolderDestination)
	}
	catch
	{
		return $Error[0]
	}
	if ($null -eq $ScheduledTaskFolderObject)
	{
		throw "Windows Task Scheduler API was unable to get content from scheduled tasks path $($ScheduledTaskFolderDestination)"
	}

	#Now we register the scheduled task
	try
	{
		$ScheduledTaskFolderObject.RegisterTaskDefinition($ScheduledTaskName, $ScheduledTaskDefinitionObject, 6, "SYSTEM", $null, 5) | Out-Null
	}
	catch
	{
		return $Error[0]
	}

	$ScheduledTaskFolderObject = $null
	try
	{
		$ScheduledTaskFolderObject = $ScheduledTaskComObject.GetFolder($ScheduledTaskFolderDestination)
	}
	catch
	{
		return $Error[0]
	}
	
	if ($null -eq $ScheduledTaskFolderObject)
	{
		throw "Windows Task Scheduler API was unable to get content from scheduled tasks path $($ScheduledTaskFolderDestination)"
	}

	$RetrievedTask = $null
	try
	{
		$RetrievedTask = $ScheduledTaskFolderObject.GetTask($ScheduledTaskName)
	}
	catch
	{
		return $Error[0]
	}
	
	if ($null -eq $RetrievedTask)
	{
		throw "Could not find scheduled task with name $($ScheduledTaskName) in folder $($ScheduledTaskFolderDestination)"
	}

	$RetrievedTaskActions = $RetrievedTask.Definition.Actions
	$RetrievedTaskActionPath = ($RetrievedTaskActions | Select-Object -Property "Path").Path
	$RetrievedTaskActionArguments = ($RetrievedTaskActions | Select-Object -Property "Arguments").Arguments
	if (($RetrievedTaskActionPath -ne $WindowsPowerShellExecutablePath) -or ($RetrievedTaskActionArguments -ne $PowerShellExecutableArguments))
	{
		$ErrorMessage = "Retrieved scheduled task actions could not be validated.`nExpected action path: $($WindowsPowerShellExecutablePath)`nRetrieved action path: $($RetrievedTaskActionPath)`nExpected arguments: $($PowerShellExecutableArguments)`nRetrieved arguments: $($RetrievedTaskActionArguments)"
		throw $ErrorMessage
	}

	$RetrievedTaskTriggers = $RetrievedTask.Definition.Triggers
	$RetrievedTaskTriggerType = ($RetrievedTaskTriggers | Select-Object -Property "Type").Type
	if ($RetrievedTaskTriggerType -ne $ScheduledTaskTriggerType)
	{
		$ErrorMessage = "Retrieved scheduled task triggers could not be validated.`nExpected trigger type: $($ScheduledTaskTriggerType)`nRetrieved trigger type: $($RetrievedTaskTriggers)"
		throw $ErrorMessage
	}
	return
}