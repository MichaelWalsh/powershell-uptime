# Mini PowerShell Uptime Monitor
# 2024-09-08
# Generates up/down time graph for my local network device by
# trying to open a TCP connection on port 80 and see if it succeeds.
# Overwrites report file each time it runs.

param (
    [string]$HostName = "192.168.2.203",
    [int]$Port = 80,
    [string]$OutputFile = "uptime_monitor.html"
)

function Check-Host {
    param (
        [string]$HostName,
        [int]$Port
    )
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connection = $tcp.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connection.AsyncWaitHandle.WaitOne(10000, $false)
        if (!$wait) {
            $tcp.Close()
            return $false
        }
        $tcp.EndConnect($connection)
        $tcp.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Get-RoundedTime {
    param (
        [DateTime]$time
    )
    return $time.AddMinutes(-($time.Minute % 5)).AddSeconds(-$time.Second)
}


function Generate-HTML {
    param (
        [hashtable]$Results
    )
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Uptime Monitor</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .day { margin-bottom: 20px; }
        .bar { height: 20px; display: flex; position: relative; }
        .slot { width: 3px; height: 100%; position: relative; }
        .up { background-color: green; }
        .down { background-color: red; }
        .unknown { background-color: gray; }
        .tooltip-container { 
            position: absolute; 
            bottom: 100%; 
            left: 50%; 
            transform: translateX(-50%);
            pointer-events: none;
        }
        .tooltip { 
            visibility: hidden; 
            background-color: rgba(0,0,0,0.8); 
            color: white; 
            text-align: center; 
            padding: 5px; 
            border-radius: 6px; 
            white-space: nowrap;
            position: absolute;
            z-index: 1;
            bottom: 0;
            left: 50%;
            transform: translateX(-50%) translateY(-5px);
        }
        .slot:hover .tooltip { visibility: visible; }
    </style>
</head>
<body>
    <h1>Uptime Monitor Results</h1>
"@

    $groupedResults = $Results.GetEnumerator() | Group-Object { $_.Key.Substring(0, 10) }
    
    foreach ($group in $groupedResults) {
        $date = $group.Name
        $html += "<div class='day'><h2>$date</h2><div class='bar'>"
        
        $startOfDay = [DateTime]::ParseExact($date, "yyyy-MM-dd", $null)
        for ($i = 0; $i -lt 288; $i++) {
            $slotTime = $startOfDay.AddMinutes($i * 5)
            $key = $slotTime.ToString("yyyy-MM-dd HH:mm:ss")
            
            if ($Results.ContainsKey($key)) {
                $status = if ($Results[$key]) { "up" } else { "down" }
                $tooltip = $key
            }
            else {
                $status = "unknown"
                $tooltip = "No data"
            }
            
            $html += @"
    <div class="slot $status">
        <div class="tooltip-container">
            <span class="tooltip">$tooltip</span>
        </div>
    </div>
"@
        }
        $html += "</div></div>"
    }

    $html += "</body></html>"
    return $html
}

function Main {
    $results = @{}
    while ($true) {
        $currentTime = Get-RoundedTime (Get-Date)
        $key = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
        
        $isUp = Check-Host -HostName $HostName -Port $Port
        $results[$key] = $isUp

        # Print result to console
        $status = if ($isUp) { "UP" } else { "DOWN" }
        Write-Host ("[{0}] Host {1} Port {2} is {3}" -f $key, $HostName, $Port, $status)
        
        $htmlContent = Generate-HTML -Results $results
        Set-Content -Path $OutputFile -Value $htmlContent

        # Wait until the next 5-minute mark
        $nextCheck = $currentTime.AddMinutes(5 - ($currentTime.Minute % 5)).AddSeconds(-$currentTime.Second)
        $sleepSeconds = ($nextCheck - (Get-Date)).TotalSeconds
        if ($sleepSeconds -gt 0) {
            Start-Sleep -Seconds $sleepSeconds
        }
    }
}

Main
