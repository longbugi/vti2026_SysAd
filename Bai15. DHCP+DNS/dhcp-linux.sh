#!/bin/bash

#DHCP and DNS server ip: 172.16.128.2

#Step1. Install DHCP server
sudo apt update && sudo apt install isc-dhcp-server -y

#Check IP interface
ip a

#Step2. Configure DHCP server

#DHCP server will listen on ens256 interface
#sudo vim /etc/default/isc-dhcp-server
#INTERFACESv4="ens256"

sudo sed -i 's/INTERFACESv4=""/INTERFACESv4="ens256"/g' /etc/default/isc-dhcp-server

#DHCP Scope configuration
#sudo vim /etc/dhcp/dhcpd.conf


#authoritative;

#subnet 172.16.128.0 netmask 255.255.255.0 {

 #range 172.16.128.100 172.16.128.200;
 #option routers 172.16.128.1;
 #option domain-name-servers 172.16.128.2;
 #option domain-name "company.local";
 #default-lease-time 600;
 #max-lease-time 7200;

#}


sudo tee -a /etc/dhcp/dhcpd.conf > /dev/null << EOF
authoritative;
subnet 172.16.128.0 netmask 255.255.255.0 {

 range 172.16.128.100 172.16.128.200;
 option routers 172.16.128.1;
 option domain-name-servers 172.16.128.2;
 option domain-name "company.local";
 default-lease-time 600;
 max-lease-time 7200;

}
EOF


#Check coonfiguration file
sudo dhcpd -t -cf /etc/dhcp/dhcpd.conf

#Step3. Start DHCP server
sudo systemctl start isc-dhcp-server
sudo systemctl enable isc-dhcp-server   

#Test DHCP server
journalctl -u isc-dhcp-server -f








