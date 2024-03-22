#####################################################
# Get SQL Server Network TCP Connections in OS Level
#####################################################

clear
function Get-SQLServerTCPConnectionsOSLevel
{
    param([string]$servername)

    if (Test-Connection -ComputerName $servername -Quiet -Count 1 -BufferSize 1)
    {
        $SQLServerProcess = Get-Process -ComputerName $servername | Where-Object {$_.ProcessName -in ('smss','SQLAGENT','sqlceip','sqlservr','sqlwriter')} | Select-Object -Unique Id, ProcessName
        $SQLServerProcessIDs = $SQLServerProcess | Select-Object -ExpandProperty Id

        $SQLServerProcessDetails = @()

        foreach ($SQLServerProcessID in $SQLServerProcessIDs)
        {
            $Octet = '(?:0?0?[0-9]|0?[1-9][0-9]|1[0-9]{2}|2[0-5][0-5]|2[0-4][0-9])'
            [regex] $IPv4Regex = "^(?:$Octet\.){3}$Octet$"

            $SB_GetNetTCPConnection = $null
            $SB_GetNetTCPConnection = {param($SQLServerProcessID) Get-NetTCPConnection -OwningProcess "$SQLServerProcessID" -ErrorAction SilentlyContinue}
            $TCPConnectionDetails = Invoke-Command -ComputerName $servername -ScriptBlock $SB_GetNetTCPConnection -ArgumentList $SQLServerProcessID
            $TCPConnectionDetails = $TCPConnectionDetails | Where-Object {$_.LocalAddress -match $IPv4Regex}
            $TCPConnectionDetails = $TCPConnectionDetails | Where-Object {$_.LocalAddress -notin ('127.0.0.1','0.0.0.0')}
            $TCPConnectionDetails = $TCPConnectionDetails | Where-Object {$_.RemoteAddress -notin ('127.0.0.1','0.0.0.0')}

            $SQLServerProcessName = $null
            $SQLServerProcessName = $SQLServerProcess | Where-Object {$_.Id -eq $SQLServerProcessID} | Select-Object -ExpandProperty ProcessName

            foreach ($TCPConnectionDetail in $TCPConnectionDetails)
            {
        
                $TCPLocalAddress = $null
                $TCPLocalAddress = $TCPConnectionDetail.LocalAddress 

                $LocalHostName = $null
                $LocalHostName = Resolve-DnsName "$TCPLocalAddress" -DnsOnly | Select-Object -ExpandProperty NameHost

                $TCPRemoteAddress = $null
                $TCPRemoteAddress = $TCPConnectionDetail.RemoteAddress 

                $RemoteHostName = $null
                $RemoteHostName = Resolve-DnsName "$TCPRemoteAddress" -DnsOnly | Select-Object -ExpandProperty NameHost
        
                $SQLServerProcessDetail = New-Object -TypeName PSObject 
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name ProcessName -Value $SQLServerProcessName
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name OwningProcess -Value $TCPConnectionDetail.OwningProcess
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name LocalAddress -Value $TCPLocalAddress
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name LocalHostName -Value $LocalHostName
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name RemoteAddress -Value $TCPRemoteAddress 
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name RemoteHostName -Value $RemoteHostName
                $SQLServerProcessDetail | Add-Member -MemberType NoteProperty -Name LocalPort -Value $TCPConnectionDetail.LocalPort
                $SQLServerProcessDetails += $SQLServerProcessDetail
            }
        }

        $SQLServerProcessDetails | ft
    }
    else
    {
        Write-Output 'Check server, PowerShell Test-Connection command failed.'
    }
}