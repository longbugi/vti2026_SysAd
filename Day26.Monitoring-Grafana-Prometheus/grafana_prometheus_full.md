# Monitoring a Windows Domain Machine with Prometheus & Grafana

**Stack:** windows_exporter (Windows) → Prometheus (Ubuntu) → Grafana (Ubuntu)  
**Tested on:** Ubuntu 22.04 LTS and 24.04 LTS

---

## Overview

This guide sets up a complete monitoring stack for a Windows domain machine. The Windows machine runs a small agent called `windows_exporter` that exposes system metrics. A separate Ubuntu server runs Prometheus (which collects those metrics) and Grafana (which displays them as dashboards).

| Component | Role |
|---|---|
| `windows_exporter` | Runs on the Windows machine. Exposes CPU, memory, disk, network, and service metrics on port 9182. |
| Prometheus | Runs on Ubuntu. Scrapes metrics from `windows_exporter` every 15 seconds and stores them. |
| Grafana | Runs on Ubuntu. Connects to Prometheus and displays dashboards in the browser on port 3000. |

---

## Step 1 — Install `windows_exporter` on the Windows domain machine

Run all commands in this step on the Windows machine you want to monitor, using **PowerShell as Administrator**.

### 1.1 Download the installer

Go to the releases page and download the latest `.msi` file for `amd64`:

```
https://github.com/prometheus-community/windows_exporter/releases
```

### 1.2 Install silently with the required collectors

```powershell
msiexec /i windows_exporter-0.27.2-amd64.msi `
  ENABLED_COLLECTORS="cpu,cs,logical_disk,net,os,process,service,memory" `
  LISTEN_PORT=9182 /qn
```

This installs `windows_exporter` as a Windows service that starts automatically on boot.

### 1.3 Verify it is running

```powershell
Invoke-WebRequest http://localhost:9182/metrics | Select-Object -First 5
```

You should see lines starting with `# HELP` and `# TYPE` followed by metric values.

### 1.4 Open the firewall

Allow the Ubuntu server to reach port 9182 through the Windows firewall:

```powershell
New-NetFirewallRule -DisplayName "Prometheus windows_exporter" `
  -Direction Inbound -Protocol TCP -LocalPort 9182 -Action Allow
```

From the Ubuntu server, confirm connectivity with:

```bash
curl http://<WINDOWS_IP>:9182/metrics
```

> **Note:** Replace `<WINDOWS_IP>` with the actual IP address of your Windows machine throughout this guide.

---

## Step 2 — Install Prometheus on the Ubuntu server

Run all commands from this step onward on the Ubuntu monitoring server.

### 2.1 Create a dedicated system user

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
```

### 2.2 Download and extract Prometheus

Check [https://prometheus.io/download](https://prometheus.io/download) for the latest version number, then run:

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.52.0/prometheus-2.52.0.linux-amd64.tar.gz
tar xvf prometheus-2.52.0.linux-amd64.tar.gz
cd prometheus-2.52.0.linux-amd64
```

### 2.3 Install binaries and directories

```bash
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/
sudo mkdir /etc/prometheus /var/lib/prometheus
sudo cp -r consoles/ console_libraries/ /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
```

---

## Step 3 — Configure Prometheus to scrape the Windows machine

Create the Prometheus configuration file:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

Paste the following content (replace `<WINDOWS_IP>` with your actual IP address):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'windows_domain_machine'
    static_configs:
      - targets: ['<WINDOWS_IP>:9182']
        labels:
          hostname: 'DOMAIN-PC-01'
```

Validate the configuration file before proceeding:

```bash
promtool check config /etc/prometheus/prometheus.yml
```

If the output says `SUCCESS`, the file is valid.

> **Note:** The `hostname` label is optional but helps identify the machine in Grafana when you monitor multiple targets.

---

## Step 4 — Run Prometheus as a systemd service

Create the systemd service file:

```bash
sudo nano /etc/systemd/system/prometheus.service
```

Paste the following:

```ini
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.listen-address=0.0.0.0:9090 \
  --storage.tsdb.retention.time=30d
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl status prometheus
```

Open `http://<UBUNTU_IP>:9090/targets` in your browser. The `windows_domain_machine` target should show a green **UP** status.

If it shows **DOWN**, check that port 9182 is open on the Windows firewall and that the IP address in `prometheus.yml` is correct.

---

## Step 5 — Install Grafana on the Ubuntu server

```bash
sudo apt install -y apt-transport-https software-properties-common

wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y grafana
sudo systemctl enable --now grafana-server
```

Grafana is now accessible at `http://<UBUNTU_IP>:3000`. The default login credentials are username `admin` and password `admin`. You will be prompted to set a new password on first login.

---

## Step 6 — Connect Grafana to Prometheus

1. Log in at `http://<UBUNTU_IP>:3000`
2. Go to **Connections → Data sources → Add data source**
3. Select **Prometheus** from the list
4. Set the URL field to `http://localhost:9090`
5. Scroll down and click **Save & Test**

A green banner saying "Data source is working" confirms the connection is successful.

---

## Step 7 — Import the Windows monitoring dashboard

Import community dashboard ID **14694**, which is purpose-built for `windows_exporter` and covers all major metrics out of the box.

1. Go to **Dashboards → Import**
2. Type `14694` in the ID field and click **Load**
3. Select your Prometheus data source from the dropdown
4. Click **Import**

The dashboard includes the following panels:

| Panel | What it shows |
|---|---|
| CPU usage % | Overall processor load across all cores |
| Memory used / free | Physical RAM consumption and availability |
| Disk read / write | I/O throughput per logical disk volume |
| Network in / out | Bytes per second on each network adapter |
| Running services | State of Windows services (running or stopped) |

---

## Step 8 — Useful PromQL queries for custom panels

Use these queries when building additional panels in Grafana. Enter them in the panel editor under the **Query** tab with **Code** mode selected.

**CPU usage percentage**
```promql
100 - (avg by(instance)(rate(windows_cpu_time_total{mode="idle"}[5m])) * 100)
```

**Memory used percentage**
```promql
100 - (windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes * 100)
```

**Disk free percentage on drive C:**
```promql
windows_logical_disk_free_bytes{volume="C:"} / windows_logical_disk_size_bytes{volume="C:"} * 100
```

**Network received (bytes per second)**
```promql
rate(windows_net_bytes_received_total[5m])
```

**Check if a specific service is running**
```promql
windows_service_state{name="wuauserv", state="running"}
```

A value of `1` means the service is running. A value of `0` means it is stopped. Replace `wuauserv` with any Windows service name.

---

## Step 9 — Set up alerts for CPU, Memory, and Disk above 90%

There are two ways to send alerts in this stack. **Method A** uses Prometheus Alertmanager (recommended for email or Slack). **Method B** uses Grafana Alerting (easier, configured in the browser with no extra installation).

---

### Method A — Prometheus Alertmanager (email / Slack)

#### 9A.1 Install Alertmanager on the Ubuntu server

```bash
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
tar xvf alertmanager-0.27.0.linux-amd64.tar.gz
cd alertmanager-0.27.0.linux-amd64

sudo cp alertmanager /usr/local/bin/
sudo cp amtool /usr/local/bin/
sudo mkdir /etc/alertmanager /var/lib/alertmanager
sudo useradd --no-create-home --shell /bin/false alertmanager
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager
```

#### 9A.2 Configure alert notification channels

Create `/etc/alertmanager/alertmanager.yml`:

```bash
sudo nano /etc/alertmanager/alertmanager.yml
```

**Option 1 — Send alerts by email:**

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'your-email@gmail.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'   # Use a Gmail App Password, not your login password

route:
  receiver: 'email-alert'

receivers:
  - name: 'email-alert'
    email_configs:
      - to: 'admin@yourdomain.com'
        send_resolved: true
```

**Option 2 — Send alerts to Slack:**

```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'

route:
  receiver: 'slack-alert'

receivers:
  - name: 'slack-alert'
    slack_configs:
      - channel: '#alerts'
        send_resolved: true
        title: '{{ .CommonAnnotations.summary }}'
        text: '{{ .CommonAnnotations.description }}'
```

> **Note:** For Gmail, generate an App Password at https://myaccount.google.com/apppasswords. For Slack, create an Incoming Webhook at https://api.slack.com/messaging/webhooks.

#### 9A.3 Run Alertmanager as a systemd service

```bash
sudo nano /etc/systemd/system/alertmanager.service
```

Paste the following:

```ini
[Unit]
Description=Alertmanager
After=network.target

[Service]
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now alertmanager
sudo systemctl status alertmanager
```

Alertmanager runs on port 9093. You can verify it at `http://<UBUNTU_IP>:9093`.

#### 9A.4 Create the alert rules file

Create `/etc/prometheus/alert_rules.yml`:

```bash
sudo nano /etc/prometheus/alert_rules.yml
```

Paste the following rules:

```yaml
groups:
  - name: windows_resource_alerts
    rules:

      # CPU above 90% for more than 5 minutes
      - alert: HighCPUUsage
        expr: >
          100 - (avg by(instance)(rate(windows_cpu_time_total{mode="idle"}[5m])) * 100) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ printf \"%.1f\" $value }}% on {{ $labels.instance }}, which has exceeded 90% for more than 5 minutes."

      # Memory above 90% for more than 5 minutes
      - alert: HighMemoryUsage
        expr: >
          100 - (windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes * 100) > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ printf \"%.1f\" $value }}% on {{ $labels.instance }}, which has exceeded 90% for more than 5 minutes."

      # Disk C: above 90% used
      - alert: HighDiskUsage
        expr: >
          100 - (windows_logical_disk_free_bytes{volume="C:"} / windows_logical_disk_size_bytes{volume="C:"} * 100) > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk C: usage is {{ printf \"%.1f\" $value }}% on {{ $labels.instance }}, which has exceeded 90% for more than 5 minutes."
```

#### 9A.5 Link the alert rules to Prometheus

Edit `/etc/prometheus/prometheus.yml` and add the highlighted lines:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - /etc/prometheus/alert_rules.yml

scrape_configs:
  - job_name: 'windows_domain_machine'
    static_configs:
      - targets: ['<WINDOWS_IP>:9182']
        labels:
          hostname: 'DOMAIN-PC-01'
```

Validate and reload Prometheus:

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl reload prometheus
```

To confirm the rules loaded, open `http://<UBUNTU_IP>:9090/rules` in your browser. All three alerts should appear with a green state.

---

### Method B — Grafana Alerting (browser-based, no extra installation)

This method requires no new software. Alerts are configured directly in the Grafana dashboard.

#### 9B.1 Set up a notification contact point

1. In Grafana, go to **Alerting → Contact points → Add contact point**
2. Give it a name, for example `Email Admin`
3. Choose the type: **Email** (or Slack, Teams, webhook, etc.)
4. Enter the destination email address
5. Click **Test** to confirm it works, then click **Save contact point**

#### 9B.2 Create the CPU alert

1. Go to **Alerting → Alert rules → New alert rule**
2. Set the name to `High CPU Usage`
3. Under **Define query and alert condition**, paste this query:
```promql
100 - (avg by(instance)(rate(windows_cpu_time_total{mode="idle"}[5m])) * 100)
```
4. Set the condition to **IS ABOVE** `90`
5. Set **Evaluate every** `1m` and **for** `5m`
6. Under **Add annotation**, add:
   - Summary: `High CPU on {{ $labels.instance }}`
   - Description: `CPU is at {{ $values.A }}%`
7. Under **Notifications**, select your contact point
8. Click **Save rule and exit**

#### 9B.3 Create the Memory alert

1. Go to **Alerting → Alert rules → New alert rule**
2. Set the name to `High Memory Usage`
3. Paste this query:
```promql
100 - (windows_os_physical_memory_free_bytes / windows_cs_physical_memory_bytes * 100)
```
4. Set the condition to **IS ABOVE** `90`
5. Set **Evaluate every** `1m` and **for** `5m`
6. Add annotations and select your contact point
7. Click **Save rule and exit**

#### 9B.4 Create the Disk Space alert

1. Go to **Alerting → Alert rules → New alert rule**
2. Set the name to `High Disk Usage C:`
3. Paste this query:
```promql
100 - (windows_logical_disk_free_bytes{volume="C:"} / windows_logical_disk_size_bytes{volume="C:"} * 100)
```
4. Set the condition to **IS ABOVE** `90`
5. Set **Evaluate every** `1m` and **for** `5m`
6. Add annotations and select your contact point
7. Click **Save rule and exit**

All active alerts can be monitored at **Alerting → Alert rules** in the Grafana sidebar.

---

### Alert summary

| Alert | Threshold | Method A rule name | Grafana rule name |
|---|---|---|---|
| CPU usage | > 90% for 5 min | `HighCPUUsage` | High CPU Usage |
| Memory usage | > 90% for 5 min | `HighMemoryUsage` | High Memory Usage |
| Disk C: usage | > 90% for 5 min | `HighDiskUsage` | High Disk Usage C: |

> **Tip:** The `for: 5m` setting means the alert only fires if the condition stays above 90% for a full 5 minutes. This prevents false alarms from short spikes. You can reduce this to `for: 1m` if you need faster notification.

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Target shows DOWN in Prometheus | Port 9182 is blocked. Check the Windows firewall rule and confirm the IP address in `prometheus.yml` is correct. |
| No data in Grafana panels | The data source URL may be wrong. Confirm it is set to `http://localhost:9090` and click Save & Test again. |
| `windows_exporter` service not starting | Check the Windows Event Viewer under Application logs for errors. Re-run the `msiexec` command as Administrator. |
| Grafana shows N/A for all metrics | The scrape interval may not have elapsed yet. Wait 30 seconds and refresh. Also check the Prometheus Targets page. |
| Alerts not firing in Prometheus | Open http://&lt;UBUNTU_IP&gt;:9090/rules and check the rule state. Run `promtool check rules /etc/prometheus/alert_rules.yml` to validate the file. |
| No email received from Alertmanager | Check Alertmanager logs with `sudo journalctl -u alertmanager -f`. Confirm the Gmail App Password is correct and that Less Secure App access is not blocking it. |
| Grafana alert stays in Pending state | The condition has not been true for the full `for` duration yet. Wait the evaluation period or lower the `for` value to `1m` for testing. |
