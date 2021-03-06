
param(
    [string]$K2Server = "localhost",
    [int]$K2Port = "5555",
		$LDAPpaths = @
    [string[]]$ldapPaths = ( "LDAP://DC=EUROPE,DC=DENALLIX,DC=COM", "LDAP://DC=ASIA,DC=DENALLIX,DC=COM", "LDAP://DC=US,DC=DENALLIX,DC=COM"),
    [string[]]$netbiosNames = ("DENALLIX","DENALLIX","DENALLIX"),
    [int]$startMinusDays = -10,
    [int]$nrOfParallels = 15
)



Add-Type -AssemblyName ("SourceCode.Security.UserRoleManager.Management, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
Add-Type -AssemblyName ("SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")



Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile = "c:\temp\LogFile2.log"
    )


    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "[$Stamp] $Level : $Message"
    #Add-Content $logfile -Value $Line
    switch ($Level) {
        "INFO" {
            Write-Host $Line
        }
        "WARN" {
            Write-Host $Line
        }
        "ERROR" {
            Write-Error $Line
        }
        "FATAL" {
            Write-Error $Line
        }
        "DEBUG" {
            Write-Debug $Line
        }
    }
}


$functions = {
 

    Add-Type -AssemblyName ("SourceCode.Security.UserRoleManager.Management, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")
    Add-Type -AssemblyName ("SourceCode.HostClientAPI, Version=4.0.0.0, Culture=neutral, PublicKeyToken=16a2c5aaaa1b130d")

    Function GetK2ConnectionString{
	    Param([string]$k2hostname, [int] $K2port = 5555)

	    $constr = New-Object -TypeName SourceCode.Hosting.Client.BaseAPI.SCConnectionStringBuilder
	    $constr.IsPrimaryLogin = $true
	    $constr.Authenticate = $true
	    $constr.Integrated = $true
	    $constr.Host = $K2hostname
	    $constr.Port = $K2port
	    return $constr.ConnectionString
    }


    Function Write-Log {
        [CmdletBinding()]
        Param(
        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory=$True)]
        [string]
        $Message,

        [Parameter(Mandatory=$False)]
        [string]
        $logfile = "c:\temp\LogFile2.log"
        )


        $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
        $Line = "[$Stamp] $Level : $Message"
        #Add-Content $logfile -Value $Line
        switch ($Level) {
            "INFO" {
                Write-Host $Line
            }
            "WARN" {
                Write-Host $Line
            }
            "ERROR" {
                Write-Error $Line
            }
            "FATAL" {
                Write-Error $Line
            }
            "DEBUG" {
                Write-Debug $Line
            }
        }
    }








    Function ResolveIdentity{
	    Param($identity)
   
	    $swResolve = [Diagnostics.Stopwatch]::StartNew()
	    Write-Log DEBUG "Resolving identity $($identity.FQN) of type $($identity.Type)"
    
        $constr = GetK2ConnectionString -K2Hostname $identity.K2Server -K2Port $identity.K2Port
        Write-Log DEBUG "K2 connection string: $constr"
    
        $urm = New-Object SourceCode.Security.UserRoleManager.Management.UserRoleManager
        $urm.CreateConnection() | Out-Null
        $urm.Connection.Open($constr) | Out-Null

	    $fqn = New-Object -TypeName SourceCode.Hosting.Server.Interfaces.FQName -ArgumentList $identity.FQN
        if ($identity.Type -eq "User") {
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Identity)
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Members)
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::User, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Containers)
        } else {
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::Group, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Identity)
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::Group, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Members)
	        $urm.ResolveIdentity($fqn, [SourceCode.Hosting.Server.Interfaces.IdentityType]::Group, [SourceCode.Hosting.Server.Interfaces.IdentitySection]::Containers)
        }
    

        $urm.Connection.Close()
        Write-Log INFO "Resolved identity $($identity.FQN) in $($swResolve.ElapsedMilliseconds)ms."
      
    }

}

$functions | Out-Null




$sw = [Diagnostics.Stopwatch]::StartNew()

# Getting last run
$lastWhenChanged = [System.DateTime]::UtcNow.AddDays($startMinusDays);
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$lastrunfile = Join-Path -Path $scriptPath -ChildPath "LastWhenChanged.txt"
if (Test-Path $lastrunfile) {
    $strLastWhenChanged = (Get-content $lastrunfile -ErrorAction Stop)
    $lastWhenChanged = [System.DateTime]::ParseExact($strLastWhenChanged, "yyyyMMddHHmmss.fK", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
}


$whenChangedqueryFilter = $lastWhenChanged.ToString("yyyyMMddHHmmss.fK");
$adFilterQuery = "(&(whenChanged>=$whenChangedqueryFilter)(!(objectClass=computer)))"
Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Starting K2 ResolveUser script. Last whenChanged is $lastWhenChanged."

$identityToResolve = @()

for ($i=0; $i -lt $ldapPaths.length; $i++) {
    $ldapPath = $ldapPaths[$i]
    $netbiosName = $netbiosNames[$i]
    Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Connecting to AD. Ldap: $ldapPath ; Netbios: $netbiosName ; Filter: $adFilterQuery"
    $dirEntry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($dirEntry)
	
    $searcher.Filter = $adFilterQuery
    $searcher.PageSize = 1000;
    $searcher.SearchScope = "Subtree"
    $searcher.PropertiesToLoad.Add("sAMAccountName") | Out-Null
    $searcher.PropertiesToLoad.Add("objectClass") | Out-Null
    $searcher.PropertiesToLoad.Add("whenChanged") | Out-Null

    Write-Log DEBUG -Message "$($sw.ElapsedMilliseconds)ms: Starting FindAll()"
    $searchResult = $searcher.FindAll()


    Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Searching AD using filter: $adFilterQuery"
    foreach ($result in $searchResult) {
	    $props = $result.Properties
        $fqn = [string]::Concat("K2:", $netbiosName, "\", $props.samaccountname)
        

        if (($props.objectclass.Contains("user") -eq $true) -or ($props.objectclass.Contains("group") -eq $true)) {
            $u = New-Object System.Object
            $u | Add-Member -Name "FQN" -Value $fqn -MemberType NoteProperty
            $u | Add-Member -Name "Started" -Value $false -MemberType NoteProperty
            $u | Add-Member -Name "LastChanged" -Value $props.whenchanged[0] -MemberType NoteProperty
            $u | Add-Member -Name "K2Server" -Value $K2Server -MemberType NoteProperty
            $u | Add-Member -Name "K2Port" -Value $K2Port -MemberType NoteProperty

	        if ($props.objectclass.Contains("user") -eq $true) {
                $u | Add-Member -Name "Type" -Value "User" -MemberType NoteProperty
            } else {
                $u | Add-Member -Name "Type" -Value "Group" -MemberType NoteProperty
            }
            Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Found $($u.FQN) in AD"
            $identityToResolve += $u
        } else {
            Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Skipping $($objResult.Path) - Not a User/Group ObjectClass"
        }
        
    }

    Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Found $($identityToResolve.Count) users and/or groups to resolve. Time used until now: $($sw.ElapsedMilliseconds)ms."

    $searchResult.Dispose()
    $searcher.Dispose()
    $dirEntry.Dispose()
    Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Cleaned up AD resources..."
}






Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Starting user resolution loop."



if ($identityToResolve.Count -gt 0) {
    $totalJobs = 0;
    $notStarted = $identityToResolve
    while ($notStarted.Count -gt 0) {
        Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Some items are not started, let's start a few, max $nrOfParallels"
        
        while (@(Get-Job -State Running).Count -ge $nrOfParallels) {
            Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: We have $nrOfParallels already running. Sleeping for 1 second"
            Start-Sleep -Seconds 1
        }

        $user = $notStarted[0];

        Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Starting job for $($user.FQN) on port $($user.K2Port)"
        
        Start-Job -InitializationScript $functions -name $user.FQN -ScriptBlock {
            Param($u)
            ResolveIdentity $u
        } -ArgumentList $user | Out-Null
        $totalJobs += 1; 
        $notStarted[0].Started = $true
          

        Get-Job -State Completed | Receive-Job
        Get-Job -State Completed | Remove-Job
        Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Removed completed jobs..."

        if ($lastWhenChanged -lt $user.LastChanged) {
            $lastWhenChanged = $user.LastChanged
        }
        
        $notStarted = ($notStarted | Where-Object { $_.Started -eq $false})

        Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Completed Ready for next batch..."

    }
} else {
    Write-Log INFO "$($sw.ElapsedMilliseconds)ms: No users to resolve."
}

while (@(Get-Job -State Running).Count -ge 1) {
    Write-Log DEBUG "$($sw.ElapsedMilliseconds)ms: Waiting for jobs to complete..."
    Start-Sleep -Seconds 5
    Get-Job -State Completed | Receive-Job
    Get-Job -State Completed | Remove-Job
    $count = (Get-Job).Count
    Write-Log INFO "$($sw.ElapsedMilliseconds)ms: $count jobs to be completed..."
}



Write-Log INFO "$($sw.ElapsedMilliseconds)ms: K2 ResolveUser script completed in $($sw.ElapsedMilliseconds)ms."

Write-Log INFO "$($sw.ElapsedMilliseconds)ms: Setting last change file to $lastWhenChanged"
$lastWhenChanged = [System.DateTime]::SpecifyKind($lastWhenChanged, [System.DateTimeKind]::Utc);
Set-Content -Path $lastrunfile -Value $lastWhenChanged.ToUniversalTime().ToString("yyyyMMddHHmmss.fK");

Write-Log INFO "$($sw.ElapsedMilliseconds)ms: K2 ResolveUser script completed in $($sw.ElapsedMilliseconds)ms."

