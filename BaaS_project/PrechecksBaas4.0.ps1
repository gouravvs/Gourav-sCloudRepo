# ============================================
# BAAS Node Migration Pre-Check 
#Version 4.0
#Author : gourav.binodkumardas@dxc.com

#--------------------------
#INPUT FILE READ and VALIDATION
#---------------------------

$InputFile = "C:\Temp\SQLCobaltServers.txt"
$OutputFile = "C:\Temp\BAAS_PreCheck_Report_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")
$LogFile = "C:\Temp\BAAS_PreCheck_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")
#-------------------------------
# Validate Input File
#-------------------------------
if (!(Test-Path $InputFile)) {
    Write-Host "Input file not found : $InputFile"
    exit
}
$Servers = Import-Csv $InputFile -Delimiter "`t"
#-------------------------------------
#USER Input and Check for Classiication
#-------------------------------------
# Check whether network copy is required
$RequireNetworkCopy = $Servers.Classification | Where-Object {
    $_ -and $_.Trim().ToUpper() -in @("PROD","DR")
}

if ($RequireNetworkCopy)
{
    $WaveNo = (Read-Host "Please enter the Wave No for Pre Checks").Trim()

    do
    {
        $Region = (Read-Host "Please enter the Region (US/SG/EMEA)").Trim().ToUpper()
    }
    while ($Region -notin @("US","EMEA","SG"))

    $FolderName = switch ($Region)
    {
        "EMEA" { "UKandFRA" }
        default { $Region }
    }

    $NetworkRoot = "\\dbg.ads.db.com\Global-VFS\FRA\46965-1\CyberArk_st01626\CobaltIron_SQL\PreChecks"
    $WaveFolder = "Wave$WaveNo"

    $DestinationFolder = Join-Path $NetworkRoot $WaveFolder
    $DestinationFolder = Join-Path $DestinationFolder $FolderName

    if (!(Test-Path $DestinationFolder))
    {
        New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
    }
}

$OptFolder = "C:\Program Files\TSM\baclient"
#-------------------------------
# Logging Function
#-------------------------------
function Write-Log {
    param([string]$Message)
 
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 
    "$Time : $Message" | Tee-Object -FilePath $LogFile -Append
}
 
#-------------------------------
# Result Collection
#-------------------------------
$Results = @()
 
Write-Log "=============================================="
Write-Log "Starting BAAS Node Migration Pre-Check V4"
Write-Log "=============================================="
 
foreach ($Server in $Servers)
{
    $ServerName = $Server.ServerName.Trim()
    $OptType    = $Server.OptType.Trim().ToUpper()
    $NodeName   = $Server.NodeName.Trim()

    #-----------------------------------
    # Discover SQL Server Instance
    #-----------------------------------

    $SqlInstance = ""

    try
    {
        $SqlInstance = Invoke-Command -ComputerName $ServerName -ScriptBlock {

            $SqlService = Get-CimInstance Win32_Service |
                Where-Object {
                    $_.Name -eq "MSSQLSERVER" -or
                    $_.Name -like "MSSQL$*"
                } |
                Select-Object -First 1

            if (!$SqlService)
            {
                throw "SQL Server service not found."
            }

            if ($SqlService.Name -eq "MSSQLSERVER")
            {
                return "localhost"
            }
            else
            {
                $InstanceName = $SqlService.Name -replace "^MSSQL\$", ""

                return "localhost\$InstanceName"
            }

        } -ErrorAction Stop

        Write-Log "SQL Instance      : $SqlInstance"
    }
    catch
    {
        $SqlInstance = ""

        Write-Log "SQL Instance Discovery Failed : $_"
    }
 
    Write-Log ""
    Write-Log "----------------------------------------------"
    Write-Log "Processing Server : $ServerName"
    Write-Log "OPT Type          : $OptType"
    Write-Log "Expected Node     : $NodeName"
 
    $OptFileNode = ""
    $OPTStatus = ""
    $SQLAgentServiceAccount = ""
    $IsLocalAdmin = ""

#-------------------------------
# Phase 1 - OPT File Validation
#-------------------------------
# Configuration
#-------------------------------
# ***** CHANGE THIS DURING TESTING *****
    
 
try
{
    $Result = Invoke-Command -ComputerName $ServerName -ScriptBlock {

        param($OptFolder,$OptType)

        #-----------------------------------
        # Find OPT File
        #-----------------------------------
        if($OptType -eq "FULL")
        {
            $Files = @(
                "dsmsql_full.opt",
                "dsm_sql_full.opt"
            )
        }
        else
        {
            $Files = @(
                "dsmsql_log.opt",
                "dsm_sql_log.opt"
            )
        }

        $OptFileNode = "OPT FILE NOT FOUND"

        foreach($File in $Files)
        {
            $Path = Join-Path $OptFolder $File

            if(Test-Path $Path)
            {
                $Node = Select-String `
                            -Path $Path `
                            -Pattern "^NODENAME" |
                        Select-Object -First 1

                if($Node)
                {
                    $OptFileNode = (($Node.Line -replace "^NODENAME\s+","").Trim())
                }
                else
                {
                    $OptFileNode = "NODENAME NOT FOUND"
                }

                break
            }
        }

        #-----------------------------------
        # SQL Agent Service Account
        #-----------------------------------
        $AgentService = Get-CimInstance Win32_Service |
                        Where-Object {
                                        $_.Name -eq "SQLSERVERAGENT" -or
                                        $_.Name -like "SQLAgent$*"
                                    } |
                        Select-Object -First 1

        if($AgentService)
        {
            $ServiceAccount = $AgentService.StartName
        }
        else
        {
            $ServiceAccount = "SQL AGENT SERVICE NOT FOUND"
        }

        #-----------------------------------
        # Local Administrator Check
        #-----------------------------------
        $IsLocalAdmin = "FAIL"

        if($AgentService)
        {
            $Admins = @(
                ([ADSI]"WinNT://./Administrators,group").psbase.Invoke("Members") |
                ForEach-Object {
                    $_.GetType().InvokeMember(
                        "Name",
                        'GetProperty',
                        $null,
                        $_,
                        $null
                    )
                }
            )

            $AccountName = $ServiceAccount.Split('\')[-1]
            if($Admins | Where-Object { $_ -ieq $AccountName })
            {
                $IsLocalAdmin = "PASS"
            }
        }

        #-----------------------------------
        # Return Results
        #-----------------------------------
        [PSCustomObject]@{
            OptFileNode             = $OptFileNode
            SQLAgentServiceAccount  = $ServiceAccount
            IsLocalAdmin            = $IsLocalAdmin
        }

    } -ArgumentList $OptFolder,$OptType -ErrorAction Stop

    $OptFileNode            = $Result.OptFileNode.Trim()
    $SQLAgentServiceAccount = $Result.SQLAgentServiceAccount
    $IsLocalAdmin           = $Result.IsLocalAdmin

    if($OptFileNode -eq $NodeName)
    {
        $OPTStatus = "PASS"
    }
    else
    {
        $OPTStatus = "FAIL"
    }

}
catch
{
    $OptFileNode = "CONNECTION FAILED"
    $SQLAgentServiceAccount = "CONNECTION FAILED"
    $IsLocalAdmin = "FAIL"
    $OPTStatus = "FAIL"

    Write-Log "Connection Failed : $_"
}
Write-Log "OPT File Node             : $OptFileNode"
Write-Log "Status                    : $OPTStatus"
Write-Log "SQL Agent Service Account : $SQLAgentServiceAccount"
Write-Log "Is Local Administrator    : $IsLocalAdmin"

#-------------------------------------------------------
# PHASE 2 - SQL Agent Job Validation
#-------------------------------------------------------
# SQL Agent Job Names
$FullBackupJobName = "DBAG Backup Database - zzzTOTALzzz"
$LogBackupJobName  = "DBAG Backup Log - zzzTOTALzzz"
$JobStatus = "FAIL"
$LastRunTime = ""
 
try
{
    if ($OptType -eq "FULL")
    {
        $JobName = $FullBackupJobName
    }
    else
    {
        $JobName = $LogBackupJobName
    }
 
    Write-Log "Checking SQL Agent Job : $JobName"
 
$JobResult = Invoke-Command -ComputerName $ServerName -ScriptBlock {
 
        param($JobName,$SqlInstance)
 
        Import-Module SqlServer -ErrorAction SilentlyContinue
 
        $Query = @"
SELECT
    j.name,
    j.enabled,
    ISNULL(h.run_status,-1) AS run_status,
    msdb.dbo.agent_datetime(h.run_date,h.run_time) AS LastRunTime
FROM msdb.dbo.sysjobs j
OUTER APPLY
(
    SELECT TOP (1)
           run_status,
           run_date,
           run_time
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = j.job_id
      AND step_id = 0
    ORDER BY instance_id DESC
) h
WHERE j.name = '$JobName'
"@
 
try
{
    Invoke-Sqlcmd `
        -ServerInstance $SqlInstance `
        -Database "msdb" `
        -Query $Query `
        -ErrorAction Stop
}
catch
{
    if ($_.Exception.Message -match "certificate|SSL Provider|not trusted")
    {
        Invoke-Sqlcmd `
            -ServerInstance $SqlInstance `
            -Database "msdb" `
            -Query $Query `
            -TrustServerCertificate `
            -ErrorAction Stop
    }
    else
    {
        throw
    }
}
 
    } -ArgumentList $JobName,$SqlInstance -ErrorAction Stop
#-ArgumentList $JobName -ErrorAction Stop
 
    if (!$JobResult)
    {
        Write-Log "Job Not Found."
        $JobStatus = "FAIL"
    }
    elseif ($JobResult.enabled -ne 1)
    {
        Write-Log "Job Exists but is Disabled."
        $JobStatus = "FAIL"
    }
    elseif ($JobResult.run_status -ne 1)
    {
        Write-Log "Last Job Execution Failed."
        $JobStatus = "FAIL"
    }
    else
    {
        $LastRunTime = $JobResult.LastRunTime

        Write-Log "Job Exists, Enabled and Last Run Successful."
        Write-Log "Last Run Time : $LastRunTime"
        $JobStatus = "PASS"
    }
    
 
}
catch
{
    Write-Log "Job Validation Failed : $_"
    $JobStatus = "FAIL"
}
 
  
#-------------------------------------------------------
# PHASE 3A - Validate Job History Node
#-------------------------------------------------------
$JobHistoryNode = ""
$TSMNodeStatus = "FALSE"

try
{
    $History = Invoke-Command -ComputerName $ServerName -ScriptBlock {

        param($JobName,$SqlInstance)

        Import-Module SqlServer -ErrorAction SilentlyContinue

        $Query = @"
SELECT TOP (1) message
FROM msdb.dbo.sysjobhistory h
INNER JOIN msdb.dbo.sysjobs j
ON h.job_id=j.job_id
WHERE j.name='$JobName'
AND h.step_id=2
ORDER BY h.instance_id DESC
"@

        try {
            Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "msdb" -Query $Query -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -match "certificate|SSL Provider|not trusted")
            {
                Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "msdb" -Query $Query -TrustServerCertificate -ErrorAction Stop
            }
            else { throw }
        }

    } -ArgumentList $JobName,$SqlInstance -ErrorAction Stop

    if($History.Message -match "Node Name:\s*(.*?)Session established")
    {
    $JobHistoryNode = $Matches[1].Trim()
    }
    else
    {
    $JobHistoryNode = "NODE NOT FOUND"
    }

    if($JobHistoryNode -eq $OptFileNode)
    {
        $TSMNodeStatus = "TRUE"
    }

    Write-Log "Job History Node : $JobHistoryNode"
    Write-Log "TSM Node Status  : $TSMNodeStatus"
}
catch
{
    $JobHistoryNode = "ERROR"
    $TSMNodeStatus = "FALSE"
    Write-Log "Phase 3A Failed : $_"
}
#---------------------------------------------------------
# Phase 3B - Get OPT file configured in SQL Agent Job Step 2
#---------------------------------------------------------
$JobStepOptFile = "Not Found"

try
{
    $JobStepResult = Invoke-Command -ComputerName $ServerName -ScriptBlock {

        param($JobName,$SqlInstance)

        Import-Module SqlServer -ErrorAction SilentlyContinue

        $JobStepQuery = @"
SELECT command
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobsteps s
ON j.job_id = s.job_id
WHERE j.name = '$JobName'
AND s.step_id = 2;
"@

        try {
            Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "msdb" -Query $JobStepQuery -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Message -match "certificate|SSL Provider|not trusted")
            {
                Invoke-Sqlcmd -ServerInstance $SqlInstance -Database "msdb" -Query $JobStepQuery -TrustServerCertificate -ErrorAction Stop
            }
            else { throw }
        }

    } -ArgumentList $JobName,$SqlInstance -ErrorAction Stop

    if ($JobStepResult.command -match '(?i)-optfile\s*=\s*("(?<OptFile>[^"]+)"|(?<OptFile>[^\s]+))')
    {
        $JobStepOptFile = [System.IO.Path]::GetFileName($Matches['OptFile'])
    }
        Write-Log "Job Step 2 OPT File : $JobStepOptFile"
}
catch
{
    $JobStepOptFile = "ERROR"
    Write-Log "Phase 3B Failed : $_"
}

$Results += [PSCustomObject]@{

    ServerName       = $ServerName
    OptType        = $OptType
    ExpectedNode   = $NodeName
    OptFileNode    = $OptFileNode
    OPTStatus      = $OPTStatus
    JobStatus      = $JobStatus
    LastRunTime    = $LastRunTime
    JobStepOptFile = $JobStepOptFile
    JobHistoryNode = $JobHistoryNode
    TSMNodeStatus  = $TSMNodeStatus
    SQLAgentServiceAccount = $SQLAgentServiceAccount
    IsLocalAdmin           = $IsLocalAdmin

}
 
}
 
$Results | Export-Csv $OutputFile -NoTypeInformation
 
Write-Log ""
Write-Log "=============================================="
Write-Log "Completed Successfully"
Write-Log "Report : $OutputFile"
Write-Log "=============================================="
 
Write-Host ""
Write-Host "Report Generated : $OutputFile"
if ($RequireNetworkCopy)
{
    Copy-Item $OutputFile -Destination $DestinationFolder -Force
    Copy-Item $LogFile -Destination $DestinationFolder -Force
}