#!/bin/bash

#Install NFS
sudo apt update && sudo apt install -y nfs-kernel-server 

#Create a NFS share directory:
sudo mkdir -p /mnt/nfs_share
sudo chown nobody:nogroup /mnt/nfs_share
sudo chmod 777 /mnt/nfs_share

#Config nfs export
grep -Fxq "/mnt/nfs_share 172.19.78.0/24(rw,sync,no_subtree_check)" /etc/exports || \
echo "/mnt/nfs_share 172.19.78.0/24(rw,sync,no_subtree_check)" | sudo tee -a /etc/exports
sudo exportfs -ra

#Restart NFS server
sudo exportfs -a
sudo systemctl restart nfs-kernel-server 

#On client - Install nfs-common 
sudo apt update && sudo apt install nfs-common -y

#Create mount directory
sudo mkdir -p /mnt/nfs_client_share

#mount share file
sudo mount 172.19.78.6:/mnt/nfs_share /mnt/nfs_client_share

