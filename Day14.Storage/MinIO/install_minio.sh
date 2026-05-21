#!/bin/bash

#Step1. Create minio user
sudo useradd -r minio-user -s /sbin/nologin

#Step2. Create minio data storage
sudo mkdir -p /mnt/minio-data
sudo chown minio-user:minio-user /mnt/minio-data


#Step3. Install MinIO on amd64 
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
minio --version

#Step3. Install MinIO on arm64 
wget https://dl.min.io/server/minio/release/linux-arm64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
minio --version

#Step4. Create configuration file 
sudo mkdir /etc/minio

#sudo vim /etc/minio/minio.conf
#MINIO_ROOT_USER=admin
#MINIO_ROOT_PASSWORD=Admin@123456
#MINIO_VOLUMES="/mnt/minio-data"
#MINIO_OPTS="--console-address :9001"

sudo tee /etc/minio/minio.conf > /dev/null << EOF
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=Admin@123456
MINIO_VOLUMES="/mnt/minio-data"
MINIO_OPTS="--console-address :9001"
EOF

#Step5. Create systemd service
sudo vim /etc/systemd/system/minio.service

[Unit]
Description=MinIO
Documentation=https://min.io/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=minio-user
Group=minio-user

EnvironmentFile=/etc/minio/minio.conf

ExecStart=/usr/local/bin/minio server $MINIO_VOLUMES $MINIO_OPTS

Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

#Step6. Start service
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio