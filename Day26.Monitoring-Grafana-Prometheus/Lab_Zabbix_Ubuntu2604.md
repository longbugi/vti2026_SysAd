# 🖥️ LAB: Giám sát hệ thống với Zabbix trên Ubuntu 26.04 LTS (Resolute)

> **Môn học:** Monitoring – Lesson 26 | **VTI Academy**
> **Hệ điều hành Server:** Ubuntu 26.04 LTS "Resolute" · **Agent:** Ubuntu 26.04 & Windows
> **Phiên bản Zabbix:** 7.2 (LTS)
> **Thời lượng:** ~2 giờ

---

## 📋 Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Cài đặt Zabbix Server trên Ubuntu 26.04](#2-cài-đặt-zabbix-server-trên-ubuntu-2604)
3. [Cài đặt Zabbix Agent trên Ubuntu](#3-cài-đặt-zabbix-agent-trên-ubuntu)
4. [Cài đặt Zabbix Agent trên Windows](#4-cài-đặt-zabbix-agent-trên-windows)
5. [Tạo Host và giám sát CPU, RAM, Disk](#5-tạo-host-và-giám-sát-cpu-ram-disk)
6. [Tạo Trigger cảnh báo theo ngưỡng](#6-tạo-trigger-cảnh-báo-theo-ngưỡng)
7. [Cấu hình gửi Alert qua Email](#7-cấu-hình-gửi-alert-qua-email)
8. [Kiểm tra & Xác nhận](#8-kiểm-tra--xác-nhận)

---

## 1. Tổng quan kiến trúc

```
┌─────────────────────────────────────────────────────────┐
│                    ZABBIX SERVER                        │
│         Ubuntu 26.04 LTS  –  IP: 192.168.100.10         │
│   ┌──────────┐  ┌──────────┐  ┌───────────────────┐    │
│   │  MySQL   │  │  Zabbix  │  │      Apache       │    │
│   │  (DB)    │  │  Server  │  │  (Web Frontend)   │    │
│   └──────────┘  └──────────┘  └───────────────────┘    │
└────────────────────────┬────────────────────────────────┘
                         │  Port 10051
              ┌──────────┴──────────┐
              │                     │
   ┌──────────▼──────────┐ ┌────────▼────────────┐
   │   UBUNTU TARGET     │ │   WINDOWS TARGET    │
   │  Ubuntu 26.04 LTS   │ │  Windows 10/11      │
   │  Zabbix Agent 2     │ │  Zabbix Agent 2     │
   │  IP: 192.168.100.20 │ │  IP: 192.168.100.30 │
   │  Port: 10050        │ │  Port: 10050        │
   └─────────────────────┘ └─────────────────────┘
```

| Thành phần     | IP                | Hostname            | Ghi chú                    |
|----------------|-------------------|---------------------|----------------------------|
| Zabbix Server  | `192.168.100.10`  | `zabbix`            | Ubuntu 26.04 LTS "Resolute"|
| Ubuntu Target  | `192.168.100.20`  | `ubuntu-target-01`  | Máy Ubuntu cần giám sát    |
| Windows Target | `192.168.100.30`  | `windows-target-01` | Windows 10/11 hoặc Server  |

> ⚠️ **Lưu ý:** Thay các địa chỉ IP trên bằng IP thực tế trong môi trường lab của bạn.

---

## 2. Cài đặt Zabbix Server trên Ubuntu 26.04

### 2.1 Cập nhật hệ thống

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg2 software-properties-common apt-transport-https
```

### 2.2 Cài đặt MySQL Server

```bash
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql
```

Chạy thiết lập bảo mật:

```bash
sudo mysql_secure_installation
```

> Chọn: **Remove anonymous users → YES** | **Disallow root login remotely → YES** | **Remove test database → YES**

### 2.3 Thêm Zabbix Repository cho Ubuntu 26.04

> 💡 **Lưu ý quan trọng:** Ubuntu 26.04 "Resolute" còn rất mới, Zabbix có thể chưa
> phát hành package riêng. Hãy kiểm tra URL đúng theo các bước sau:

**Bước 1 – Kiểm tra codename hệ thống:**

```bash
lsb_release -cs
# Kết quả mong đợi: resolute
```

**Bước 2 – Tìm URL package đúng trên trang Zabbix:**

Truy cập trình duyệt: https://www.zabbix.com/download

Chọn:
- **Zabbix version:** `7.2`
- **OS Distribution:** `Ubuntu`
- **OS Version:** `26.04 (Resolute)` *(nếu chưa có, chọn `24.04` để xem pattern URL)*
- **Zabbix component:** `Server, Frontend, Agent`
- **Database:** `MySQL`
- **Web server:** `Apache`

**Bước 3 – Cài đặt theo lệnh trên trang web** (lệnh mẫu dự kiến):

```bash
# Thay thế URL bằng link chính xác lấy từ https://www.zabbix.com/download
wget https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.4%2Bubuntu26.04_all.deb

sudo dpkg -i zabbix-release_latest_7.4+ubuntu26.04_all.deb
sudo apt update
```

**Nếu Zabbix chưa hỗ trợ Ubuntu 26.04 – dùng phương án thay thế:**

```bash
# Phương án A: Dùng repo Ubuntu 24.04 (noble) tạm thời
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.2-1+ubuntu24.04_all.deb

sudo dpkg -i zabbix-release_7.2-1+ubuntu24.04_all.deb

# Ghi đè codename về noble trong sources.list
sudo sed -i 's/resolute/noble/g' /etc/apt/sources.list.d/zabbix.list
sudo apt update
```

```bash
# Phương án B: Cài trực tiếp từ apt nếu Zabbix đã vào Ubuntu main repo
sudo apt install -y zabbix-server-mysql zabbix-frontend-php \
  zabbix-apache-conf zabbix-sql-scripts zabbix-agent2
```

### 2.4 Cài đặt Zabbix Server, Frontend và Agent 2

```bash
sudo apt install -y \
  zabbix-server-mysql \
  zabbix-frontend-php \
  zabbix-apache-conf \
  zabbix-sql-scripts \
  zabbix-agent2
```

### 2.5 Tạo Database cho Zabbix

```bash
sudo mysql -uroot -p
```

Trong MySQL shell, chạy lần lượt:

```sql
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;

CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'ZabbixPass@2024';

GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';

SET GLOBAL log_bin_trust_function_creators = 1;

FLUSH PRIVILEGES;
EXIT;
```

Import schema Zabbix vào database:


```bash
zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz \
  | sudo mysql --default-character-set=utf8mb4 -uzabbix -p zabbix
```

> ⏳ Quá trình import mất khoảng **2–5 phút**, vui lòng chờ đến khi hoàn tất.

zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz | sudo mysql --default-character-set=utf8mb4 zabbix

Your earlier failure happened because DBPassword is not set in /etc/zabbix/zabbix_server.conf, so the zabbix DB user auth wasn’t valid.

Sau khi import xong, tắt flag tạm thời:

```bash
sudo mysql -uroot -p -e "SET GLOBAL log_bin_trust_function_creators = 0;"
```

### 2.6 Cấu hình Zabbix Server

```bash
sudo vim /etc/zabbix/zabbix_server.conf
```

Tìm và sửa các dòng sau:

```ini
DBPassword=ZabbixPass@2024
ListenPort=10051
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=10
```
```bash
sudo sed -i '/^DBPassword=/s/=[^#]*/=ZabbixPass@2024/' /etc/zabbix/zabbix_server.conf
sudo sed -i '/^ListenPort=/s/=[^#]*/=10051/' /etc/zabbix/zabbix_server.conf
sudo sed -i '/^LogFile=/s|=[^#]*|=/var/log/zabbix/zabbix_server.log|' /etc/zabbix/zabbix_server.conf
sudo sed -i '/^LogFileSize=/s/=[^#]*/=10/' /etc/zabbix/zabbix_server.conf

#sudo sed -i '/^CacheSize=/s/=[^#]*/=256M/' /etc/zabbix/zabbix_server.conf


```


### 2.7 Cấu hình timezone PHP

```bash
sudo vim /etc/zabbix/apache.conf
```

Đảm bảo dòng timezone đúng:

```apache
php_value date.timezone Asia/Ho_Chi_Minh
```

### 2.8 Khởi động dịch vụ

```bash
sudo systemctl restart zabbix-server zabbix-agent2 apache2
sudo systemctl enable  zabbix-server zabbix-agent2 apache2
```

Kiểm tra trạng thái:

```bash
sudo systemctl status zabbix-server
# Kết quả mong đợi: Active: active (running)
```

### 2.9 Mở firewall

```bash
sudo ufw allow 10050/tcp   # Zabbix Agent
sudo ufw allow 10051/tcp   # Zabbix Server
sudo ufw allow 80/tcp      # HTTP Web UI
sudo ufw allow 443/tcp     # HTTPS
sudo ufw reload
sudo ufw status
```

### 2.10 Cấu hình Web UI lần đầu

1. Mở trình duyệt: `http://192.168.100.10/zabbix`
2. Làm theo wizard:
   - **Welcome** → Next step
   - **Check prerequisites** → Next (đảm bảo tất cả ✅ xanh)
   - **Configure DB connection:**

     | Trường   | Giá trị           |
     |----------|-------------------|
     | Host     | `localhost`       |
     | Port     | `3306`            |
     | Database | `zabbix`          |
     | User     | `zabbix`          |
     | Password | `ZabbixPass@2024` |

   - **Settings:** Name = `VTI Zabbix Lab`, Timezone = `Asia/Ho_Chi_Minh`
   - **Finish**
3. Đăng nhập: **Username** `Admin` / **Password** `zabbix`

> 🔐 **Bảo mật:** Đổi mật khẩu Admin ngay sau khi đăng nhập lần đầu:
> **User settings (góc phải) → Profile → Change password**

---

## 3. Cài đặt Zabbix Agent trên Ubuntu

> Thực hiện trên **máy Ubuntu cần giám sát** – IP: `192.168.100.20`

### 3.1 Thêm Zabbix Repository (giống Server)

```bash
# Dùng cùng package đã tải ở bước 2.3
wget https://repo.zabbix.com/zabbix/7.2/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.2-1+ubuntu26.04_all.deb

sudo dpkg -i zabbix-release_7.2-1+ubuntu26.04_all.deb
sudo apt update
```

### 3.2 Cài đặt Zabbix Agent 2

```bash
sudo apt install -y zabbix-agent2 zabbix-agent2-plugin-*
```

### 3.3 Cấu hình Agent 2

```bash
sudo nano /etc/zabbix/zabbix_agent2.conf
```

Sửa các thông số sau:

```ini
# Địa chỉ Zabbix Server (passive – Server kéo dữ liệu từ Agent)
Server=192.168.100.10

# Địa chỉ Zabbix Server (active – Agent chủ động gửi dữ liệu)
ServerActive=192.168.100.10

# Tên hostname – PHẢI khớp với "Host name" trên Zabbix Web UI
Hostname=ubuntu-target-01

# Port Agent lắng nghe
ListenPort=10050

# Log
LogFile=/var/log/zabbix/zabbix_agent2.log
```

### 3.4 Khởi động Agent 2

```bash
sudo systemctl restart zabbix-agent2
sudo systemctl enable  zabbix-agent2
sudo systemctl status  zabbix-agent2
```

### 3.5 Mở firewall

```bash
sudo ufw allow 10050/tcp
sudo ufw reload
```

### 3.6 Kiểm tra kết nối từ Server

Chạy lệnh sau **trên Zabbix Server** (`192.168.100.10`):

```bash
# Cài công cụ kiểm tra
sudo apt install -y zabbix-get

# Test lấy metrics từ Ubuntu target
zabbix_get -s 192.168.100.20 -p 10050 -k system.cpu.util
zabbix_get -s 192.168.100.20 -p 10050 -k vm.memory.size[pavailable]
zabbix_get -s 192.168.100.20 -p 10050 -k vfs.fs.size[/,pused]
```

> ✅ Lệnh trả về giá trị số → Agent kết nối thành công.

---

## 4. Cài đặt Zabbix Agent trên Windows

> Thực hiện trên **máy Windows** – IP: `192.168.100.30`

### 4.1 Tải Zabbix Agent 2

Truy cập: [https://www.zabbix.com/download_agents](https://www.zabbix.com/download_agents)

| Trường     | Chọn      |
|------------|-----------|
| Version    | `7.2`     |
| OS         | `Windows` |
| OS Flavour | `amd64`   |
| Packaging  | `MSI`     |

### 4.2 Cài đặt bằng MSI Installer (GUI)

Chạy file `.msi` với quyền **Administrator**, điền:

| Trường                           | Giá trị                |
|----------------------------------|------------------------|
| Zabbix server IP/DNS             | `192.168.100.10`       |
| Agent listen port                | `10050`                |
| Server or Proxy for active checks| `192.168.100.10`       |
| Hostname                         | `windows-target-01`    |

### 4.3 Cài đặt bằng Command Line (tùy chọn)

M�� **Command Prompt** với quyền Administrator:

```cmd
msiexec /i "zabbix_agent2-7.2.0-windows-amd64-openssl.msi" ^
  /qn ^
  SERVER=192.168.100.10 ^
  SERVERACTIVE=192.168.100.10 ^
  HOSTNAME=windows-target-01 ^
  LISTENPORT=10050 ^
  ENABLEREMOTECOMMANDS=1
```

### 4.4 Kiểm tra dịch vụ

```cmd
sc query "Zabbix Agent 2"
```

Kết quả mong đợi: `STATE: 4 RUNNING`

Nếu dịch vụ chưa chạy:

```cmd
sc start "Zabbix Agent 2"
```

### 4.5 Mở Windows Firewall

Chạy **PowerShell** với quyền Administrator:

```powershell
New-NetFirewallRule `
  -DisplayName "Zabbix Agent 2" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 10050 `
  -Action Allow `
  -Profile Any
```

---

## 5. Tạo Host và giám sát CPU, RAM, Disk

> Thực hiện trên **Zabbix Web UI**: `http://192.168.100.10/zabbix`

> Default User: `Admin`
> Default password: `zabbix`

### 5.1 Thêm Host Ubuntu

1. Vào **Data collection → Hosts → Create host**

2. Tab **Host:**

   | Trường       | Giá trị               |
   |--------------|-----------------------|
   | Host name    | `ubuntu-target-01`    |
   | Visible name | `Ubuntu 26.04 Target` |
   | Host groups  | `Linux servers`       |

3. Tab **Interfaces → Add → Agent:**

   | Trường     | Giá trị           |
   |------------|-------------------|
   | IP address | `192.168.100.20`  |
   | Port       | `10050`           |

4. Tab **Templates → Select:**
   - Tìm: `Linux by Zabbix agent 2` → **Select**

5. Nhấn **Add** để lưu

### 5.2 Thêm Host Windows

| Trường       | Giá trị                        |
|--------------|--------------------------------|
| Host name    | `windows-target-01`            |
| Visible name | `Windows Target`               |
| Host groups  | `Windows servers`              |
| IP address   | `192.168.100.30`               |
| Port         | `10050`                        |
| Template     | `Windows by Zabbix agent 2`    |

### 5.3 Kiểm tra dữ liệu giám sát

Sau ~1–2 phút, vào **Monitoring → Latest data**, lọc theo host:

| Key / Metric                 | Mô tả                  | Đơn vị  |
|------------------------------|------------------------|---------|
| `system.cpu.util`            | % CPU đang sử dụng     | `%`     |
| `vm.memory.size[pavailable]` | % RAM còn trống        | `%`     |
| `vfs.fs.size[/,pused]`       | % Disk `/` đã dùng     | `%`     |
| `system.uptime`              | Thời gian hoạt động    | giây    |
| `net.if.in[ens3]`            | Lưu lượng mạng vào     | bytes/s |
| `system.swap.size[,pused]`   | % Swap đang dùng       | `%`     |

> ✅ Dữ liệu cập nhật liên tục mỗi 60 giây → Agent kết nối thành công.

---

## 6. Tạo Trigger cảnh báo theo ngưỡng

### 6.1 Tạo Trigger – CPU cao

1. Vào **Data collection → Hosts → ubuntu-target-01 → Triggers → Create trigger**

2. Điền thông tin:

   | Trường     | Giá trị                                    |
   |------------|--------------------------------------------|
   | Name       | `High CPU usage (over 80%) on {HOST.NAME}` |
   | Severity   | **High**                                   |

3. Phần **Expression** → nhấn **Add:**

   ```
   avg(/ubuntu-target-01/system.cpu.util,5m)>80
   ```

   > Ý nghĩa: CPU trung bình **5 phút** vượt **80%**

4. **Description:**
   ```
   CPU đang ở mức {ITEM.LASTVALUE} trong 5 phút liên tiếp.
   Kiểm tra tiến trình: top, htop hoặc ps aux --sort=-%cpu | head
   ```

5. Nhấn **Add** để lưu

### 6.2 Tạo Trigger – RAM thấp

| Trường     | Giá trị                                           |
|------------|---------------------------------------------------|
| Name       | `Low memory available (below 15%) on {HOST.NAME}` |
| Severity   | **Average**                                       |
| Expression | `last(/ubuntu-target-01/vm.memory.size[pavailable])<15` |
| Description| RAM còn `{ITEM.LASTVALUE}%`. Nguy cơ hệ thống bị OOM killer. |

### 6.3 Tạo Trigger – Disk đầy

| Trường     | Giá trị                                                 |
|------------|---------------------------------------------------------|
| Name       | `Disk space critically low (over 85%) on {HOST.NAME}`   |
| Severity   | **High**                                                |
| Expression | `last(/ubuntu-target-01/vfs.fs.size[/,pused])>85`       |
| Description| Disk `/` đã dùng `{ITEM.LASTVALUE}%`. Cần dọn dữ liệu ngay. |

### 6.4 Bảng tổng hợp ngưỡng cảnh báo

| Tài nguyên | Warning        | Average        | High           | Disaster       |
|------------|----------------|----------------|----------------|----------------|
| CPU Usage  | `>60%` / 5 min | `>70%` / 5 min | `>80%` / 5 min | `>95%` / 2 min |
| RAM Free   | `<25%`         | `<20%`         | `<15%`         | `<5%`          |
| Disk Used  | `>70%`         | `>75%`         | `>85%`         | `>95%`         |
| Swap Used  | `>30%`         | `>50%`         | `>70%`         | —              |

### 6.5 Kiểm tra Trigger bằng stress-ng

```bash
# Cài stress-ng (Ubuntu 26.04 dùng stress-ng thay cho stress)
sudo apt install -y stress-ng

# Tạo tải CPU 100% trong 5 phút
stress-ng --cpu 4 --timeout 300s

# Tạo tải RAM (chiếm 1GB trong 3 phút)
stress-ng --vm 1 --vm-bytes 1G --timeout 180s
```

Kiểm tra tại **Monitoring → Problems** – trigger xuất hiện sau ~1 phút.

---

## 7. Cấu hình gửi Alert qua Email

### 7.1 Cấu hình Media Type – Email

1. Vào **Alerts → Media types → Email**

2. Điền thông tin SMTP Gmail:

   | Trường              | Giá trị                   |
   |---------------------|---------------------------|
   | SMTP server         | `smtp.gmail.com`          |
   | SMTP server port    | `587`                     |
   | SMTP helo           | `gmail.com`               |
   | SMTP email          | `youremail@gmail.com`     |
   | Connection security | **STARTTLS**              |
   | Authentication      | **Username and password** |
   | Username            | `youremail@gmail.com`     |
   | Password            | *(Google App Password)*   |

   > 💡 **Tạo Google App Password:**
   > Google Account → Security → 2-Step Verification → App passwords
   > → Chọn "Mail" → Generate → Copy 16 ký tự

3. Nhấn **Update** → nhấn **Test** để kiểm tra gửi thử

### 7.2 Thêm Email vào tài khoản Admin

1. Vào **Administration → Users → Admin → Tab Media → Add:**

   | Trường          | Giá trị                         |
   |-----------------|---------------------------------|
   | Type            | `Email`                         |
   | Send to         | `alert-receiver@gmail.com`      |
   | When active     | `1-7,00:00-24:00`               |
   | Use if severity | ✅ Warning, Average, High, Disaster |

2. Nhấn **Add** → **Update**

### 7.3 Tạo Action – Gửi email khi có cảnh báo

1. Vào **Alerts → Actions → Trigger actions → Create action**

2. Tab **Action:**

   | Trường  | Giá trị             |
   |---------|---------------------|
   | Name    | `Send Email Alert`  |
   | Enabled | ✅                  |

3. Tab **Operations → Add:**

   | Trường              | Giá trị                             |
   |---------------------|-------------------------------------|
   | Send to user groups | `Zabbix administrators`             |
   | Send only to        | `Email`                             |
   | Default subject     | `[{TRIGGER.STATUS}] {TRIGGER.NAME}` |
   | Default message     | *(xem mẫu bên dưới)*               |

   **Mẫu nội dung email:**

   ```
   🚨 CẢNH BÁO HỆ THỐNG

   Hostname   : {HOST.NAME}
   IP Address : {HOST.IP}
   Trigger    : {TRIGGER.NAME}
   Mức độ     : {TRIGGER.SEVERITY}
   Trạng thái : {TRIGGER.STATUS}
   Thời gian  : {EVENT.DATE} lúc {EVENT.TIME}
   Giá trị    : {ITEM.LASTVALUE}
   Mô tả      : {TRIGGER.DESCRIPTION}

   🔗 Xem chi tiết: http://192.168.100.10/zabbix

   ---
   Zabbix Monitoring | VTI Academy
   ```

4. Tab **Recovery operations → Add:**
   - Gửi thông báo khi sự cố đã giải quyết
   - Subject: `[RESOLVED] {TRIGGER.NAME}`

5. Tab **Conditions:**
   - `Trigger severity` >= `Warning`
   - `Trigger value` = `PROBLEM`

6. Nhấn **Add** để lưu

### 7.4 Kiểm tra gửi Email

```bash
# Trên máy Ubuntu target – tạo tải CPU kích hoạt trigger
stress-ng --cpu 4 --timeout 300s &

# Kiểm tra log nếu không nhận được email
sudo tail -50 /var/log/zabbix/zabbix_server.log | grep -i "email\|alert\|action"
```

Kiểm tra trên Web UI: **Monitoring → Problems** → cột **Actions** có icon ✉️ = email đã gửi.

---

## 8. Kiểm tra & Xác nhận

### ✅ Checklist hoàn thành LAB

#### Zabbix Server (Ubuntu 26.04)
- [ ] Zabbix Server 7.2 cài đặt thành công
- [ ] Dịch vụ `zabbix-server` và `zabbix-agent2` đang `active (running)`
- [ ] Truy cập Web UI `http://192.168.100.10/zabbix` thành công
- [ ] Đã đổi mật khẩu Admin mặc định

#### Zabbix Agent – Ubuntu 26.04
- [ ] Zabbix Agent 2 cài đặt trên `ubuntu-target-01` (IP: `192.168.100.20`)
- [ ] File `/etc/zabbix/zabbix_agent2.conf` đúng: `Server=192.168.100.10`, `Hostname=ubuntu-target-01`
- [ ] Firewall đã mở port `10050/tcp`
- [ ] `zabbix_get` từ Server trả về dữ liệu hợp lệ

#### Zabbix Agent – Windows
- [ ] Zabbix Agent 2 cài và dịch vụ `RUNNING` trên `192.168.100.30`
- [ ] Windows Firewall mở inbound port `10050/tcp`
- [ ] Hostname config khớp với tên Host trên Web UI

#### Giám sát Host
- [ ] Host `ubuntu-target-01` hiển thị **màu xanh** trong Monitoring → Hosts
- [ ] Host `windows-target-01` hiển thị **màu xanh**
- [ ] Latest data cập nhật CPU, RAM, Disk mỗi 60 giây

#### Trigger & Alert
- [ ] Trigger **CPU > 80%** tạo thành công, kích hoạt được khi test
- [ ] Trigger **RAM < 15%** tạo thành công
- [ ] Trigger **Disk > 85%** tạo thành công
- [ ] Monitoring → Problems hiển thị cảnh báo khi dùng `stress-ng`

#### Email Alert
- [ ] Media Type Email cấu hình SMTP đúng, Test thành công
- [ ] Tài khoản Admin đã thêm email nhận cảnh báo
- [ ] Action "Send Email Alert" đã tạo và enabled
- [ ] Nhận được email cảnh báo khi trigger kích hoạt
- [ ] Nhận được email recovery khi sự cố giải quyết

---

### 🔍 Lệnh kiểm tra nhanh

```bash
# ── Trên Zabbix Server (192.168.100.10) ────────────────────────

# Kiểm tra tất cả dịch vụ
sudo systemctl status zabbix-server zabbix-agent2 apache2 mysql

# Xem log realtime
sudo tail -f /var/log/zabbix/zabbix_server.log

# Test lấy metrics từ Ubuntu target
zabbix_get -s 192.168.100.20 -p 10050 -k system.cpu.util
zabbix_get -s 192.168.100.20 -p 10050 -k vm.memory.size[pavailable]
zabbix_get -s 192.168.100.20 -p 10050 -k vfs.fs.size[/,pused]

# Kiểm tra kết nối port
nc -zv 192.168.100.20 10050
nc -zv 192.168.100.30 10050

# ── Trên Ubuntu Agent (192.168.100.20) ─────────────────────────

# Kiểm tra agent
sudo systemctl status zabbix-agent2
sudo tail -f /var/log/zabbix/zabbix_agent2.log

# Xem cấu hình đang áp dụng (bỏ dòng trống và comment)
grep -v "^#\|^$" /etc/zabbix/zabbix_agent2.conf
```

---

### 🛠️ Xử lý sự cố thường gặp

| Vấn đề | Nguyên nhân có thể | Cách khắc phục |
|---|---|---|
| `wget` báo 404 khi tải repo | Ubuntu 26.04 chưa có repo riêng | Dùng repo Ubuntu 24.04 tạm thời, xem mục 2.3 Phương án A |
| Host hiển thị màu đỏ | Agent không kết nối được | Kiểm tra firewall, ping IP, test port: `nc -zv 192.168.100.20 10050` |
| Không có data trong Latest Data | `Hostname` không khớp | So sánh `Hostname` trong `zabbix_agent2.conf` với **Host name** trên Web UI |
| `zabbix_get` báo timeout | Firewall chặn port 10050 | `sudo ufw allow 10050/tcp` trên máy target |
| Không nhận được email | SMTP sai / App Password chưa tạo | Dùng nút **Test** trong Media Type; kiểm tra log `zabbix_server.log` |
| Trigger không kích hoạt | Expression sai key item | Kiểm tra tên **key** chính xác trong Latest Data rồi copy vào Expression |
| Zabbix Server không start | Lỗi DB connection | Kiểm tra `DBPassword` trong `zabbix_server.conf`; test: `mysql -uzabbix -p zabbix` |
| Import schema thất bại | MySQL 8+ cần trust flag | Chạy `SET GLOBAL log_bin_trust_function_creators = 1;` trước khi import |

---

## 📚 Tài liệu tham khảo

- [Zabbix Download – chọn Ubuntu 26.04](https://www.zabbix.com/download?os_distribution=ubuntu&os_version=26.04)
- [Zabbix 7.2 Documentation](https://www.zabbix.com/documentation/7.2)
- [Zabbix Agent 2 for Windows](https://www.zabbix.com/download_agents)
- [Zabbix Agent 2 Configuration Reference](https://www.zabbix.com/documentation/7.2/en/manual/appendix/config/zabbix_agent2)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)

---

*VTI Academy – Way to Enterprise | Lesson 26: Monitoring*
