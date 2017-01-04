param ([int]$SelectFirst)
$loop = $true
#$ErrorActionPreference = "SilentlyContinue"
$sortmode = "CPUUsage"
Echo "Querying WMI for data. Please wait a bit..."
do {
If (! $ProcessName) { $ProcessName = '*' }
If (! $SelectFirst) { $SelectFirst = 50 }
if ([console]::KeyAvailable){
        $x = [System.Console]::ReadKey() 
        switch ($x.key){
            D { $sortmode = "DiskIOPS" } 
            C { $sortmode = "CPUUsage" } 
            R { $sortmode = "UsedRAM" } 
            K { 
             $procpid = Read-Host -Prompt 'Enter PID of the process you want to kill:'
             Echo $procpid
             taskkill /f /pid $procpid
             Echo "Process with PID $procpid killed" 
             Continue
             } 
             Q{ 
               Echo "Exiting..."
               cls
              exit } 
        } 
         
    } 

If ($ProcessName -eq '*') {
  $ProcessList = gwmi Win32_PerfFormattedData_PerfProc_Process |
   select IDProcess,
   Name,
   PercentProcessorTime,
   WorkingSet,
   IODataBytesPersec,
   IODataOperationsPersec,
   IOReadBytesPersec,
   IOWriteBytesPersec  |
   where { $_.Name -ne "_Total" -and $_.Name -ne "Idle"}  |
   select -First $SelectFirst
   }

Else{
  $ProcessList = gwmi Win32_PerfFormattedData_PerfProc_Process |
   where {$_.Name -eq $ProcessName} |
   select IDProcess,
   Name,
   PercentProcessorTime,
   WorkingSet,
   IODataBytesPersec,
   IODataOperationsPersec,
   IOReadBytesPersec,
   IOWriteBytesPersec,
   WorkingSet |
   select -First $SelectFirst
}
$TopProcess = @()

ForEach ($Process in $ProcessList) {
  $row = new-object PSObject -Property @{
    PID = $Process.IDProcess
    Name = $Process.Name
    #User = (gwmi Win32_Process | where {$_.ProcessId -eq $Process.IDProcess}).GetOwner().User
    CPUUsage = $Process.PercentProcessorTime
    #DiskMBs = $Process.IODataBytesPersec/1MB
    DiskMBs = [math]::Round($Process.IODataBytesPersec/1MB,2)
    UsedRAM =  [math]::Round($Process.WorkingSet/1MB,2)
    DiskReadsMBs = [math]::Round($Process.IOReadBytesPersec/1MB,2)
    DiskWriteMBs = [math]::Round($Process.IOWriteBytesPersec/1MB,2)
    DiskIOPS = $Process.IODataOperationsPersec
    Description = (Get-Process -Id $Process.IDProcess).Description
	 
  }
 $TopProcess += $row
}
 #$TopProcess += $row


If ($GridView) {
    $b= $TopProcess |
    sort $sortmode -Descending |
    select PID,
    Name,
    #User,
    CPUUsage,
    UsedRAM,
    DiskMBs,
    DiskReadsMBs,
    DiskWriteMBs,
    DiskIOPS,
    Description |
    Out-GridView |
    out-string
  cls
} 
Else {
  $TotalCPUWMI = Get-WmiObject win32_processor | select LoadPercentage
  $TotalCPU = $TotalCPUWMI.LoadPercentage
  $totalproc = Get-Process
  $proccount = $totalproc.Count
  $c = $TopProcess |
     sort $sortmode -Descending |
      select PID,
      Name,
      #User,
      CPUUsage,
      UsedRAM,
      DiskMBs,
      DiskReadsMBs,
      DiskWriteMBs,
      DiskIOPS,
      Description |
      ft -AutoSize | out-string

  $pagefile = Get-WmiObject Win32_PageFileusage | Select-Object AllocatedBaseSize,PeakUsage
  $freememRaw = Get-WmiObject -class "Win32_OperatingSystem" | select-object FreePhysicalMemory
  $freemem = $freememRaw.FreePhysicalMemory / 1024
  $freemem = [math]::Round($freemem,2)
  $pfassigned = $pagefile.AllocatedBaseSize
  $pfused = $pagefile.PeakUsage
  cls
  if($TotalCPU -gt "90"){
      $fore = "Red"
  }
  if($TotalCPU -le "90"){
      $fore = "Yellow"
  }
  if($TotalCPU -le "20"){
      $fore = "Green"
  }
  
  if($freemem -lt "512"){
      $memfore = "Red"
  }
  else{
      $memfore = "Green"
  }
 $swappct = (($pfused/$pfassigned)*100)
 if( $swappct -gt "90"){
     $swapfore = "Red"
 }
 else{
     $swapfore = "Green"
 }
    
Echo " ---------------------------------------------------------------------------------------------------------"
Echo "| WTOP - Windows Top like utility v0.9.1 Created by: Alesandro Slepcevic - Email: alesandro@slepcevic.net |"
Echo " ---------------------------------------------------------------------------------------------------------"
Echo ""
Write-host "Sort by: (D)isk IOPS, (C)PU Usage or (R)am Usage | (K)ill a process | (Q)uit" -fore Green
Write-host "Currently sorting by: $sortmode"
Echo ""
Write-host "Total CPU usage: $TotalCPU% " -background $fore -foreground "black" -nonewline
Write-host " ---- " -nonewline
Write-host "Free system memory: $freemem MB" -background $memfore -foreground "black" -nonewline
Write-host " ---- " -nonewline
Write-host "SWAP Assigned/Used: $pfassigned MB/$pfused MB" -background $swapfore -foreground "black" -nonewline
Write-host " ---- " -nonewline
Write-host "Total running tasks: $proccount" -background "Green" -foreground "black"
Write-host $c -nonewline
}
}
while( $loop=$true)