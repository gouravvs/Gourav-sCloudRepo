<#
BAAS Telnet Validation Script
Author : gourav.binodkumardas@dxc.com
#Version 2.0
Purpose:
  - Reads servers from CSV
  - Selects target IP/Port list based on Region + DC + Classification
  - Performs remote Test-NetConnection
  - Exports CSV report

Input CSV Columns:
ServerName,Region,DC,Classification
#>

#==========================
# CONFIGURATION
#==========================

$InputFile  = "C:\Temp\SQLCobaltServers.txt"
$OutputFile = "C:\Temp\BAAS_Telnet_Report.csv"

#-------------------------------------------------
# Maintain ONLY this section when IPs change
#-------------------------------------------------

$TargetConfig = @{

    "SINGAPORE_DSJ_PROD" = @(
        @{IP="10.208.6.13";Port=1570}
        @{IP="10.208.6.14";Port=1570}
        @{IP="10.208.6.15";Port=1570}
        @{IP="10.208.6.16";Port=1570}
        @{IP="10.208.6.17";Port=1570}
    )

    "SINGAPORE_DSJ_DEV" = @(
        @{IP="10.200.160.25";Port=1570}
        @{IP="10.200.160.26";Port=1570}
        @{IP="10.200.160.27";Port=1570}
        @{IP="10.200.160.28";Port=1570}
        @{IP="10.200.160.29";Port=1570}
    )

    "SINGAPORE_DSJ_UAT" = @(
        @{IP="10.202.100.85";Port=1570}
        @{IP="10.202.100.86";Port=1570}
        @{IP="10.202.100.87";Port=1570}
        @{IP="10.202.100.88";Port=1570}
        @{IP="10.202.100.89";Port=1570}
    )

    "SINGAPORE_KDC_PROD" = @(
        @{IP="10.239.132.15";Port=1550}
        @{IP="10.239.132.16";Port=1550}
        @{IP="10.239.132.17";Port=1550}
        @{IP="10.239.132.18";Port=1550}
        @{IP="10.239.132.25";Port=1550}
    )
    "SINGAPORE_KDC_DEV"  = @(
        @{IP="10.200.160.32";Port=1570}
        @{IP="10.200.160.33";Port=1570}
        @{IP="10.200.160.34";Port=1570}
    )
    "SINGAPORE_KDC_UAT"  = @(
        @{IP="10.202.100.90";Port=1570}
        @{IP="10.202.100.91";Port=1570}
        @{IP="10.202.100.92";Port=1570}
    )

    "SINGAPORE_9TS_PROD" = @()
    "SINGAPORE_9TS_DEV"  = @(
        @{IP="10.245.208.15";Port=1550}
        @{IP="10.245.208.16";Port=1550}
    )
    "SINGAPORE_9TS_UAT"  = @(
        @{IP="10.245.179.21";Port=1550}
        @{IP="10.245.179.22";Port=1550}
    )

    "GERMANY_DCB_PROD" = @(
        @{IP="10.216.11.13";Port=1570}
        @{IP="10.216.11.14";Port=1570}
        @{IP="10.216.11.15";Port=1570}
        @{IP="10.216.11.16";Port=1570}
        @{IP="10.216.11.33";Port=1570}
        @{IP="10.216.11.34";Port=1570}
        @{IP="10.216.11.35";Port=1570}
        @{IP="10.216.11.36";Port=1570}
    )
    "GERMANY_DCB_DEV"  = @(
        @{IP="10.198.1.15";Port=1570}
        @{IP="10.198.1.16";Port=1570}
        @{IP="10.198.1.17";Port=1570}
        @{IP="10.198.1.18";Port=1570}
        @{IP="10.198.1.19";Port=1570}
        @{IP="10.198.1.20";Port=1570}
        @{IP="10.198.1.21";Port=1570}
        @{IP="10.198.1.22";Port=1570}
        @{IP="10.198.1.28";Port=1570}
        @{IP="10.198.1.29";Port=1570}
        @{IP="10.198.1.30";Port=1570}
        @{IP="10.198.1.31";Port=1570}
    )
    "GERMANY_DCB_UAT"  = @(
        @{IP="10.198.192.32";Port=1570}
        @{IP="10.198.192.33";Port=1570}
        @{IP="10.198.192.34";Port=1570}
        @{IP="10.198.192.35";Port=1570}
        #@{IP="10.198.192.36";Port=1570}
        @{IP="10.198.192.37";Port=1570}
        @{IP="10.198.192.38";Port=1570}
        @{IP="10.198.192.39";Port=1570}
        @{IP="10.202.72.81";Port=1570}
        @{IP="10.202.72.82";Port=1570}
        @{IP="10.202.72.83";Port=1570}
        @{IP="10.202.72.84";Port=1570}
    )

    "GERMANY_DCN_PROD" = @(
        @{IP="10.217.156.55";Port=1550}
        @{IP="10.217.156.56";Port=1550}
        @{IP="10.217.156.57";Port=1550}
        @{IP="10.217.156.58";Port=1550}
        @{IP="10.217.156.95";Port=1550}
        @{IP="10.217.156.96";Port=1550}
        @{IP="10.217.156.97";Port=1550}
        @{IP="10.217.156.98";Port=1550}
    )
    "GERMANY_DCN_DEV"  = @(
        @{IP="10.245.52.67";Port=1550}
        @{IP="10.245.52.68";Port=1550}
        @{IP="10.245.52.75";Port=1550}
        @{IP="10.245.52.77";Port=1550}
        #@{IP="10.245.52.80";Port=1550}
        @{IP="10.245.52.81";Port=1550}
        @{IP="10.245.52.82";Port=1550}
        @{IP="10.245.52.83";Port=1550}
        @{IP="10.200.56.43";Port=1550}
        @{IP="10.200.56.44";Port=1550}
        @{IP="10.200.56.45";Port=1550}
        @{IP="10.200.56.46";Port=1550}
    )
    "GERMANY_DCN_UAT"  = @(
        @{IP="10.202.68.71";Port=1550}
        @{IP="10.202.68.72";Port=1550}
        @{IP="10.202.68.73";Port=1550}
        @{IP="10.202.68.76";Port=1550}
        @{IP="10.202.68.77";Port=1550}
        @{IP="10.202.68.78";Port=1550}
        @{IP="10.202.68.84";Port=1550}
        @{IP="10.202.68.89";Port=1550}
        @{IP="10.202.72.85";Port=1550}
        @{IP="10.202.72.86";Port=1550}
        @{IP="10.202.72.87";Port=1550}
        @{IP="10.202.72.88";Port=1550}
    )

    "UK_WDC_PROD" = @(
        @{IP="10.232.136.93";Port=1550}
        @{IP="10.232.136.94";Port=1550}
        @{IP="10.232.136.95";Port=1550}
       #@{IP="10.232.136.96";Port=1550}
        @{IP="10.232.136.154";Port=1570}

    )
    "UK_WDC_DEV"  = @(
        @{IP="10.200.128.77";Port=1570}
        @{IP="10.200.128.80";Port=1570}
        @{IP="10.200.128.81";Port=1570}
       #@{IP="10.200.128.82";Port=1570}
        @{IP="10.200.128.25";Port=1570}
    )
    "UK_WDC_UAT"  = @(
        @{IP="10.202.58.82";Port=1570}
        @{IP="10.202.88.112";Port=1570}
        @{IP="10.202.88.113";Port=1570}
        @{IP="10.202.88.114";Port=1570}
        @{IP="10.202.88.44";Port=1570}
    )

    "UK_CDC_PROD" = @(
        @{IP="10.232.136.89";Port=1570}
        @{IP="10.232.136.90";Port=1570}
        @{IP="10.232.136.91";Port=1570}
     #  @{IP="10.232.136.92";Port=1570}
        @{IP="10.232.136.152";Port=1550}
    )
    "UK_CDC_DEV"  = @(
        @{IP="10.200.128.69";Port=1550}
        @{IP="10.200.128.74";Port=1550}
        @{IP="10.200.128.75";Port=1550}
      # @{IP="10.200.128.76";Port=1550}
        @{IP="10.200.128.21";Port=1550}
    )
    "UK_CDC_UAT"  = @(
        @{IP="10.202.58.78";Port=1550}
        @{IP="10.202.58.79";Port=1550}
        @{IP="10.202.58.80";Port=1550}
        @{IP="10.202.58.81";Port=1550}
        @{IP="10.202.56.139";Port=1550}
    )

    "US_2PK_PROD" = @(
        @{IP="10.212.84.88";Port=1550}
        @{IP="10.212.84.89";Port=1550}
        @{IP="10.212.84.90";Port=1550}
    )
    "US_2PK_DEV"  = @(
        @{IP="10.200.80.14";Port=1550}
        @{IP="10.200.80.16";Port=1550}
        @{IP="10.200.80.19";Port=1550}
    )
    "US_2PK_UAT"  = @(
        @{IP="10.202.161.13";Port=1550}
      # @{IP="10.202.161.14";Port=1550}
        @{IP="10.202.161.15";Port=1550}
    )

    "US_NJM_PROD" = @(
        @{IP="10.213.7.13";Port=1570}
        @{IP="10.213.7.14";Port=1570}
        @{IP="10.213.7.15";Port=1570}
    )
    "US_NJM_DEV"  = @(
        @{IP="10.200.80.24";Port=1570}
        @{IP="10.200.80.27";Port=1570}
        @{IP="10.200.80.28";Port=1570}
    )
    "US_NJM_UAT"  = @(
        @{IP="10.202.44.130";Port=1570}
        @{IP="10.202.44.136";Port=1570}
        @{IP="10.202.44.178";Port=1570}
    )
    "US_PIL_PROD"  = @(
        @{IP="10.213.7.13";Port=1570}
        @{IP="10.213.7.14";Port=1570}
        @{IP="10.213.7.15";Port=1570}
        @{IP="10.212.84.88";Port=1550}
        @{IP="10.212.84.89";Port=1550}
        @{IP="10.212.84.90";Port=1550}
    )
    "US_PIL_UAT"  = @(
        @{IP="10.202.44.130";Port=1570}
        @{IP="10.202.44.136";Port=1570}
        @{IP="10.202.44.178";Port=1570}
        @{IP="10.202.161.13";Port=1550}
      # @{IP="10.202.161.14";Port=1550}
        @{IP="10.202.161.15";Port=1550}
    )
        "US_PIL_DEV"  = @(
        @{IP="10.200.80.14";Port=1550}
        @{IP="10.200.80.16";Port=1550}
        @{IP="10.200.80.19";Port=1550}
        @{IP="10.200.80.24";Port=1570}
        @{IP="10.200.80.27";Port=1570}
        @{IP="10.200.80.28";Port=1570}   
    )
}

#==========================
# MAIN
#==========================

$Servers = Import-Csv $InputFile -Delimiter "`t"
# Remove duplicate servers
$Servers = $Servers | Sort-Object ServerName -Unique

$Results = foreach($Server in $Servers)
{
    $Region = $Server.Region.Trim().ToUpper()
    $DC = $Server.DC.Trim().ToUpper()
    $Class = $Server.Classification.Trim().ToUpper()
        # Treat DR same as PROD
        if ($Class -eq "DR")
        {
            $Class = "PROD"
        }

    $Hosts = $Server.ServerName.Trim()

    $Key = "{0}_{1}_{2}" -f $Region,$DC,$Class

    if(-not $TargetConfig.ContainsKey($Key))
    {
        [PSCustomObject]@{
            Hostname=$Hosts
            Region=$Region
            DC=$DC
            Classification=$Class
            TelnetIP=""
            TelnetPort=""
            Status="Configuration Missing"
            Error="No target block found for $Key"
        }
        continue
    }

    $Targets = $TargetConfig[$Key]

    if($Targets.Count -eq 0)
    {
        [PSCustomObject]@{
            Hostname=$Hosts
            Region=$Region
            DC=$DC
            Classification=$Class
            TelnetIP=""
            TelnetPort=""
            Status="No Targets Configured"
            Error=""
        }
        continue
    }

    foreach($Target in $Targets)
    {
        try
        {
            Invoke-Command -ComputerName $Hosts -ArgumentList $Hosts,$Target.IP,$Target.Port,$Region,$DC,$Class -ErrorAction Stop -ScriptBlock {

                param($Hostsname,$IP,$Port,$Region,$DC,$Class)

                $Result = Test-NetConnection -ComputerName $IP -Port $Port -WarningAction SilentlyContinue

                [PSCustomObject]@{
                    Hostname=$Hostsname
                    Region=$Region
                    DC=$DC
                    Classification=$Class
                    TelnetIP=$IP
                    TelnetPort=$Port
                    Status= if($Result.TcpTestSucceeded){"PASS"}else{"FAIL"}
                    Error=""
                }

            }
        }
        catch
        {
            [PSCustomObject]@{
                Hostname=$Hosts
                Region=$Region
                DC=$DC
                Classification=$Class
                TelnetIP=$Target.IP
                TelnetPort=$Target.Port
                Status="Invoke-Command Failed"
                Error=$_.Exception.Message
            }
        }
    }
}

$Results | Export-Csv $OutputFile -NoTypeInformation

Write-Host ""
Write-Host "Completed."
Write-Host "Report : $OutputFile"
