
<#
IBM Storage Protect TSM OPT File Updater for SQL Nodes 
Version 3.0
Author : gourav.binodkumardas@dxc.com
#>
#======================== Logging ==========================
###############################################################
# PHASE 1 - SQL Job Status Check and Disable Log Backup Job
###############################################################
do {
    $CRNo = (Read-Host "Please enter the CR/ITSK No ").Trim().ToUpper()
}
while ([string]::IsNullOrWhiteSpace($CRNo))

$LogFolder = "C:\Temp"

if (!(Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder | Out-Null
}

$ScriptStart = Get-Date

###############################################################
# SQL Helper Function
###############################################################
function Invoke-DBQuery
{
    param
    (
        [string]$Server,

        [string]$Database,

        [string]$Query
    )

    $SqlParams = @{
        ServerInstance = $Server
        Database       = $Database
        Query          = $Query
        ErrorAction    = 'Stop'
    }

    # Add TrustServerCertificate only if supported by installed SqlServer module
    if ((Get-Command Invoke-Sqlcmd).Parameters.ContainsKey('TrustServerCertificate'))
    {
        $SqlParams['TrustServerCertificate'] = $true
    }

    return Invoke-Sqlcmd @SqlParams
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PHASE 1 : SQL Backup Job Validation" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

$TxtPath = "C:\Temp\SQLCobaltServers.txt"

$Servers = (Import-Csv $TxtPath -Delimiter "`t").ServerName | Sort-Object -Unique

$JobLog = Join-Path $LogFolder ($CRNo + "_JobStatus.log")

"==============================================================" | Out-File $JobLog
"SQL Backup Job Status Report" | Out-File $JobLog -Append
"Change Number : $CRNo" | Out-File $JobLog -Append
"Generated     : $(Get-Date)" | Out-File $JobLog -Append
"==============================================================" | Out-File $JobLog -Append

foreach ($Server in $Servers)
{
    Write-Host ""
    Write-Host "Checking SQL on $Server..." -ForegroundColor Yellow

    Add-Content $JobLog ""
    Add-Content $JobLog "======================================================"
    Add-Content $JobLog "Server : $Server"
    Add-Content $JobLog "======================================================"

    #-----------------------------------
    # Discover SQL Server Instance
    #-----------------------------------

    $SqlInstance = ""

    try
    {
        $SqlService = Get-CimInstance Win32_Service -ComputerName $Server |
            Where-Object {
                $_.Name -eq "MSSQLSERVER" -or
                $_.Name -like "MSSQL$*"
            } |
            Select-Object -First 1

        if (!$SqlService)
        {
            throw "SQL Server service not found on $Server"
        }

        if ($SqlService.Name -eq "MSSQLSERVER")
        {
            $SqlInstance = $Server
        }
        else
        {
            $InstanceName = $SqlService.Name -replace "^MSSQL\$", ""
            $SqlInstance = "$Server\$InstanceName"
        }

        Add-Content $JobLog "SQL Instance : $SqlInstance"
    }
    catch
    {
        Add-Content $JobLog "SQL Instance Discovery Failed : $($_.Exception.Message)"
        Write-Host "SQL Instance discovery FAILED." -ForegroundColor Red
        continue
    }

    try
    {
        $Query = @"
SELECT
    j.name,
    j.enabled,
    CASE h.run_status
        WHEN 0 THEN 'FAILED'
        WHEN 1 THEN 'SUCCESS'
        WHEN 2 THEN 'RETRY'
        WHEN 3 THEN 'CANCELLED'
        WHEN 4 THEN 'RUNNING'
        ELSE 'UNKNOWN'
    END AS LastRunStatus,
    msdb.dbo.agent_datetime(h.run_date,h.run_time) AS LastRunDate
FROM msdb.dbo.sysjobs j
OUTER APPLY
(
    SELECT TOP (1) *
    FROM msdb.dbo.sysjobhistory h
    WHERE h.job_id=j.job_id
    AND step_id=0
    ORDER BY instance_id DESC
) h
WHERE j.name IN
(
'DBAG Backup Database - zzzTOTALzzz',
'DBAG Backup Log - zzzTOTALzzz'
)
ORDER BY j.name
"@

        $Jobs = Invoke-DBQuery `
                    -Server $SqlInstance `
                    -Database "msdb" `
                    -Query $Query

        foreach ($Job in $Jobs)
        {
            Add-Content $JobLog "Job Name        : $($Job.name)"
            Add-Content $JobLog "Enabled         : $($Job.enabled)"
            Add-Content $JobLog "Last Run        : $($Job.LastRunDate)"
            Add-Content $JobLog "Last Outcome    : $($Job.LastRunStatus)"
            Add-Content $JobLog ""
        }

        $DisableQuery = @"
EXEC msdb.dbo.sp_update_job
    @job_name='DBAG Backup Log - zzzTOTALzzz',
    @enabled=0;
"@

        Invoke-DBQuery `
            -Server $SqlInstance `
            -Database "msdb" `
            -Query $DisableQuery

        Add-Content $JobLog "LOG Backup Job Disabled : SUCCESS"

        Write-Host "LOG Backup Job Disabled." -ForegroundColor Green
    }
    catch
    {
        Add-Content $JobLog "ERROR : $($_.Exception.Message)"

        Write-Host "FAILED : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Job status report saved to:"
Write-Host $JobLog -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Green

$Proceed = Read-Host "Proceed with DSM OPT Modification? (Y/N)"

if($Proceed.ToUpper() -ne "Y")
{
    Write-Host "Operation Cancelled." -ForegroundColor Yellow
    return
}

###############################################################
# PHASE 2 - Update Dsm opt files for SQLNodes
###############################################################


#======================== Logging ==========================

$ScriptStart = Get-Date

$LogFile = Join-Path $LogFolder ("DSMUpdate_" + $CRNo + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

#======================== Central Audit Log ==========================
$CentralLog = Join-Path $LogFolder ("CentralAudit_" + $CRNo + "_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

"===========================================================" | Out-File $CentralLog
"IBM Storage Protect OPT File Central Audit" | Out-File $CentralLog -Append
("Change Number : {0}" -f $CRNo) | Out-File $CentralLog -Append
("Execution Host: {0}" -f $env:COMPUTERNAME) | Out-File $CentralLog -Append
("Executed By   : {0}" -f $env:USERNAME) | Out-File $CentralLog -Append
("Start Time    : {0}" -f (Get-Date)) | Out-File $CentralLog -Append
"===========================================================" | Out-File $CentralLog -Append

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts  $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Write-Log "==========================================================="
Write-Log "IBM Storage Protect OPT File Updater"
Write-Log "==========================================================="

<#
IBM Storage Protect OPT File Updater
Version 2.0
#>

$DefaultClientFolder = "C:\Program Files\TSM\baclient"

function Write-Info($m){Write-Host $m -ForegroundColor Cyan}
function Write-Good($m){Write-Host $m -ForegroundColor Green}
function Write-Bad($m){Write-Host $m -ForegroundColor Red}

function Get-BackupName{
    param([string]$OptFile)
    $dir=Split-Path $OptFile
    $base=[IO.Path]::GetFileNameWithoutExtension($OptFile)
    $ext=[IO.Path]::GetExtension($OptFile)

    $candidate = Join-Path $dir ($base + "_Backup_" + $CRNo + $ext + ".txt")
    if(!(Test-Path $candidate)){ return $candidate }

    $i=1
    while($true){
        $candidate = Join-Path $dir ($base + "_Backup_" + $CRNo + "_" + $i + $ext + ".txt")
        if(!(Test-Path $candidate)){ return $candidate }
        $i++
    }
}

function Update-OptFile{
param(
[string]$ClientFolder,
[string]$OptType,
[string]$NewNode,
[string]$NewAddress,
[string]$NewPort
)
$OptType = $OptType.Trim().ToUpper()

if ($OptType -eq "FULL") {
    $OptFile = Get-ChildItem -Path $ClientFolder -Filter "*full*.opt" -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
}
else {
    $OptFile = Get-ChildItem -Path $ClientFolder -Filter "*log*.opt" -File -ErrorAction SilentlyContinue |
               Select-Object -First 1
}

if ($OptFile) {
    $OptFile = $OptFile.FullName
}
else {
    return [PSCustomObject]@{
        Status = "OPT File Not Found"
        File   = ""
        Backup = ""
    }
}


if(!$OptFile){
    return [pscustomobject]@{Status="OPT File Not Found";File="";Backup=""}
}

Write-Log "==========================================================="
Write-Log ("SERVER : {0}" -f $env:COMPUTERNAME)
Write-Log ("TYPE   : {0}" -f $OptType)
$OpStart=Get-Date
Write-Log ("START  : {0}" -f $OpStart)
Write-Log "==========================================================="
Write-Log ""
Write-Log "OPT FILE"
Write-Log "-----------------------------------------------------------"
Write-Log $OptFile
Write-Good "Found : $OptFile"

$content=Get-Content $OptFile

$oldNode=($content|Where-Object{$_ -match '^\s*NODENAME\s+'}) -replace '^\s*NODENAME\s+',''
$oldAddr=($content|Where-Object{$_ -match '^\s*TCPSERVERADDRESS\s+'}) -replace '^\s*TCPSERVERADDRESS\s+',''
$oldPort=($content|Where-Object{$_ -match '^\s*TCPPORT\s+'}) -replace '^\s*TCPPORT\s+',''

Write-Log ""
Write-Log "CURRENT VALUES"
Write-Log "-----------------------------------------------------------"
Write-Log ("NODENAME          : "+$oldNode)
Write-Log ("TCPSERVERADDRESS  : "+$oldAddr)
Write-Log ("TCPPORT           : "+$oldPort)
Write-Host ""
Write-Host "Current Values" -ForegroundColor Yellow
Write-Host " NODENAME         : $oldNode"
Write-Host " TCPSERVERADDRESS : $oldAddr"
Write-Host " TCPPORT          : $oldPort"

Write-Log ""
Write-Log "NEW VALUES"
Write-Log "-----------------------------------------------------------"
Write-Log ("NODENAME          : "+$NewNode)
Write-Log ("TCPSERVERADDRESS  : "+$NewAddress)
Write-Log ("TCPPORT           : "+$NewPort)
Write-Host ""
Write-Host "New Values" -ForegroundColor Yellow
Write-Host " NODENAME         : $NewNode"
Write-Host " TCPSERVERADDRESS : $NewAddress"
Write-Host " TCPPORT          : $NewPort"

$backup=Get-BackupName $OptFile
Copy-Item $OptFile $backup
Write-Log ""
Write-Log "BACKUP"
Write-Log "-----------------------------------------------------------"
Write-Log "Created :"
Write-Log $backup
Write-Good "Backup : $backup"

$newContent = foreach($l in $content){

    if($l -match '^\s*NODENAME\s+'){
        "NODENAME $NewNode"
    }

    elseif($l -match '^\s*TCPSERVERADDRESS\s+'){
        "TCPSERVERADDRESS $NewAddress"
    }

    elseif($l -match '^\s*TCPPORT\s+'){
        "TCPPORT $NewPort"
    }

    # Comment DOMAIN line
    elseif($l -match '^\s*DOMAIN\s+ALL-LOCAL\s+-SYSTEMSTATE'){
        "* DOMAIN ALL-LOCAL -SYSTEMSTATE"
    }

    # Update Schedule Log
    elseif($l -match '^\s*SCHEDLOGNAME\s+'){
        'SCHEDLOGNAME "C:\Program Files\TSM\baclient\dbagschedlog.log"'
    }

    # Update Error Log
    elseif($l -match '^\s*ERRORLOGNAME\s+'){
        'ERRORLOGNAME "C:\Program Files\TSM\baclient\dbagtsmerrorlog.log"'
    }

    else{
        $l
    }
}

$newContent|Set-Content $OptFile

$v=Get-Content $OptFile

$nok=$v -match "^NODENAME\s+$([regex]::Escape($NewNode))$"
$aok=$v -match "^TCPSERVERADDRESS\s+$([regex]::Escape($NewAddress))$"
$pok=$v -match "^TCPPORT\s+$([regex]::Escape($NewPort))$"
$domainOK = $v -match '^\*\s*DOMAIN\s+ALL-LOCAL\s+-SYSTEMSTATE$'
$schedOK = $v -match '^SCHEDLOGNAME\s+"C:\\Program Files\\TSM\\baclient\\dbagschedlog\.log"$'
$errorOK = $v -match '^ERRORLOGNAME\s+"C:\\Program Files\\TSM\\baclient\\dbagtsmerrorlog\.log"$'

if($nok){Write-Good "Verified NODENAME"}else{Write-Bad "NODENAME Failed"}
if($aok){Write-Good "Verified TCPSERVERADDRESS"}else{Write-Bad "TCPSERVERADDRESS Failed"}
if($pok){Write-Good "Verified TCPPORT"}else{Write-Bad "TCPPORT Failed"}
if($domainOK){Write-Good "Verified DOMAIN commented"}else{Write-Bad "DOMAIN update failed"}
if($schedOK){Write-Good "Verified SCHEDLOGNAME"}else{Write-Bad "SCHEDLOGNAME update failed"}
if($errorOK){Write-Good "Verified ERRORLOGNAME"}else{Write-Bad "ERRORLOGNAME update failed"}

Write-Log ""
Write-Log "VALIDATION"
Write-Log "-----------------------------------------------------------"
Write-Log ("NODENAME          : "+($(if($nok){"PASS"}else{"FAIL"})))
Write-Log ("TCPSERVERADDRESS  : "+($(if($aok){"PASS"}else{"FAIL"})))
Write-Log ("TCPPORT           : "+($(if($pok){"PASS"}else{"FAIL"})))
Write-Log ("DOMAIN            : "+($(if($domainOK){"PASS"}else{"FAIL"})))
Write-Log ("SCHEDLOGNAME      : "+($(if($schedOK){"PASS"}else{"FAIL"})))
Write-Log ("ERRORLOGNAME      : "+($(if($errorOK){"PASS"}else{"FAIL"})))
Write-Log ""
Write-Log "STATUS"
Write-Log "-----------------------------------------------------------"
if($nok -and
   $aok -and
   $pok -and
   $domainOK -and
   $schedOK -and
   $errorOK){ Write-Log "SUCCESS" } else { Write-Log "FAILED" }
$OpEnd=Get-Date
$OpDur=New-TimeSpan $OpStart $OpEnd
Write-Log ""
Write-Log ("END TIME : {0}" -f $OpEnd)
Write-Log ("Duration : {0}" -f $OpDur)
if($nok -and $aok -and $pok){
    return [pscustomobject]@{Status="SUCCESS";File=$OptFile;Backup=$backup}
}else{
    Copy-Item $backup $OptFile -Force
    return [pscustomobject]@{Status="FAILED - Rolled Back";File=$OptFile;Backup=$backup}
}
}

Write-Host "IBM Storage Protect OPT File Updater v2.0" -ForegroundColor Cyan

$rows = Import-Csv $TxtPath -Delimiter "`t"
$report=@()

foreach($r in $rows){

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Server : $($r.ServerName)"
Write-Host "Type   : $($r.OptType)"
Write-Host "=================================================" -ForegroundColor Cyan

try{

if($r.ServerName.ToUpper() -eq "LOCAL"){
    $res=Update-OptFile -ClientFolder $DefaultClientFolder `
        -OptType $r.OptType `
        -NewNode $r.NewNodeName `
        -NewAddress $r.NewTCPServerAddress `
        -NewPort $r.NewTCPPort
}
else{

$Functions = @(
@"
function Write-Log {
$(${function:Write-Log}.ToString())
}
"@,
@"
function Write-Good {
$(${function:Write-Good}.ToString())
}
"@,
@"
function Write-Bad {
$(${function:Write-Bad}.ToString())
}
"@,
@"
function Get-BackupName {
$(${function:Get-BackupName}.ToString())
}
"@,
@"
function Update-OptFile {
$(${function:Update-OptFile}.ToString())
}
"@
)

$res = Invoke-Command -ComputerName $r.ServerName `
-ArgumentList $Functions,$DefaultClientFolder,$r.OptType,$r.NewNodeName,$r.NewTCPServerAddress,$r.NewTCPPort,$LogFile,$CRNo `
-ScriptBlock {
param($Functions,$folder,$type,$node,$addr,$port,$RemoteLogFile,$RemoteCRNo)

foreach($f in $Functions){
    Invoke-Expression $f
}

$script:LogFile = $RemoteLogFile
$script:CRNo    = $RemoteCRNo

Update-OptFile -ClientFolder $folder `
               -OptType $type `
               -NewNode $node `
               -NewAddress $addr `
               -NewPort $port
}
}

}catch{
$res=[pscustomobject]@{
Status=$_.Exception.Message
File=""
Backup=""
}
}

$report+=[pscustomobject]@{
Server=$r.ServerName
Type=$r.OptType
Status=$res.Status
File=$res.File
Backup=$res.Backup
}

#======================== Central Audit ==========================
Add-Content $CentralLog ""
Add-Content $CentralLog "==========================================================="
Add-Content $CentralLog ("Server              : {0}" -f $r.ServerName)
Add-Content $CentralLog ("OPT Type            : {0}" -f $r.OptType)
Add-Content $CentralLog ("New Node            : {0}" -f $r.NewNodeName)
Add-Content $CentralLog ("New Server Address  : {0}" -f $r.NewTCPServerAddress)
Add-Content $CentralLog ("New TCP Port        : {0}" -f $r.NewTCPPort)
Add-Content $CentralLog ("Status              : {0}" -f $res.Status)
Add-Content $CentralLog ("OPT File            : {0}" -f $res.File)
Add-Content $CentralLog ("Backup File         : {0}" -f $res.Backup)
Add-Content $CentralLog ("Completed At        : {0}" -f (Get-Date))
Add-Content $CentralLog "==========================================================="

}

Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Yellow
$report|Format-Table -AutoSize
Write-Good "Processing complete. Detailed log: $LogFile"

#======================== Log Summary ==========================
$ScriptEnd = Get-Date
$Duration = New-TimeSpan -Start $ScriptStart -End $ScriptEnd

Write-Log ""
Write-Log "==========================================================="
Write-Log "SUMMARY"
Write-Log "==========================================================="

try{
    $SuccessCount = ($report | Where-Object {$_.Status -like "SUCCESS*"}).Count
    $FailedCount  = ($report | Where-Object {$_.Status -notlike "SUCCESS*"}).Count
    $TotalCount   = $report.Count

    Write-Log ("Servers Processed : {0}" -f $TotalCount)
    Write-Log ("Successful        : {0}" -f $SuccessCount)
    Write-Log ("Failed            : {0}" -f $FailedCount)
}catch{}

Write-Log ("Start Time        : {0}" -f $ScriptStart)
Write-Log ("End Time          : {0}" -f $ScriptEnd)
Write-Log ("Duration          : {0}" -f $Duration)
Write-Log ("Log File          : {0}" -f $LogFile)

#======================== Central Audit Summary ==========================
Add-Content $CentralLog ""
Add-Content $CentralLog "==========================================================="
Add-Content $CentralLog ("Total Servers : {0}" -f $report.Count)
Add-Content $CentralLog ("Successful   : {0}" -f (($report | Where-Object {$_.Status -like "SUCCESS*"}).Count))
Add-Content $CentralLog ("Failed       : {0}" -f (($report | Where-Object {$_.Status -notlike "SUCCESS*"}).Count))
Add-Content $CentralLog ("End Time     : {0}" -f (Get-Date))
Add-Content $CentralLog "==========================================================="

Write-Host ""
Write-Host "Central Audit Log : $CentralLog" -ForegroundColor Green
