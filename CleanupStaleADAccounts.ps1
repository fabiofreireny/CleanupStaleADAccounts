<#
.SYNOPSIS
Disables and/or deletes stale computer and user accounts

.DESCRIPTION
Disables and/or deletes stale computer and user accounts
- Supports exception list
- Adds "Disabled on ". Writes to Location property but that can be changed easily
- Send out status email

Look over the default values below and change them to something that makes sense in your environment, otherwise I guarantee this will not work out of the box!

WARNING: this script makes changes to AD objects which may be hard (or impossible) to reverse. Use the WhatIf parameter when in doubt

WARNING: Setting deleteAfter < disableAfter could disable then immediately delete an object, or outright delete it!

DISCLAIMER: use at your own risk!!

.PARAMETER disableAfter
Number of days *since last logon* after which a user/computer will be disabled. Set to 0 (zero) to skip

.PARAMETER deleteAfter
Number of days *since last logon* after which a user/computer will be deleted. Set to 0 (zero) to skip

.PARAMETER exceptionListPath
Path to file that contains exception list (one item per line. Users or computers)

.PARAMETER logFilePath
Path of log file (if any). Not specifying this will not create log

.PARAMETER from
From email address

.PARAMETER to
To email address

.PARAMETER smtpServer
SMTP server address. Not specifying this will not send email

.PARAMETER disabledComputersOU
OU where disabled computer accounts will be moved to

.PARAMETER disabledUsersOU
OU where disabled user accounts will be moved to

.PARAMETER disabledOnTextADPropertyName
AD Property for "Disabled On ..." text

.PARAMETER processComputers
Process computer accounts? Default is $True

.PARAMETER processUsers
Process user accounts? Default is $True

.PARAMETER WhatIf. Default it $True. Specify $False to do actual work
Dry-run

.EXAMPLE
.\CleanStaleADObjects.ps1 -disableAfter 90 -deleteAfter 180 -whatIf
#>

Param(
    [int]$disableAfter = 0,
    [int]$deleteAfter = 30,
    [string]$exceptionListPath = ".\staleObjectsExceptionList.txt",
    [string]$logFilePath = "d:\logs\staleObjects.log",
    [string]$from = "staleObjects@domain.com",
    [string]$to = "peopleWhoCareAboutStaleObjects@domain.com",
    [string]$smtpServer,
    [string]$disabledComputersOU = "OU=disabledComputers,$($(Get-ADDomain).DistinguishedName)",
    [string]$disabledUsersOU = "OU=xEmployees,$($(Get-ADDomain).DistinguishedName)",
    [string]$disabledOnTextADPropertyName = "Location",
    [boolean]$processComputers = $true,
    [boolean]$processUsers = $true,
    [switch]$whatIf = $true
)

$disableDays    = (Get-Date).Adddays(-$disableAfter)
$deleteDays     = (Get-Date).Adddays(-$deleteAfter)
$Today          = (Get-Date -UFormat "%Y-%m-%d")
$disabledOnText = @{$disabledOnTextADPropertyName = ("Disabled On $Today") }

if (Test-Path $exceptionListPath) {
    $exceptionList = (Get-Content -Path $exceptionListPath)
}

# Process Computers
if ($processComputers) {
    if ($disableAfter -gt 0) {
        $Computers = Get-ADComputer -Filter {(LastLogonDate -lt $disableDays) -and (Enabled -eq $true)} |`
             ? { ($exceptionList -notcontains $_.Name) } | sort -Property Name

        # Disable computer account(s)
        if ($whatIf) {
            $Computers | Set-ADComputer @disabledOnText -WhatIf
            $Computers | Disable-ADAccount -WhatIf
            $Computers | Move-ADObject -TargetPath $disabledComputersOU -WhatIf
        } else {
            $Computers | Set-ADComputer @disabledOnText
            $Computers | Disable-ADAccount
            $Computers | Move-ADObject -TargetPath $disabledComputersOU
        }
    }
    if ($deleteAfter -gt 0) {
        $Computers = Get-ADComputer -SearchBase $disabledComputersOU -Filter {(LastLogonDate -lt $deleteDays) -and (Enabled -eq $false)}

        # Delete computer account(s)
        if ($whatIf) {
            $Computers | Remove-ADObject -WhatIf
        } else {
            $Computers | Remove-ADObject
        }
    }
}


# Process User
if ($processUsers) {
    $Users = Get-ADUser -Filter {(LastLogonDate -lt $disableDays) -and (Enabled -eq $true)} |`
        ? { ($exceptionList -notcontains $_.Name) } | sort -Property Name

    #$Users | Select-Object -Property Name, Enabled, LastLogonDate, PasswordLastSet, PasswordNeverExpires | sort -Property Name  | Export-Csv c:\temp\staleUsers.csv

    #Register date account was disabled (use Location field for info since there isn't a pre-defined one)
    #	$Users | Set-ADUser -Office ("Disabled on " + $Today)
    #	$Users | Disable-ADAccount

    #Move account to Disabled OU
    #	$Users | Move-ADObject -TargetPath "OU=X-Employees,DC=sop,DC=com"

    #	#Delete accounts that were moved to Disabled after 6 months
    #	$Computers = Get-ADComputer –Filter “Name –like ‘*’”–SearchBase "OU=Computers_Stale,DC=TEST,DC=Local" | Where-Object {$_.Location -GT (Get-Date).AddMonths(-7) -and $_.Location -LT (Get-Date).AddMonths(-6)}
    #	$Computers | Remove-ADObject
}

#Prepare email
if ($smtpServer) {
    $messageParameters = @{
        From = $from
        To = $to
        SmtpServer = $smtpServer
        Subject = "Disabled AD Objects"
        Body = ($computers | Select-Object -Property Name, DNSHostName, Enabled, LastLogonDate | out-string -Width 99)
    }

    Send-MailMessage @messageParameters
}