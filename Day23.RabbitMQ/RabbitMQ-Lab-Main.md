# LAB-2

Created: June 10, 2026 8:18 AM
Tags: RabbitMQ

```
192.168.100.0/24
```

# LAB RabbitMQ cho môi trường doanh nghiệp

## Sơ đồ

```
                    192.168.100.0/24

+--------------------------------------------------+
|                                                  |
|  RabbitMQ Server                                 |
|  192.168.100.10                                  |
|                                                  |
+--------------------------------------------------+
                    ^
                    |
                    |
        student.created event
                    |
                    |

+--------------------------------------------------+
|                                                  |
|  Student Portal (Producer)                       |
|  192.168.100.20                                  |
|                                                  |
+--------------------------------------------------+

                    |
                    v

+--------------------------------------------------+
|                                                  |
|  Consumer Server                                 |
|  192.168.100.30                                  |
|                                                  |
|  Email Service                                   |
|  AD Sync Service                                 |
|  Audit Service                                   |
|                                                  |
+--------------------------------------------------+
```

---

# VM Layout

| VM | Hostname | IP |
| --- | --- | --- |
| RabbitMQ | rabbitmq.lab.local | 192.168.100.10 |
| Producer | portal.lab.local | 192.168.100.20 |
| Consumer | worker.lab.local | 192.168.100.30 |

Gateway:

```
192.168.100.1
```

DNS:

```
8.8.8.8
```

---

# Bước 1 - Cấu hình Hostname

RabbitMQ

```bash
sudo hostnamectl set-hostname rabbitmq.lab.local
```

Producer

```bash
sudo hostnamectl set-hostname portal.lab.local
```

Consumer

```bash
sudo hostnamectl set-hostname worker.lab.local
```

---

# Bước 2 - Cấu hình Hosts

Trên cả 3 máy:

```bash
sudo nano /etc/hosts
```

Thêm:

```
192.168.100.10 rabbitmq.lab.local
192.168.100.20 portal.lab.local
192.168.100.30 worker.lab.local
```

Test:

```bash
ping rabbitmq.lab.local
```

---

# Bước 3 - Cài RabbitMQ

Trên 192.168.100.10

```bash
sudo apt update

sudo apt install rabbitmq-server -y
```

Kiểm tra:

```bash
sudo systemctl status rabbitmq-server
```

---

Enable Management UI

```bash
sudo rabbitmq-plugins enable rabbitmq_management
```

---

Cho phép truy cập từ xa

```bash
sudo rabbitmqctl add_user admin Admin@123
```

```bash
sudo rabbitmqctl set_user_tags admin administrator
```

```bash
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"
```

Xóa user guest:

```bash
sudo rabbitmqctl delete_user guest
```

---

# Firewall

```bash
sudo ufw allow 5672/tcp
```

```bash
sudo ufw allow 15672/tcp
```

Kiểm tra:

```bash
ss -tulpn | grep rabbit
```

---

# Bước 4 - Truy cập Web UI

Từ browser:

```
http://192.168.100.10:15672
```

Login:

```
admin
Admin@123
```

---

# Bước 5 - Cài Python

[**- Python Virtual Environment** 

`sudo apt update
sudo apt install python3-full python3-venv -y`

Tạo môi trường:

`mkdir ~/rabbitmq-lab
cd ~/rabbitmq-lab

python3 -m venv venv`

Kích hoạt:

`source venv/bin/activate`

Bạn sẽ thấy:

`(venv) user@server:~/rabbitmq-lab$`

Cài thư viện:

`pip install pika requests`

Kiểm tra:

`pip list`](https://app.notion.com/p/Python-Virtual-Environment-sudo-apt-update-sudo-apt-install-python3-full-python3-venv-y-T-o-m-i--37ce27b0f9bc80b197e5eaa0deb3d556?pvs=21)

Producer

```bash
sudo apt install python3-pip -y
```

```bash
pip3 install pika
```

Consumer

```bash
sudo apt install python3-pip -y
```

```bash
pip3 install pika
```

---

Bước 6 - Tạo Exchange

RabbitMQ UI

Exchange:

```
school_events
```

Type:

```
fanout
```

Durable:

```
Yes
```

---

# Bước 7 - Tạo Queue

Tạo 3 queue:

```
email_q
```

```
ad_q
```

```
audit_q
```

---

Bind vào Exchange

```
school_events
       |
       +--> email_q
       |
       +--> ad_q
       |
       +--> audit_q
```

---

# Bước 8 - Producer

portal.py

```python
import pika
import json

credentials = pika.PlainCredentials(
    'admin',
    'Admin@123'
)

connection = pika.BlockingConnection(
    pika.ConnectionParameters(
        host='192.168.100.10',
        credentials=credentials
    )
)

channel = connection.channel()

student = {
    "student_id":"S1001",
    "name":"Nguyen Van A",
    "grade":"Grade 10"
}

channel.basic_publish(
    exchange='school_events',
    routing_key='',
    body=json.dumps(student)
)

print("Student created")

connection.close()
```

Chạy:

```bash
python3 portal.py
```

---

---