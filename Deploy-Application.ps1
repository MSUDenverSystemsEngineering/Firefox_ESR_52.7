<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
## Suppress PSScriptAnalyzer errors for not using declared variables during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Justification="Suppresses AppVeyor errors on informational variables below")]
## Suppress PSScriptAnalyzer errors for using traling whitespace during AppVeyor build
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidTrailingWhitespace", "", Justification="Suppresses AppVeyor errors on informational variables below")]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { Write-Error "Failed to set the execution policy to Bypass for this process." }

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Mozilla'
	[string]$appName = 'Firefox'
	[string]$appVersion = 'ESR 52.7.2'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '3.7.0.1'
	[string]$appScriptDate = '06/22/2018'
	[string]$appScriptAuthor = 'MSU Denver'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close Internet Explorer if needed, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome -CloseApps 'firefox,maintenanceservice' -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>

		## Uninstall previous version of Firefox
		If (Test-Path -Path "${envProgramFilesX86}\Mozilla Firefox" -PathType 'Container') {
			$exitCode = Execute-Process -Path "$envProgramFilesX86\Mozilla Firefox\uninstall\helper.exe" -Parameters "/S" -WindowStyle "Hidden" -WaitForMsiExec -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }
		}
		
		## Check for default user Mozilla data
		If (Test-Path -Path "${envSystemDrive}\Users\Default\AppData\Local\Mozilla" -PathType 'Container') {
			Write-Log -Message "Removing default user Local app data for Firefox..." -Severity 1
			Remove-File -Path "${envSystemDrive}\Users\Default\AppData\Local\Mozilla" -Recurse
			Remove-Folder -Path "${envSystemDrive}\Users\Default\AppData\Local\Mozilla"
		}

		If (Test-Path -Path "${envSystemDrive}\Users\Default\AppData\LocalLow\Mozilla" -PathType 'Container') {
			Write-Log -Message "Removing default user LocalLow app data for Firefox..." -Severity 1
			Remove-File -Path "${envSystemDrive}\Users\Default\AppData\LocaLow\Mozilla" -Recurse
			Remove-Folder -Path "${envSystemDrive}\Users\Default\AppData\LocalLow\Mozilla"
		}

		If (Test-Path -Path "${envSystemDrive}\Users\Default\AppData\Roaming\Mozilla" -PathType 'Container') {
			Write-Log -Message "Removing default user Roaming app data for Firefox..." -Severity 1
			Remove-File -Path "${envSystemDrive}\Users\Default\AppData\Roaming\Mozilla" -Recurse
			Remove-Folder -Path "${envSystemDrive}\Users\Default\AppData\Roaming\Mozilla"
		}

		If (Test-Path -Path "${envProgramFilesX86}\Mozilla Firefox\cck2.cfg" -PathType 'Leaf') {
			Write-Log -Message "Removing detected CCK revision for 32-bit Firefox..." -Severity 1
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\cck2.cfg"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\cck2" -Recurse
			Remove-Folder -Path "${envProgramFilesX86}\Mozilla Firefox\cck2"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\browser\override.ini"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\browser\defaults\profile\bookmarks.html"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\defaults\pref\autoconfig.js"
		}

		If (Test-Path -Path "${envProgramFiles}\Mozilla Firefox\cck2.cfg" -PathType 'Leaf') {
			Write-Log -Message "Removing detected CCK revision for 64-bit Firefox..." -Severity 1
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\cck2.cfg"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\cck2" -Recurse
			Remove-Folder -Path "${envProgramFiles}\Mozilla Firefox\cck2"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\browser\override.ini"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\browser\defaults\profile\bookmarks.html"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\defaults\pref\autoconfig.js"
		}

		## Clean up any registry keys indicating installation of a previous version of the CCK
		If (Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Value 'CCKFS') {
			## Remove Faculty Staff Hub CCK registry key
			Write-Log -Message "Removing registry keys for Faculty and Staff Hub CCK versions..." -Severity 1
			Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Name 'CCKFS'
		}

		If (Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Value 'CCKSH') {
			## Remove Student Hub CCK registry key
			Write-Log -Message "Removing registry keys for Student Hub CCK versions..." -Severity 1
			Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Name 'CCKSH'
		}

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>

		$exitCode = Execute-Process -Path "Firefox Setup ${appVersion}esr.exe" -Parameters "-ms" -WindowStyle "Hidden" -WaitForMsiExec -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }


		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>

		Remove-File -Path "$envCommonDesktop\Mozilla Firefox.lnk" -ContinueOnError $true

		If (Test-Path -Path "${envProgramFilesX86}\Mozilla Firefox" -PathType 'Container') {
			Write-Log -Message "Copying Faculty and Staff Hub CCK for 32-bit Firefox..." -Severity 1
			Copy-File -Path "${dirFiles}\*" -Destination "${envProgramFilesX86}\Mozilla Firefox" -Recurse
		}

		If (Test-Path -Path "${envProgramFiles}\Mozilla Firefox" -PathType 'Container') {
			Write-Log -Message "Copying Faculty and Staff Hub CCK for 64-bit Firefox..." -Severity 1
			Copy-File -Path "${dirFiles}\*" -Destination "${envProgramFiles}\Mozilla Firefox" -Recurse
		}

		Write-Log -Message "Writing installation registry keys..." -Severity 1
		Set-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Name 'CCKFS' -Value '1.3' -Type 'String'

		## Display a message at the end of the install
		If (-not $useDefaultMsi) {

		}
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'firefox,maintenanceservice' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>

		$exitCode = Execute-Process -Path "$envProgramFilesX86\Mozilla Firefox\uninstall\helper.exe" -Parameters "/S" -WindowStyle "Hidden" -WaitForMsiExec -PassThru
		If (($exitCode.ExitCode -ne "0") -and ($mainExitCode -ne "3010")) { $mainExitCode = $exitCode.ExitCode }

		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>

		If (Test-Path -Path "${envProgramFilesX86}\Mozilla Firefox\cck2.cfg" -PathType 'Leaf') {
			Write-Log -Message "Removing detected CCK revision for 32-bit Firefox..." -Severity 1
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\cck2.cfg"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\cck2" -Recurse
			Remove-Folder -Path "${envProgramFilesX86}\Mozilla Firefox\cck2"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\browser\override.ini"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\browser\defaults\profile\bookmarks.html"
			Remove-File -Path "${envProgramFilesX86}\Mozilla Firefox\defaults\pref\autoconfig.js"
		}

		If (Test-Path -Path "${envProgramFiles}\Mozilla Firefox\cck2.cfg" -PathType 'Leaf') {
			Write-Log -Message "Removing detected CCK revision for 64-bit Firefox..." -Severity 1
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\cck2.cfg"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\cck2" -Recurse
			Remove-Folder -Path "${envProgramFiles}\Mozilla Firefox\cck2"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\browser\override.ini"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\browser\defaults\profile\bookmarks.html"
			Remove-File -Path "${envProgramFiles}\Mozilla Firefox\defaults\pref\autoconfig.js"
		}

		If (Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Value 'CCKFS') {
			## Remove Faculty Staff Hub CCK registry key
			Write-Log -Message "Removing registry keys for Faculty and Staff Hub CCK versions..." -Severity 1
			Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Name 'CCKFS'
		}

		If (Get-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Value 'CCKSH') {
			## Remove Student Hub CCK registry key
			Write-Log -Message "Removing registry keys for Student Hub CCK versions..." -Severity 1
			Remove-RegistryKey -Key 'HKEY_LOCAL_MACHINE\SOFTWARE\MSUDenver' -Name 'CCKSH'
		}

	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}
