<#
.SYNOPSIS
Disables and/or deletes stale computer and user accounts

.DESCRIPTION
- Supports exception list
- Adds "Disabled on ". Writes to Location property but that can be changed easily
- Send out status email

Look over the default values below and change them to something that makes sense in your environment, otherwise
I guarantee this will not work out of the box!

WARNING: this script makes changes to AD objects which may be hard to reverse. Use the WhatIf parameter when in doubt

DISCLAIMER: use at your own risk!!

.EXAMPLE
.\CleanStaleADObjects.ps1 -disableAfter 90 -deleteAfter 180 -whatIf
#>

Param(
    [Parameter(Mandatory=$False,HelpMessage="Number of days before object is considered stale. Set to 0 to skip")]
    [int]$disableAfter,

    [Parameter(Mandatory=$False,HelpMessage="Number of days before object is deleted. Set to 0 to skip")]
    [int]$deleteAfter,

    [Parameter(Mandatory=$False,HelpMessage="Exception list (one item per line. Users or computers")]
    [string[]]$exceptionListPath = ".\staleObjectsExceptionList.txt",

    [Parameter(Mandatory=$False,HelpMessage="Path of log file (if any)")]
    [string]$logFilePath = "d:\logs\staleObjects.log",

    [Parameter(Mandatory=$False,HelpMessage="From email address")]
    [string]$from = "staleObjects@domain.com",

    [Parameter(Mandatory=$False,HelpMessage="To email address")]
    [string]$to = "peopleWhoCareAboutStaleObjects@domain.com",

    [Parameter(Mandatory=$False,HelpMessage="SMTP server address")]
    [string]$smtpServer = "smtp.domain.com",

    [Parameter(Mandatory=$False,HelpMessage="OU to move disabled computers to")]
    [string]$disabledComputersOU = "OU=disabledComputers,DC=domain,DC=com",

    [Parameter(Mandatory=$False,HelpMessage="OU to move disabled users to")]
    [string]$disabledUsersOU = "OU=xEmployees,DC=domain,DC=com",

    [Parameter(Mandatory=$False,HelpMessage="AD Property for Disabled On text")]
    [string]$disabledOnTextADPropertyName = "Location",

    [Parameter(Mandatory=$False,HelpMessage="Process computer accounts?")]
    [boolean]$processComputers = $true,

    [Parameter(Mandatory=$False,HelpMessage="Process user accounts?")]
    [boolean]$processUsers = $true,

    [Parameter(Mandatory=$False,HelpMessage="Set this to see what the script *would* do")]
    [switch]$whatIf = $true
)

$Days           = (Get-Date).Adddays(-$disableAfter)
$Today          = (Get-Date -UFormat "%Y-%m-%d")
$disabledOnText = @{$disabledOnTextADPropertyName = ("Disabled On $Today") }

if (Test-Path $exceptionListPath) {
    $exceptionList = (Get-Content -Path $exceptionListPath)
}

# Process Computers
if ($processComputers -and $disableAfter -ge 0) {
    $Computers = Get-ADComputer -Filter {(LastLogonDate -lt $Days) -and (Enabled -eq $true)} |`
         ? { ($exceptionList -notcontains $_.Name) } | sort -Property Name

    # Disable account(s)
    if ($whatIf) {
        $Computers | Set-ADComputer $disabledOnText -WhatIf
        $Computers | Disable-ADAccount -WhatIf
        $Computers | Move-ADObject -TargetPath $disabledComputersOU -WhatIf
    } else {
        $Computers | Set-ADComputer $disabledOnText
        $Computers | Disable-ADAccount
        $Computers | Move-ADObject -TargetPath $disabledComputersOU
    }
    #Delete accounts that were moved to Disabled after 6 months
    $Computers = Get-ADComputer –Filter * -SearchBase $disabledComputersOU | Where-Object {$_.Location -GT (Get-Date).AddMonths(-7) -and $_.Location -LT (Get-Date).AddMonths(-6)}
    $Computers | Remove-ADObject
}


# Process User
if ($processUsers) {
    $Users = Get-ADUser -Filter {(LastLogonDate -lt $Days) -and (Enabled -eq $true)} -Properties Name, LastLogonDate, PasswordLastSet, PasswordNeverExpires |`
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
$messageParameters = @{
    From = "staleObjects@sandleroneill.com"
    #To = "cis-it-tech@sandleroneill.com"
    To = "ffreire@sandleroneill.com"
    SmtpServer = "sop-exch2010.sop.com"
    Subject = "Disabled AD Objects"
    Body = ($computers | Select-Object -Property Name, DNSHostName, Enabled, LastLogonDate | out-string -Width 99)
}

Send-MailMessage @messageParameters
