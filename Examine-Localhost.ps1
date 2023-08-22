# Server checking script by Petr Pivoda (petr.pivoda@cz.ibm.com)

$RemoteBlock = {

function Get-RamCPUconfig
{

$size = (((Get-WmiObject -Class Win32_PhysicalMemory).capacity |Measure-Object -sum ).sum / 1GB).Tostring()
$cores = (Get-WmiObject -Class Win32_Processor).NumberOfLogicalProcessors
$sockets=$cores.count
"* RAM Size: $size GB `t CPU Cores: " + $cores[0] + "`t CPU sockets: " + $sockets 

} #get-ramcpuconfig
		
Function CheckAllAutoNotRunningSvc
    {      
Get-wmiobject win32_service -Filter 'startmode = "auto" AND state != "running"' | select Name,Displayname,State,ExitCode,PathName | ft -auto
	} #CheckAllAutoNotRunningSvc

Function CheckDiskSpace
{
get-ciminstance Win32_LogicalDisk -filter "drivetype=3" | select Name, VolumeName,@{Name="Free (%)";Expression={"{0,6:P0}" -f(($_.freespace/1gb) / ($_.size/1gb)+0.001)}}, Description, @{Label="Size";Expression={"{0:n0} MB" -f ($_.Size/1mb)}}, @{Label="Free Space";Expression={"{0:n0} MB" -f ($_.FreeSpace/1mb)}} | FT -auto # out-gridview -Title "Disk Space Scan Results"
}

Function CheckCPUload
{
$comptype = $env:computername + " is "+(gwmi win32_operatingsystem).caption + " @ " + (gwmi Win32_ComputerSystem).model 

[string]$load ="* "+$comptype+" | CPU load: "+ (Get-WmiObject -class win32_processor | Measure-Object -property LoadPercentage -Average | select -expandproperty average).ToString() + " %"
$load
}
Function CheckUpTime
{
$os = gwmi win32_operatingsystem


        $timeZone=Get-WmiObject -Class win32_timezone 
        $localTime = Get-WmiObject -Class win32_localtime 


$servertime = "* Local time: " + (Get-Date -Day $localTime.Day -Month $localTime.Month).ToString() + " | " + ($timezone.caption).Tostring() + ""
$serverIP = "* Primary IP address: " + ((Gwmi Win32_NetworkAdapterConfiguration | where {$_.DefaultIPGateway -ne $null}).IPAddress | select -first 1)
$BootTime = $OS.ConvertToDateTime($OS.LastBootUpTime)  
$Uptime = ($OS.ConvertToDateTime($OS.LocalDateTime) - $boottime).ToString() 
$lastboot = "* Last reboot: " + ($boottime).Tostring() + " local time | Uptime: " + $UpTime 
$lastboot


$servertime
$serverip

}


function Get-PageFileMemory 
{

$pf = get-wmiobject -class "Win32_PageFileUsage" -namespace "root\CIMV2" # nactu si detaily o pagefile
$pfused = ($pf[0].currentusage / (($pf[0].allocatedbasesize / 100)+0.01)).ToString("00.00")  # vypocitam procenta

$pf | Add-Member -type NoteProperty -name PFUsedPct -Value $pfused #pridam vlastnost

$memused = Get-WmiObject win32_operatingsystem |
                  Foreach {"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ ($_.TotalVisibleMemorySize + 0.001) )}
				  
$pf | Add-Member -type NoteProperty -name RAMUsedPct -Value $memused #pridam vlastnost

$pf | fl Caption, AllocatedBaseSize, CurrentUsage, PeakUsage, PFUsedPct, RAMUsedPct # zobrazim to co chci videt
}
CheckCPUload
CheckUpTime 
Get-RamCPUconfig
Get-PageFileMemory 
 
"* Local Drives utilizaton: ";CheckDiskSpace
"* Stopped auto-starting Services: ";CheckAllAutoNotRunningSvc
} #end of remote block

$computer = $env:computername
write-host  Checking health of $computer -fore yellow -nonewline
write-host ", please wait . . . " -fore yellow

$datum = (Get-Date).ToString() 

$zdravicko = &$RemoteBlock
write-host
write-host "__________________________________________________________________________" -fore darkgray
write-host -ForegroundColor Green "$computer - System Health Report dated $datum "
$zdravicko
 "__________________________________________________________________________"

# $zdravicko | out-file c:\ibm\LastHealthCheck.txt -Force