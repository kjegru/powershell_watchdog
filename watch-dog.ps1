<#
.SYNOPSIS
  Name: watch-dog.ps1
  The purpose of this script is to genereate hashes of the files in a directory and its sub directory to check if they have been changed.
  
.DESCRIPTION
	This script is for Windows environment where you want to check if the files have been changed. It can be run with task scheduler at a 
	regular interval and will report which files have been edited or added.
	
.PARAMETER InitialDirectory
	$directoryPath is the directory where you check the files
	$wokringdir is where the files with the hashes will be put. Default c:\watchdog\
  
.PARAMETER Add
  A switch parameter that will cause the example function to ADD content.

Add or remove PARAMETERs as required.

.NOTES
    Updated: 09.02.2019 - First script
    Release Date: 9th of February 2019
   
  Author: Kjetil Grun

.EXAMPLE
	Watch-dog.ps1 -directoryPath "C:\inetpub\nasa.gov\" -customer "NASA" -workingdir "f:\watchdog-hashes\" -exclude "*.png,*.jpg,*.pdf"

#requires -version 4
#>
param (
	# Location of the files to be checked
	[Parameter(Mandatory=$true)]
	[string]	$directoryPath,
	# Customername
	[Parameter(Mandatory=$true)]
	[string]	$customer,
	# Full path to working dir. C:\watchdog\ if nothing is specified
	[Parameter(Mandatory=$false)]
	[AllowNull()]
	[string]	$workingdir,
	# Full or partly name of the path to exclude. 
	[Parameter(Mandatory=$false)]
	[array]		$exclude
)

function set-variables {
	if ($workingdir.Length -eq 0) {
		$workingdir = "c:\watchdog\"
	}
	if (!(Test-Path $workingdir)) {
		mkdir $workingdir
	}
	$newHashFile = "$workingdir\$customer-new.txt"
	$oldHashFile = "$workingdir\$customer-old.txt"
	$messageFile = "$workingdir\$customer.message"
	# Checking if this is first run.
	if ((Test-path $oldHashFile) -eq $true) {
		$firstRun = $false
	}
	else {
		$firstRun = $true
	}
	$hostname = hostname
	New-item $messageFile -force
	new-item $newHashFile -force
	start-hashing
}

function start-hashing {
	foreach ($file in (Get-ChildItem -path $directoryPath -recurse -file -Exclude $exclude)) {
			$filehash = Get-Filehash $file.fullname
			add-content -path $newHashFile -value $filehash.hash -nonewline
			add-content -path $newHashFile -value "," -nonewline
			add-content -path $newHashFile -value $filehash.path
	}
	compare-hashfiles
}

function compare-hashfiles {
	if (!(Test-path $oldHashFile)) {
		Write-Output "First run. No old hash to compare with"
	}
	else {
		$difference = (Compare-Object (Get-Content $newHashFile) (Get-Content $oldHashFile))
		write-host $difference
		if ($difference -ne $null) {
			$changedFiles = New-Object System.Collections.ArrayList
			$newFiles = New-Object System.Collections.ArrayList
			$difference | foreach-object {
				if ($_.SideIndicator -like "<=") {
					# Extracting the path from the Compare-Object result
					$newFiles.Add(($_.InputObject -split(","))[1]) > $null
				}
				elseif ($_.SideIndicator -like "=>") {	
					# Extracting the path from the Compare-Object result
					$changedFiles.Add(($_.InputObject -split(","))[1]) > $null
				}
			}
		}
		else {
			Write-host "No Changes"
		}
	}
	write-result
}

function write-result {
	if ($changedFiles.count -gt 0) {
		Add-Content -Path $messageFile -Value "Files Changed for $customer on folder $directoryPath on host $hostname"
		$changedFiles | ForEach-Object {
			Add-Content -Path $messageFile -Value $_
		}
	}
	if ($newFiles.count -gt 0) {
		Add-Content -Path $messageFile -Value "Files New for $customer on folder $directoryPath on host $hostname"
		$newFiles | ForEach-Object {
			Add-Content -Path $messageFile -Value $_
		}
	}
	if ($newFiles.Count -eq 0 -and $changedFiles.Count -eq 0 -and $firstRun -eq $false) {
		Add-Content -Path $messageFile -Value "No new files for $customer on folder $directoryPath on host $hostname."
	}
	elseif ($newFiles.Count -eq 0 -and $changedFiles.Count -eq 0 -and $firstRun -eq $false) {
		Add-Content -Path $messageFile -Value "First run for $customer on folder $directoryPath on host $hostname."
	}
	foreach ($line in (get-content $messageFile)) {
		# insert preferred channel for messagin; email, slack, SMS, push....
		Write-Host $line
	}
		
	stop-script
}

function stop-script {
	#Set-location -path c:\scripts
	Move-item $newHashFile $oldHashFile -force
}


set-variables