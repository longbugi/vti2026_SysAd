=======================================================================
🌲 Hạ Tầng Active Directory Domain Services (AD DS) & High Availability (HA)
=======================================================================

-----------------------------------------------------------------------
📖 1. Mô Hình Kiến Trúc Hệ Thống (Architecture Design)
-----------------------------------------------------------------------
Bài lab này triển khai hạ tầng mạng Active Directory Domain Services (AD DS) doanh nghiệp chuẩn hóa với cơ chế dự phòng High Availability (HA) chống lỗi điểm đơn lẻ (Single Point of Failure).

### 🌐 Sơ Đồ Thiết Kế Hệ Thống Mạng
                    ┌──────────────────────────────────────────────┐
                    │            Lớp Mạng: 192.168.100.0/24         │
                    └──────────────────────┬───────────────────────┘
                                           │
             ┌─────────────────────────────┼─────────────────────────────┐
             │                             │                             │
┌────────────┴────────────┐   ┌────────────┴────────────┐   ┌────────────┴────────────┐
│   Primary DC (DC01)     │   │   Additional DC (DC02)  │   │   Windows Client        │
│   Hostname: LAB-SERVER  │   │   Hostname: LAB-DC02    │   │   Hostname: LAB-CLIENT01│
│   IP: 192.168.100.101   │   │   IP: 192.168.100.102   │   │   IP: Nhận tự động      │
│   Roles: AD, DNS, DHCP  │   │   Roles: ADC, DNS, GC   │   │   DNS: Nhận từ DHCP     │
└─────────────────────────┘   └─────────────────────────┘   └─────────────────────────┘

### 📊 Bảng Phân Hoạch Thông Số Kỹ Thuật
- PDC (Domain Controller 1):
  + Hostname: LAB-SERVER
  + IP tĩnh: 192.168.100.101
  + Preferred DNS: 127.0.0.1
  + Alternate DNS: 192.168.100.102
  + Gateway: 192.168.100.1
  + Dịch vụ chính: AD DS, DNS, DHCP (Authorized)

- ADC (Domain Controller 2):
  + Hostname: LAB-DC02
  + IP tĩnh: 192.168.100.102
  + Preferred DNS: 192.168.100.101
  + Alternate DNS: 127.0.0.1
  + Gateway: 192.168.100.1
  + Dịch vụ chính: Additional DC, DNS, GC

- Client:
  + Hostname: LAB-CLIENT01
  + IP & DNS: Nhận tự động từ DHCP

-----------------------------------------------------------------------
🛠️ 2. Kịch Bản 1: Triển Khai Primary Domain Controller (DC01)
-----------------------------------------------------------------------
LƯU Ý: Thực thi kịch bản bằng quyền Administrator trên máy chủ chính (LAB-SERVER).

```powershell
# BƯỚC 1.1: Tự động cấu hình IP tĩnh và Đổi tên máy chủ
$Interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
$InterfaceAlias = $Interface.Name

Write-Host "Cấu hình IP tĩnh cho card mạng: $InterfaceAlias..." -ForegroundColor Green
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress "192.168.100.101" -PrefixLength 24 -DefaultGateway "192.168.100.1" -Force
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "127.0.0.1"

Write-Host "Đổi tên máy chủ thành LAB-SERVER và khởi động lại..." -ForegroundColor Yellow
Rename-Computer -NewName "LAB-SERVER" -Force -Restart

# BƯỚC 1.2: (Sau khi Reboot) Cài đặt AD DS & Thăng cấp lên Forest Root DC
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$DsrmPassword = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
$Password = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
Set-LocalUser -Name "Administrator" -Password $Password

Install-ADDSForest `
    -DomainName "lab.local" `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysVolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $DsrmPassword `
    -Force:$true

# BƯỚC 1.3: Ủy quyền DHCP trong AD DS (Chạy sau khi đã thăng cấp thành công)
Add-DhcpServerInDC -DnsName "LAB-SERVER.lab.local" -IPAddress "192.168.100.101"
```

-----------------------------------------------------------------------
🤝 3. Kịch Bản 2: Triển Khai Additional Domain Controller (DC02)
-----------------------------------------------------------------------
LƯU Ý: Thực thi bằng quyền Administrator trên máy chủ thứ hai (LAB-DC02).

```powershell
# BƯỚC 2.1: Cấu hình Mạng trỏ Preferred DNS về DC01 để nhận diện miền
$Interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
$InterfaceAlias = $Interface.Name

Write-Host "Cấu hình IP tĩnh cho DC02, trỏ Preferred DNS về DC01 (192.168.100.101)..." -ForegroundColor Green
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress "192.168.100.102" -PrefixLength 24 -DefaultGateway "192.168.100.1" -Force
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "192.168.100.101", "127.0.0.1"

Write-Host "Đổi tên máy chủ thành LAB-DC02..." -ForegroundColor Yellow
Rename-Computer -NewName "LAB-DC02" -Force -Restart

# BƯỚC 2.2: (Sau khi Reboot) Cài đặt và Thăng cấp làm Additional DC
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

$Credential = Get-Credential -UserName "LAB\Administrator" -Message "Nhập mật khẩu tài khoản Administrator của miền lab.local"
$DsrmPassword = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force

Install-ADDSDomainController `
    -NoGlobalCatalog:$false `
    -CreateDnsDelegation:$false `
    -Credential $Credential `
    -DomainName "lab.local" `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysVolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $DsrmPassword `
    -Force:$true
```

-----------------------------------------------------------------------
🏢 4. Kịch Bản 3: Tự Động Hóa Quản Trị Đối Tượng (OU, Group & User)
-----------------------------------------------------------------------
Đăng nhập vào Domain Controller bằng tài khoản LAB\Administrator, mở PowerShell (Admin) và chạy:

```powershell
Import-Module ActiveDirectory

# 1. Khởi tạo một Đơn vị tổ chức (OU) mới mang tên 'Phong-Nhan-Su'
New-ADOrganizationalUnit -Name "Phong-Nhan-Su" -Path "DC=lab,DC=local"

# 2. Khởi tạo tài khoản Người dùng (User) mới nằm trong OU vừa tạo
$UserPassword = ConvertTo-SecureString "UserP@ss123!" -AsPlainText -Force
New-ADUser -Name "Nguyễn Văn A" `
           -SamAccountName "anv" `
           -UserPrincipalName "anv@lab.local" `
           -Path "OU=Phong-Nhan-Su,DC=lab,DC=local" `
           -AccountPassword $UserPassword `
           -ChangePasswordAtLogon $false `
           -Enabled $true

# 3. Khởi tạo Nhóm bảo mật (Security Group) mang tên 'G_NHAN_SU' trong OU
New-ADGroup -Name "G_NHAN_SU" `
            -GroupScope Global `
            -GroupCategory Security `
            -Path "OU=Phong-Nhan-Su,DC=lab,DC=local"

# 4. Thực hiện thêm thành viên (User) 'anv' vào bên trong Nhóm 'G_NHAN_SU'
Add-ADGroupMember -Identity "G_NHAN_SU" -Members "anv"

# Xác minh cấu trúc đã tạo
Get-ADOU -Identity "OU=Phong-Nhan-Su,DC=lab,DC=local"
Get-ADGroup -Identity "G_NHAN_SU" -Properties Members
```

-----------------------------------------------------------------------
💻 5. Kịch Bản 4: Gia Nhập Miền Cho Máy Trạm (Windows Client)
-----------------------------------------------------------------------
Mở PowerShell (Admin) trên máy Client và chạy:

```powershell
# 1. Ép buộc card mạng làm mới dữ liệu để nhận DNS mới nhất từ DHCP
ipconfig /release
ipconfig /renew

# Xác minh phân giải DNS đối với tên miền lab.local
Resolve-DnsName lab.local

# 2. Khai báo tài khoản quản trị miền có quyền Join Domain
$Credential = Get-Credential -UserName "LAB\Administrator" -Message "Nhập mật khẩu Admin của Domain lab.local"

# 3. Thực thi lệnh Join Domain và khởi động lại ngay lập tức
Add-Computer -DomainName "lab.local" -Credential $Credential -Restart -Force

# Lệnh kiểm tra trạng thái Join Domain thành công sau khi reboot:
[System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
```

-----------------------------------------------------------------------
🛡️ 6. Kịch Bản 5: Thiết Lập Sao Lưu & Phục Hồi Thảm Họa (Disaster Recovery)
-----------------------------------------------------------------------
### Bước 5.1: Cấu hình và Chạy Sao Lưu Trạng Thế Hệ Thống (System State Backup)
LƯU Ý: Phải sử dụng phân vùng lưu trữ riêng biệt (ví dụ ổ E:\).

```powershell
# 1. Cài đặt tính năng Windows Server Backup
Install-WindowsFeature -Name Windows-Server-Backup

# 2. Thiết lập chính sách sao lưu System State lưu về ổ E:
$Policy = New-WBPolicy
Add-WBSystemState -Policy $Policy
$BackupTarget = New-WBBackupTarget -VolumePath "E:"
Add-WBBackupTarget -Policy $Policy -Target $BackupTarget

# 3. Bắt đầu tiến trình chạy sao lưu ngay lập tức
Start-WBBackup -Policy $Policy
```

### Bước 5.2: Khôi Phục Hệ Thống Khi Gặp Thảm Họa (Restore AD DS)
LƯU Ý: Bắt buộc khởi động máy chủ vào chế độ Directory Services Repair Mode (DSRM).

1. Khởi động cưỡng bức máy chủ vào chế độ DSRM bằng PowerShell:
   bcdedit /set safeboot dsrm
   Restart-Computer -Force

2. Đăng nhập DSRM: Sử dụng tài khoản cục bộ .\Administrator và mật khẩu DSRM (ví dụ: P@ssword123!).

3. Tìm bản sao lưu: Mở PowerShell và chạy:
   wbadmin get versions
   (Lấy mã nhận dạng Version Identifier, ví dụ: 05/30/2026-10:00)

4. Chạy lệnh phục hồi System State:
   wbadmin start systemstaterestore -version:05/30/2026-10:00 -backupTarget:E: -quiet

5. Đưa máy chủ hoạt động bình thường trở lại:
   bcdedit /deletevalue safeboot
   Restart-Computer -Force

-----------------------------------------------------------------------
🎯 7. Best Practices Dành Cho SysAdmin Quản Trị AD DS
-----------------------------------------------------------------------
- Luôn triển khai ít nhất 2 Domain Controllers để tránh lỗi điểm đơn lẻ.
- Sử dụng DHCP Integration & Authorization để quản trị DHCP an toàn.
- Cấu hình Preferred DNS trỏ chéo giữa các DC để đồng bộ dữ liệu hoàn hảo.
- Định kỳ kiểm thử sao lưu và khôi phục System State (tối thiểu 6 tháng 1 lần).
