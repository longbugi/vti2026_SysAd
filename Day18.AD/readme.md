# 🌲 Hạ Tầng Active Directory Domain Services (AD DS) & High Availability (HA)

---

## 📖 1. Mô Hình Kiến Trúc Hệ Thống (Architecture Design)
Bài lab này triển khai hạ tầng mạng Active Directory Domain Services (AD DS) doanh nghiệp chuẩn hóa với cơ chế dự phòng High Availability (HA) chống lỗi điểm đơn lẻ (Single Point of Failure).

### 🌐 Sơ Đồ Thiết Kế Hệ Thống Mạng
```md
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
```

### 📊 Bảng Phân Hoạch Thông Số Kỹ Thuật
| Thiết bị | Tên máy (Hostname) | Địa chỉ IP tĩnh | Preferred DNS | Alternate DNS | Gateway | Dịch vụ chính |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Domain Controller 1 (PDC)** | `LAB-SERVER` | `192.168.100.101` | `127.0.0.1` | `192.168.100.102` | `192.168.100.1` | AD DS, DNS, DHCP (Authorized) |
| **Domain Controller 2 (ADC)** | `LAB-DC02` | `192.168.100.102` | `192.168.100.101` | `127.0.0.1` | `192.168.100.1` | Additional DC, DNS, GC |
| **Client Machine** | `LAB-CLIENT01` | *Nhận từ DHCP* | *Nhận từ DHCP* | *Nhận từ DHCP* | *Nhận từ DHCP* | Domain Joined Client |

---

## 🛠️ 2. Kịch Bản 1: Triển Khai Primary Domain Controller (DC01)
> [!IMPORTANT]
> Thực thi kịch bản bằng quyền **Administrator** trên máy chủ chính (`LAB-SERVER`).

Kịch bản này tự động hóa: cấu hình card mạng sang IP tĩnh, đổi tên máy, cài đặt vai trò AD DS, thăng cấp thành rừng miền `lab.local`, và **ủy quyền (Authorize) dịch vụ DHCP trong AD DS** để đảm bảo dịch vụ cấp phát mạng hoạt động sau khi nâng cấp.

```powershell
# =====================================================================
# BƯỚC 1.1: Tự động cấu hình IP tĩnh và Đổi tên máy chủ
# =====================================================================
# Tự động lấy tên Card mạng đang hoạt động (Up) để tránh lỗi cứng cổng mạng
$Interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
$InterfaceAlias = $Interface.Name

Write-Host "Cấu hình IP tĩnh cho card mạng: $InterfaceAlias..." -ForegroundColor Green
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress "192.168.100.101" -PrefixLength 24 -DefaultGateway "192.168.100.1" -Force
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "127.0.0.1"

Write-Host "Đổi tên máy chủ thành LAB-SERVER và khởi động lại..." -ForegroundColor Yellow
Rename-Computer -NewName "LAB-SERVER" -Force -Restart

# =====================================================================
# BƯỚC 1.2: (Sau khi Reboot) Cài đặt AD DS & Thăng cấp lên Forest Root DC
# =====================================================================
# 1. Cài đặt vai trò AD DS và các công cụ quản trị
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# 2. Định nghĩa mật khẩu DSRM (Mật khẩu Safe Mode phục hồi AD)
$DsrmPassword = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force

# 3. Đồng bộ mật khẩu tài khoản Administrator cục bộ thành mật khẩu bảo mật của miền
$Password = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force
Set-LocalUser -Name "Administrator" -Password $Password

# 4. Thăng cấp máy chủ lên Forest Root Domain Controller
Install-ADDSForest `
    -DomainName "lab.local" `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysVolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $DsrmPassword `
    -Force:$true

# =====================================================================
# BƯỚC 1.3: (Chạy sau khi thăng cấp lên DC thành công) Ủy quyền DHCP trong AD DS
# =====================================================================
# Ủy quyền cho phép DHCP Server hoạt động hợp pháp trong môi trường Active Directory
Add-DhcpServerInDC -DnsName "LAB-SERVER.lab.local" -IPAddress "192.168.100.101"
```

---

## 🤝 3. Kịch Bản 2: Triển Khai Additional Domain Controller (DC02)
> [!IMPORTANT]
> Thực thi bằng quyền **Administrator** trên máy chủ thứ hai (`LAB-DC02`). Máy chủ này sẽ hoạt động như một DC dự phòng nóng để chia sẻ tải và phòng ngừa rủi ro.

```powershell
# =====================================================================
# BƯỚC 2.1: Cấu hình Mạng trỏ Preferred DNS về DC01 để nhận diện miền
# =====================================================================
$Interface = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
$InterfaceAlias = $Interface.Name

Write-Host "Cấu hình IP tĩnh cho DC02, trỏ Preferred DNS về DC01 (192.168.100.101)..." -ForegroundColor Green
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress "192.168.100.102" -PrefixLength 24 -DefaultGateway "192.168.100.1" -Force
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses "192.168.100.101", "127.0.0.1"

Write-Host "Đổi tên máy chủ thành LAB-DC02..." -ForegroundColor Yellow
Rename-Computer -NewName "LAB-DC02" -Force -Restart

# =====================================================================
# BƯỚC 2.2: (Sau khi Reboot) Cài đặt và Thăng cấp làm Additional DC
# =====================================================================
# 1. Cài đặt vai trò AD DS
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# 2. Thu thập Credential tài khoản Domain Admin của miền lab.local hiện tại
$Credential = Get-Credential -UserName "LAB\Administrator" -Message "Nhập mật khẩu tài khoản Administrator của miền lab.local"
$DsrmPassword = ConvertTo-SecureString "P@ssword123!" -AsPlainText -Force

# 3. Chạy lệnh Promote thành Additional Domain Controller
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

---

## 🏢 4. Kịch Bản 3: Tự Động Hóa Quản Trị Đối Tượng (OU, Group & User)
Đăng nhập vào Domain Controller (`LAB-SERVER`) bằng tài khoản `LAB\Administrator`, mở PowerShell (Admin) và thực thi script để khởi tạo cấu trúc sơ đồ tổ chức phòng **Nhân Sự**:

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

# =====================================================================
# XÁC MINH CẤU TRÚC ĐÃ TẠO TRÊN HỆ THỐNG
# =====================================================================
Write-Host "`n=== KẾT QUẢ XÁC MINH OU ===" -ForegroundColor Green
Get-ADOU -Identity "OU=Phong-Nhan-Su,DC=lab,DC=local"

Write-Host "`n=== THÀNH VIÊN NHÓM G_NHAN_SU ===" -ForegroundColor Green
Get-ADGroup -Identity "G_NHAN_SU" -Properties Members
```

---

## 💻 5. Kịch Bản 4: Gia Nhập Miền Cho Máy Trạm (Windows Client)
Thực hiện cấu hình trên máy trạm Windows Client để nhận diện DNS của DC và tự động hóa Join Domain:

```powershell
# 1. Ép buộc card mạng làm mới dữ liệu để nhận DNS mới nhất từ DHCP Server (.101/.102)
ipconfig /release
ipconfig /renew

# Xác minh phân giải DNS đối với tên miền lab.local (Bắt buộc phải ra IP .101 hoặc .102)
Resolve-DnsName lab.local

# 2. Khai báo tài khoản quản trị miền có quyền Join Domain (Nhập mật khẩu ở hộp thoại hiển thị)
$Credential = Get-Credential -UserName "LAB\Administrator" -Message "Nhập mật khẩu Admin của Domain lab.local"

# 3. Thực thi lệnh Join Domain và khởi động lại ngay lập tức
Add-Computer -DomainName "lab.local" -Credential $Credential -Restart -Force

# =====================================================================
# XÁC MINH SAU KHI REBOOT (XÁC MINH TRẠNG THÁI JOIN DOMAIN THÀNH CÔNG)
# =====================================================================
# Thực thi lệnh sau để kiểm tra xem Client đã thuộc về Domain 'lab.local' chưa:
[System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
```

---

## 🛡️ 6. Kịch Bản 5: Thiết Lập Sao Lưu & Phục Hồi Thảm Họa (Disaster Recovery)
Để bảo vệ cơ sở dữ liệu Active Directory (`NTDS.dit`), chính sách nhóm (`SYSVOL`) và thông tin bảo mật, quản trị viên cần triển khai cơ chế **System State Backup**.

### 📥 Bước 5.1: Cấu hình và Chạy Sao Lưu Trạng Thái Hệ Thống (System State Backup)
> [!WARNING]
> Phải chỉ định phân vùng lưu trữ riêng độc lập (ví dụ ổ `E:`), tuyệt đối không sao lưu trực tiếp lên cùng phân vùng hệ điều hành (`C:`).

```powershell
# 1. Cài đặt tính năng Windows Server Backup trên Domain Controller
Install-WindowsFeature -Name Windows-Server-Backup

# 2. Thiết lập chính sách sao lưu System State tạm thời và chỉ định đích lưu trữ ổ E:
$Policy = New-WBPolicy
Add-WBSystemState -Policy $Policy
$BackupTarget = New-WBBackupTarget -VolumePath "E:"
Add-WBBackupTarget -Policy $Policy -Target $BackupTarget

# 3. Bắt đầu tiến trình chạy sao lưu ngay lập tức
Start-WBBackup -Policy $Policy
```

### 🔄 Bước 5.2: Khôi Phục Hệ Thống Khi Gặp Thảm Họa (Restore AD DS)
> [!CAUTION]
> Bạn không thể phục hồi trạng thái hệ thống khi Windows Server đang chạy bình thường. Bắt buộc phải khởi động máy chủ vào chế độ chuyên dụng phục hồi dịch vụ thư mục **Directory Services Repair Mode (DSRM)**.

1. **Khởi động cưỡng bức máy chủ vào chế độ DSRM bằng PowerShell**:
   ```powershell
   bcdedit /set safeboot dsrm
   Restart-Computer -Force
   ```
2. **Đăng nhập DSRM**: Khi máy chủ khởi động lại, đăng nhập bằng tài khoản cục bộ `.\Administrator` phối hợp với mật khẩu DSRM (đã cấu hình tại Bước 1.2).
3. **Thực hiện khôi phục**: Mở PowerShell (Admin) và kiểm tra danh sách bản sao lưu:
   ```powershell
   wbadmin get versions
   ```
   *Lấy mã nhận dạng (Version Identifier), ví dụ: `05/30/2026-10:00`*
4. **Chạy lệnh phục hồi System State**:
   ```powershell
   wbadmin start systemstaterestore -version:05/30/2026-10:00 -backupTarget:E: -quiet
   ```
5. **Đưa máy chủ hoạt động bình thường trở lại**: Sau khi khôi phục hoàn tất 100%, tắt cờ khởi động Safe Boot DSRM để đưa máy chủ về chế độ vận hành mạng chuẩn:
   ```powershell
   bcdedit /deletevalue safeboot
   Restart-Computer -Force
   ```

---

## 🎯 7. Best Practices Dành Cho SysAdmin Quản Trị AD DS
✔ **Luôn triển khai ít nhất 2 Domain Controllers**: DC phụ (`LAB-DC02`) đảm bảo mạng hoạt động bình thường kể cả khi DC chính gặp sự cố vật lý hoặc cần tắt để cập nhật hệ điều hành.

✔ **Sử dụng DHCP Integration & Authorization**: DHCP và AD DS khi chạy trên cùng một máy chủ phải được ủy quyền đầy đủ để dịch vụ DHCP có thể tự khởi động và đăng ký các bản ghi DNS động chính xác.

✔ **Preferred DNS trỏ chéo**: Với mô hình đa DC, cấu hình card mạng của DC01 trỏ Preferred DNS về DC02 (`192.168.100.102`) và Alternate DNS về chính nó (`127.0.0.1`). Ngược lại trên DC02, Preferred DNS trỏ về DC01 (`192.168.100.101`) và Alternate DNS về chính nó (`127.0.0.1`). Cơ chế trỏ chéo này giúp hệ thống đồng bộ dữ liệu chuẩn xác nhất.

✔ **Định kỳ kiểm tra System State Backup**: Lập lịch sao lưu tự động và kiểm thử khôi phục giả lập trên lab cách ly tối thiểu 6 tháng 1 lần để đảm bảo tệp sao lưu nguyên vẹn.