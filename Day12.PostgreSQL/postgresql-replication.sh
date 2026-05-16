#!/bin/bash

# PostgreSQL Replication Setup Script
#Install PostgreSQL on both primary and replica servers
sudo apt update
sudo apt install postgresql postgresql-contrib -y

####################### Configure the primary server #######################
# Edit the PostgreSQL configuration file
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_level = replica/wal_level = replica/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#max_wal_senders = 10/max_wal_senders = 10/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#hot_standby = on/hot_standby = on/g" /etc/postgresql/16/main/postgresql.conf
sudo sed -i "s/#wal_keep_size = 0/wal_keep_size = 512/g" /etc/postgresql/16/main/postgresql.conf    

# Allow replication connections from the replica server
echo "host    replication     all             192.168.26.4/32            md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf 
echo "host    replication     all             192.168.26.5/32            md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf 
# Restart PostgreSQL service on the primary server
sudo systemctl restart postgresql   

# Create a replication user on the primary server
sudo -u postgres psql -c "CREATE ROLE replication_user WITH REPLICATION PASSWORD 'Test@123' LOGIN;"


################### Set up replication on the replica server ###################

# Stop the PostgreSQL service on the replica server
sudo systemctl stop postgresql

#Create cluster on replica server
#sudo pg_createcluster 16 main --start-conf=auto

# Remove existing data directory on the replica server
#sudo rm -rf /var/lib/postgresql/16/main/*
#sudo pg_dropcluster --stop 16 main
#sudo mkdir -p /var/lib/postgresql/16/main

sudo chown -R root:root /var/lib/postgresql/16/main
sudo rm -rf /var/lib/postgresql/16/main/*
sudo chown -R postgres:postgres /var/lib/postgresql/16/main


# Use pg_basebackup to copy data from the primary server to the replica server
sudo -u postgres pg_basebackup -h 192.168.26.3 -D /var/lib/postgresql/16/main -U replication_user -v -P --wal-method=stream -R

sudo systemctl start postgresql 
# Check replication status on the replica server
sudo -u postgres psql -c "SELECT * FROM pg_stat_replication;"



# Create a recovery configuration file on the replica server
#echo "standby_mode = 'on'" | sudo tee /var/lib/postgresql/16/main/recovery.conf
#echo "primary_conninfo = 'host=192.168.26.3 port=5432 user=replication_user password=Test@123'" | sudo tee -a /var/lib/postgresql/16/main/recovery.conf
# Start the PostgreSQL service on the replica server

#######################Test replication #############################
#Insert data into the primary server (master) and check if it appears on the replica server (standby)

sudo -u postgres psql -c "create database labdb;"

sudo -u postgres psql -d labdb -c "
CREATE TABLE IF NOT EXISTS test_replication (
    id SERIAL PRIMARY KEY,
    message TEXT,
    created_at TIMESTAMP DEFAULT now()
);
INSERT INTO test_replication(message) VALUES ('Hello from master');
SELECT * FROM test_replication;
"

# Check if the data is replicated to the replica server
sudo -u postgres psql -d labdb -c "SELECT * FROM test_replication;"

##################### Allow remote access to PostgreSQL #####################

# Edit the PostgreSQL configuration file to allow remote connections
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
# Allow remote connections from any IP address (for testing purposes)
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf    
# Restart PostgreSQL service to apply changes
sudo systemctl restart postgresql

#Verify port 5432 is open and listening for connections
sudo netstat -tuln | grep 5432

#create user with remote access
#sudo -u postgres psql -c "CREATE ROLE remote_user WITH LOGIN PASSWORD 'Remote@123';"
#echo "host    all             remote_user             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
# Restart PostgreSQL service to apply changes
#sudo systemctl restart postgresql

#Create user for DBeaver and grant necessary privileges

sudo -u postgres psql

CREATE USER dbeaver_user WITH PASSWORD 'Test@123';
GRANT ALL PRIVILEGES ON DATABASE labdb TO dbeaver_user;
\c labdb
GRANT ALL ON SCHEMA public TO dbeaver_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO dbeaver_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO dbeaver_user;


#From client machine, test connectivity to PostgreSQL server
nc -zv 192.168.26.3 5432





