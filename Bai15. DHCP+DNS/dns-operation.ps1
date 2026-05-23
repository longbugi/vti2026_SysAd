
<#

| Server   | Values                    |
| ------------ | -------------------------- |
| DNS Zone     | `lab.demo`                 |
| Reverse Zone | `26.168.192.in-addr.arpa` |
| DNS Server   | `192.168.26.10`           |
| NS Server    | `ns1.lab.demo`             |
| Server       | `server.lab.demo`          |
| Client       | `client.lab.demo`          |

#>
$ZoneName = "lab.demo"
$ReverseZoneName = "26.168.192.in-addr.arpa"


###################Step1: Install DNS server role#############################
Install-WindowsFeature DNS -IncludeManagementTools
Get-WindowsFeature DNS*

#####################Step2: Configure DNS server #############################

Add-DnsServerPrimaryZone `
    -Name $ZoneName `
    -ZoneFile "$ZoneName.dns"

Add-DnsServerPrimaryZone `
    -Name $ReverseZoneName `
    -ZoneFile "$ReverseZoneName.dns"

#verify zones
Get-DnsServerZone

######################Step3: Add DNS records#############################
Add-DnsServerResourceRecordA `
    -ZoneName $ZoneName `
    -Name "ns1" `
    -IPv4Address "192.168.26.10"

Get-DnsServerResourceRecord `
    -ZoneName "lab.demo" `
    -RRType NS

Add-DnsServerResourceRecordA `
    -ZoneName $ZoneName `
    -Name "server" `
    -IPv4Address "192.168.26.9"

#Add PTR record for server
Add-DnsServerResourceRecordPtr `
    -ZoneName $ReverseZoneName `
    -Name "9" `
    -PtrDomainName "server.lab.demo"

#Add cname record for client
Add-DnsServerResourceRecordCName `
    -ZoneName $ZoneName `
    -Name "client" `
    -HostNameAlias "server.lab.demo"

#Add mx record for mail server
Add-DnsServerResourceRecordMX `
    -ZoneName $ZoneName `
    -Name "@" `
    -MailExchange "mail.lab.demo" `
    -Preference 10

#Add txt record for domain verification

Add-DnsServerResourceRecord `
    -ZoneName $ZoneName `
    -TXT `
    -Name "@" `
    -DescriptiveText "This is a TXT record for lab.demo"

######################Step4: View dns records#############################

#View all records in the zone
Get-DnsServerResourceRecord -ZoneName $ZoneName
Get-DnsServerResourceRecord -ZoneName $ReverseZoneName

#View specific record types
Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType A
Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType CNAME
Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType MX
Get-DnsServerResourceRecord -ZoneName $ZoneName -RRType TXT 


###################Step5: Edit dns records#############################
#Edit A record for server
$Old = Get-DnsServerResourceRecord `
    -ZoneName $ZoneName `
    -Name "server" `
    -RRType A

$New = $Old.Clone()

$New.RecordData.IPv4Address = "192.168.26.11"

Set-DnsServerResourceRecord `
    -ZoneName $ZoneName `
    -OldInputObject $Old `
    -NewInputObject $New


#####################Step6: Delete dns records#############################
Remove-DnsServerResourceRecord `
    -ZoneName $ZoneName `
    -Name "@" `
    -RRType txt `
    -Confirm:$false

################### DNS Condition forwarder #############################
Add-DnsServerConditionalForwarderZone `
    -Name "corp.demo" `
    -MasterServers 192.168.200.10

Add-DnsServerConditionalForwarderZone `
    -Name "corp-branch.demo" `
    -MasterServers 192.168.200.20


#View conditional forwarders
Get-DnsServerZone
Get-DnsServerZone | Where-Object {$_.ZoneType -eq "Forwarder"}

#Delete conditional forwarder
Remove-DnsServerZone `
    -Name "corp.demo" `
    -Force
Remove-DnsServerZone `
    -Name "corp-branch.demo" `
    -Force

#################### DNS Forwarding #############################
Set-DnsServerForwarder `
    -IPAddress 8.8.8.8,8.8.4.4

#View forwarders
Get-DnsServerForwarder