#!/bin/bash

################### 1.Basic MongoDB operations ########################### 

#Connect to the primary member of the replica set
mongo --host 127.0.0.1 --port 27017

#Choose/Create a database and collection to test the replica set
use labdb
db.createCollection("users")

#View collections in the database
show collections

#Remove collection
db.users.drop()

##################### 2. CRUD command ###########################

##########Insert a document into the collection############
db.users.insertOne({ name: "John Doe", age: 30, email: "test@example.com" })

#Find a document in the collection
db.users.find({ name: "John Doe" })

#Update a document in the collection
db.users.updateOne({ name: "John Doe" }, { $set: { age: 31 } })

#Delete a document from the collection
db.users.deleteOne({ name: "John Doe" })

#Insert multiple documents into the collection
db.users.insertMany([
    { name: "Alice", age: 25, email: "alice@example.com" },
    { name: "Bob", age: 28, email: "bob@example.com" }
])

##########Filter documents in the collection ############

#View all documents in the collection
db.users.find()

#pretty print the documents
db.users.find().pretty()

#fillter documents based on age
db.users.find({ age: { $gt: 26 } })

#Filter documents based on email
db.users.find({ email: { $regex: /example.com$/ } })

#Filter documents based on name
db.users.find({ name: { $in: ["Alice", "Bob"] } })

#########Update documents in the collection ############
db.users.updateMany({ age: { $gt: 26 } }, { $set: { status: "Senior" } })
db.users.updateOne({ name: "Alice" }, { $set: { status: "Junior" } })

##########Delete documents from the collection ############
db.users.deleteMany({ age: { $gt: 26 } })
db.users.deleteOne({ name: "Alice" })

##################### 3. User and Security Management ###########################

#Create a new user with readWrite role on the labdb database
db.createUser({
    user: "labuser",
    pwd: "Test@123",
    roles: [{ role: "readWrite", db: "labdb" }]
})
#Authenticate as the new user
db.auth("labuser", "Test@123")

#View the current users in the database
db.getUsers()

#Change the password for the user
db.updateUser("labuser", { pwd: "NewPass@123" })

#Delete the user from the database
db.dropUser("labuser")

#Create admin user with root role
use admin
db.createUser({
    user: "admin",
    pwd: "Admin@123",
    roles: [{ role: "root", db: "admin" }]
})

#View users
show users

############### 4. Replication and Sharding Operations ###########################

#Check the status of the replica set
rs.status()

#Initialize the replica set (run this command on the primary member)
rs.initiate()

#Add secondary members to the replica set (run this command on the primary member)
rs.add("172.19.78.3:27017")
rs.add("172.19.78.4:27017")

#view configuration of the replica set
rs.conf()

################ 5. Monitoring and performance tuning ############################

#Server status
db.serverStatus()

#Current operations
db.currentOp()

#Kill operation by its opid
db.killOp(opid)

#Database stats
db.stats()

#Collection stats
db.users.stats()

################### 6. Backup and Restore Operations ###########################
#Backup the database using mongodump
mongodump --db labdb --out /path/to/backup
#Restore the database using mongorestore
mongorestore --db labdb /path/to/backup/labdb






