#!/bin/bash

######################### Step 1: Install Bind9 DNS server on Linux #########################

#Update package lists
sudo apt update
sudo apt upgrade -y

#Install DNS server packages:
sudo apt install bind9 bind9-utils bind9-doc dnsutils -y

#Check if the DNS server is running
sudo systemctl status named
sudo systemctl enable named


########################## Step 2: Configure Firewall for DNS Server ##########################
#Allow DNS traffic through the firewall
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
sudo ufw reload


########################## Step 3: Configure DNS Zones and Records #########################

| File               | Purpose            |
| ------------------ | ------------------ |
| named.conf         | Main config        |
| named.conf.options | Global DNS options |
| named.conf.local   | Custom zones       |
| db.*               | Zone files         |


######################## Step 4: Configure DNS Forwarders ########################
#Edit named.conf.options to add forwarders
sudo vim /etc/bind/named.conf.options

options {
    directory "/var/cache/bind";

    recursion yes;

    forwarders {
        8.8.8.8;
        1.1.1.1;
    };

    dnssec-validation auto;

    listen-on { any; };
    listen-on-v6 { any; };
};

#########################Step 5: Create a Forward Lookup Zone #######################################
sudo vim /etc/bind/named.conf.local

zone "lab.demo" {
    type master;
    file "/etc/bind/db.lab.demo";
};

#########################Step 6: Create Zone File for Forward Lookup Zone #########################
sudo cp /etc/bind/db.local /etc/bind/db.lab.demo

sudo vim /etc/bind/db.lab.demo

$TTL    604800
@       IN      SOA     ns1.lab.demo. admin.lab.demo. (
                        2026052301
                        604800
                        86400
                        2419200
                        604800 )

@       IN      NS      ns1.lab.demo.

ns1     IN      A       192.168.100.10
server  IN      A       192.168.100.10
client  IN      A       192.168.100.20

#########################Step 7: Create Reverse Lookup Zone #########################
sudo vim /etc/bind/named.conf.local

zone "100.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.192.168.100";
};

#########################Step 8: Create Zone File for Reverse Lookup Zone #########################
sudo cp /etc/bind/db.127 /etc/bind/db.192.168.100
sudo vim /etc/bind/db.192.168.100
$TTL    604800
@       IN      SOA     ns1.lab.demo. admin.lab.demo. (
                        2026052301
                        604800
                        86400
                        2419200
                        604800 )        
@       IN      NS      ns1.lab.demo.
10      IN      PTR     ns1.lab.demo.
20      IN      PTR     client.lab.demo.
; ===== DNS Servers =====
ns1     IN      A       192.168.100.10
ns2     IN      A       192.168.100.11

; ===== Hosts =====
server  IN      A       192.168.100.10
client  IN      A       192.168.100.20

; ===== Alias =====
www     IN      CNAME   server.lab.local.

; ===== Mail =====
mail    IN      A       192.168.100.30
@       IN      MX 10   mail.lab.local.

; ===== FTP =====
ftp     IN      CNAME   server.lab.local.

; ===== IPv6 =====
server6 IN      AAAA    2001:db8::10

; ===== TXT =====
@       IN      TXT     "Lab DNS Server"
spf     IN      TXT     "v=spf1 ip4:192.168.100.30 -all"

; ===== SRV =====
_ldap._tcp      IN SRV 0 5 389 dc1.lab.local.
dc1             IN A   192.168.100.40

#########################Step 9: Check DNS Server Configuration and Restart Service #########################
#Check configuration for syntax errors
sudo named-checkconf
sudo named-checkzone lab.demo /etc/bind/db.lab.demo
sudo named-checkzone 100.168.192.in-addr.arpa /etc/bind/db.192.168.100
#Restart DNS server to apply changes
sudo systemctl restart named
sudo systemctl status named
sudo systemctl enable named

sudo ss -tulpn | grep :53

###########################Step 10: Confifgure DNS Client to Use Your DNS Server #########################
sudo nano /etc/netplan/*.yaml

network:
  version: 2
  ethernets:
    ens33:
      dhcp4: no
      addresses:
        - 192.168.100.20/24
      routes:
        - to: default
          via: 192.168.100.1
      nameservers:
        addresses:
          - 192.168.100.10

sudo netplan apply

#Test DNS resolution
nslookup www.lab.demo 172.19.88.101
dig @192.168.26.26 www.lab.demo





######################## Trouvleshooting Tips ########################
#Check DNS server logs for errors
sudo tail -f /var/log/syslog | grep named

#Check dns client status
resolvectl status

#Query DNS server directly
nslookup www.lab.local 172.19.88.101
resolvectl query www.lab.local

dig @192.168.26.26 www.lab.local

#Clear DNS cache on client
sudo resolvectl flush-caches
sudo systemctl restart systemd-resolved


