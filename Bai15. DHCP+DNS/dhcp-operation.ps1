#Install DHCP server role and configure it to assign IP addresses to clients in the network. Also, install DNS server role and configure it to resolve domain names for the clients.
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Get-WindowsFeature -Name DHCP, DNS
Restart-Service -Name DHCPServer

######################Authorize the DHCP server in Active Directory#######################
$DHCPServerName = "DHCPServer01"
Add-DhcpServerInDC -DnsName $DHCPServerName -IpAddress "172.19.88.101"
Get-DhcpServerInDC

###############################Scope management################################
$ScopeName = "MyDHCPscope"
$StartIP = "172.19.88.2"
$EndIP = "172.19.88.10"
$SubnetMask = "255.255.255.0"
$DefaultGateway = "172.19.88.1"
$DNSServer = "172.20.4.1"

Get-DhcpServerv4Scope
Add-DhcpServerv4Scope `
    -Name $ScopeName `
    -StartRange $StartIP `
    -EndRange $EndIP `
    -SubnetMask $SubnetMask

    #Set scope options
Set-DhcpServerv4Scope `
    -ScopeId "172.19.88.0" `
    -State Active `

#Get scope id
Get-DhcpServerv4Scope -ScopeId "172.19.88.0" | Select-Object -ExpandProperty ScopeID

#Get scope details
Get-DhcpServerv4Scope -ScopeId "172.19.88.0"

#Remove a scope
# 1. Disable scope
Set-DhcpServerv4Scope -ScopeId 172.19.88.0 -State Inactive

# 2. Restart DHCP (clears lock)
Restart-Service dhcpserver

# 3. Remove scope
Remove-DhcpServerv4Scope -ScopeId 172.19.88.0 -Force


###############################DHCP options################################
Set-DhcpServerv4OptionValue `
    -ScopeId "172.19.88.0" `
    -DnsServer $DNSServer `
    -Router $DefaultGateway 
    
Get-DhcpServerv4OptionValue -ScopeId "172.19.88.0"

################################Server options################################
Set-DhcpServerv4OptionValue `
    -OptionId 6 `
    -Value $DNSServer
Get-DhcpServerv4OptionValue -OptionId 6

Set-DhcpServerv4OptionValue `
    -OptionId 3 `
    -Value $DefaultGateway
Get-DhcpServerv4OptionValue -OptionId 3

#Remove server option
Remove-DhcpServerv4OptionValue -OptionId 6
Remove-DhcpServerv4OptionValue -OptionId 3


###############################Reservation################################
$ReservationIP = "172.19.88.9"
$MACAddress = "00-11-22-33-44-55"
Add-DhcpServerv4Reservation `
    -ScopeId "172.19.88.0" `
    -IPAddress $ReservationIP `
    -ClientId $MACAddress `
    -Name "ReservedClient" `
    -Description "Reserved IP for client with MAC 00-11-22-33-44-55"

Get-DhcpServerv4Reservation -ScopeId "172.19.88.0"

#Remove reservation
Remove-DhcpServerv4Reservation `
    -ScopeId "172.19.88.0" `
    -IPAddress $ReservationIP `
    -ClientId $MACAddress `
    -Confirm:$false

#Convert existing lease to reservation
$Leases = Get-DhcpServerv4Lease `
    -ScopeId "172.19.88.0"
foreach ($Lease in $Leases) {
    if ($Lease.ClientId -eq $MACAddress) {
        Add-DhcpServerv4Reservation `
            -ScopeId "172.19.88.0" `
            -IPAddress $Lease.IPAddress `
            -ClientId $Lease.ClientId `
            -Name "ReservedClient" `
            -Description "Reserved IP for client with MAC 00-11-22-33-44-55"
    }
}

########################Exclusion Range########################
$ExclusionStartIP = "172.19.88.100"
$ExclusionEndIP = "172.19.88.110"
Add-DhcpServerv4ExclusionRange `
    -ScopeId "172.19.88.0" `
    -StartRange $ExclusionStartIP `
    -EndRange $ExclusionEndIP

#####################Statistics and monitoring#####################
Get-DhcpServerv4Lease -ScopeId "172.19.88.0"
Get-DhcpServerv4ScopeStatistics -ScopeId "172.19.88.0"

#######################Policies and filters#######################
$PolicyName = "BlockSpecificMAC"
$MACAddressToBlock = "00-11-22-33-44-55"
$PolicyName = "BlockSpecificMAC"

$PolicyName = "BlockSpecificMAC"

#Enable filtering
Set-DhcpServerv4FilterList -Deny $true

#Add MAC to Deny List
Add-DhcpServerv4Filter `
-List Deny `
-MacAddress "00-11-22-33-44-55" `
-Description "Blocked client"

#Get Deny List
Get-DhcpServerv4Filter -List Deny

#remove MAC from Deny List
Remove-DhcpServerv4Filter `
-MacAddress "00-11-22-33-44-55"



#####################Export and import DHCP configuration#####################
Export-DhcpServer `
    -ComputerName "localhost" `
    -File "C:\DHCPConfig.xml" `
    -Verbose

Import-DhcpServer `
    -ComputerName "localhost" `
    -File "C:\DHCPConfig.xml" `
    -BackupPath "C:\DHCPBackup" `
    -Verbose

