#!/bin/bash

#Update ubuntu
sudo apt update && sudo apt upgrade -y 

#Change the hostname
sudo hostnamectl set-hostname mail

#Config hosts
sudo vim /etc/hosts

#Install docker
curl -fsSL https://get.docker.com | sudo sh

#Install docker compose
sudo apt install docker-compose-plugin -y

#Clone the mailcow repository
cd /~

git clone https://github.com/mailcow/mailcow-dockerized

#cd into the mailcow directory
cd mailcow-dockerized

#Generate the configuration
./generate_config.sh

#Enter mail.lab.local
#Create mailcow.conf

#Start the mailcow stack
sudo docker compose up -d

#Web UI
#https://192.168.100.10
#https://mail.lab.local
#Account: admin/moohoo

#Config mailcow
#Configuration → Mail Setup → Domains → Add Domain (lab.local)

#Create mailboxes (Configuration → Mail Setup → Mailboxes → Add Mailbox_)
#Accounts → Add Mailbox (username: [EMAIL_ADDRESS], password: [PASSWORD])

#Test Webmail 
#https://mail.lab.local/SOGo

#Login:
#user1@lab.local

#Send mail LOCAL
#User1 send: user1@lab.local
#to: user2@lab.local
#Check:
#Inbox Sent Items

#Login user2 check inbox
#https://mail.lab.local/SOGo

#Check logs
#docker logs -f postfix-mailcow docker logs -f dovecot-mailcow docker logs -f rspamd-mailcow

#Add DNS record for mail server
#mail A 192.168.100.10
#mx mail.lab.local


################# DNS Server Example ##################
#mail A 192.168.100.10
#mail.company.com      A      113.161.x.x

#company.com          MX 10  mail.company.com

#company.com          TXT    SPF

#dkim._domainkey      TXT    DKIM

#_dmarc               TXT    DMARC

#PTR                  mail.company.com

################################################


###################### Bai tap #####################
#Active Directory Integration
#Mailcow ↔ LDAP ↔ Active Directory
#User AD đăng nhập Mailcow.

###################################################








