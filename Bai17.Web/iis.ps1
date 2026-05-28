############################# 1. Install IIS #############################
Install-WindowsFeature Web-Server -IncludeManagementTools

#Check IIS status
Get-WindowsFeature Web-Server

############################# 2. Import IIS Module ##############################

Import-Module WebAdministration

#Check module
Get-Module WebAdministration

############################# 3. Check IIS service status ###############################
Get-Service W3SVC

#Start / Stop / Restart IIS service:
Start-Service W3SVC
Stop-Service W3SVC
Restart-Service W3SVC

#Restart full IIS:
iisreset

############################# 4. Website Management ##############################

#List all websites
Get-Website

#Start / Stop website
Start-Website -Name "Default Web Site"
Stop-Website -Name "Default Web Site"
Restart-Website -Name "Default Web Site"

#Create source folder for new website
New-Item -Path "C:\inetpub\vti-demo" -ItemType Directory

#Create a sample index.html file
New-Item -Path "C:\inetpub\vti-demo\index.html" -ItemType File -Value "<html><body><h1>Welcome to vti-demo website</h1></body></html>"  -Force  


#Create new website
New-Website `
  -Name "vti-demo" `
  -Port 80 `
  -PhysicalPath "C:\inetpub\vti-demo" `
  -HostHeader "vti-demo.vti.demo"

#Remove website
Remove-Website -Name "vti-demo"

################## Application Pool Management ##############################

#List all application pools
Get-WebAppPoolState
Get-IISAppPool
Get-ChildItem IIS:\AppPools

#Create app pool
New-WebAppPool -Name "vti-demo-app-pool"

#Start / Stop app pool
Start-WebAppPool -Name "vti-demo-app-pool"
Stop-WebAppPool -Name "vti-demo-app-pool"
Restart-WebAppPool -Name "vti-demo-app-pool"

#Set .NET CLR version for app pool
Set-ItemProperty IIS:\AppPools\vti-demo-app-pool -Name "managedRuntimeVersion" -Value "v4.0"

#Set app pool identity
Set-ItemProperty IIS:\AppPools\vti-demo-app-pool -Name "processModel.identityType" -Value "NetworkService"


################## Binding Management ##############################

#Show bindings for a website
Get-WebBinding -Name "Default Web Site"

#Add https binding to website
New-WebBinding -Name "Default Web Site" -Protocol https -Port 443 -HostHeader "vti-demo.vti.demo"

#Remove https binding from website
Remove-WebBinding -Name "Default Web Site" -Protocol https -Port 443 -HostHeader "vti-demo.vti.demo"

##################### Virtual Directory Management ##############################
#Create virtual directory
New-WebVirtualDirectory -Site "Default Web Site" -Name "vti-virtual" -PhysicalPath "C:\inetpub\vti-demo"
#Remove virtual directory
Remove-WebVirtualDirectory -Site "Default Web Site" -Name "vti-virtual"

##################### Logging Management ##############################
#Show current logging settings
Get-WebConfigurationProperty -Filter "system.WebServer/logging" -Name "*"

#View latest logs
Get-ChildItem -Path "C:\inetpub\logs\LogFiles\W3SVC1" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

Get-ChildItem C:\inetpub\logs\LogFiles -Recurse |
Sort-Object LastWriteTime -Descending |
Select-Object -First 10


######################### Common Troubleshooting Commands ##############################

#Test port 80
Test-NetConnection -ComputerName localhost -Port 80

#Check website path permissions
Get-Acl -Path "C:\inetpub\vti-demo" | Format-List
Get-Website | Select-Object Name, State, PhysicalPath

#Check app pool status
Get-WebAppPoolState -Name "vti-demo-app-pool"

#Check IIS listening ports
Get-NetTCPConnection -LocalPort 80,443
netstat -ano | findstr ":80"
netstat -ano | findstr ":443"


