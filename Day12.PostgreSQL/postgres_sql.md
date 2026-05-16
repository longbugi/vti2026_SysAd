# PostgreSQL Command

## 1. Kết nối PostgreSQL

### Login local:

```bash
sudo -u postgres psql
```

### Login với user cụ thể:

```bash
psql -U postgres -d labdb -h localhost
```

### Remote:

```bash
psql -U postgres -h 192.168.26.3 -d labdb
```

---

# 2. Các lệnh meta trong `psql`

> Các lệnh này bắt đầu bằng `\`
> 

## List databases:

```sql
\l
```

## Connect database:

```sql
\c labdb
```

## List tables:

```sql
\dt
```

## List schemas:

```sql
\dn
```

## Describe table:

```sql
\d employees
```

## List users/roles:

```sql
\du
```

## Show current connection:

```sql
\conninfo
```

## Quit:

```sql
\q
```

---

# 3. Database commands

## Create database:

```sql
CREATE DATABASE labdb;
```

## Drop database:

```sql
DROP DATABASE labdb;
```

---

# 4. User / Role management

## Create user:

```sql
CREATE USER dbadmin WITH PASSWORD 'StrongPass123';
```

## Create role with superuser:

```sql
CREATE ROLE dbadmin WITH LOGIN SUPERUSER PASSWORD 'StrongPass123';
```

## Grant privileges:

```sql
GRANT ALL PRIVILEGES ON DATABASE labdb TO dbadmin;
```

## Change password:

```sql
ALTER USER dbadmin WITH PASSWORD 'NewPass123';
```

---

# 5. Table operations

## Create table:

```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name TEXT,
    salary NUMERIC
);
```

## Insert:

```sql
INSERT INTO employees(name, salary)
VALUES ('John', 5000);
```

## Select:

```sql
SELECT * FROM employees;
```

## Update:

```sql
UPDATE employees
SET salary = 6000
WHERE name = 'John';
```

## Delete:

```sql
DELETE FROM employees
WHERE id = 1;
```

## Drop table:

```sql
DROP TABLE employees;
```

---

# 6. Backup / Restore

## Backup database:

```bash
pg_dump -U postgres labdb > labdb.sql
```

## Backup compressed:

```bash
pg_dump -U postgres -Fc labdb > labdb.backup
```

## Restore SQL:

```bash
psql -U postgres labdb < labdb.sql
```

## Restore custom:

```bash
pg_restore -U postgres -d labdb labdb.backup
```

---

# 7. Service management (Ubuntu)

## Status:

```bash
sudo systemctl status postgresql
```

## Start:

```bash
sudo systemctl start postgresql
```

## Stop:

```bash
sudo systemctl stop postgresql
```

## Restart:

```bash
sudo systemctl restart postgresql
```

---

# 8. Cluster management

## Show clusters:

```bash
pg_lsclusters
```

## Start cluster:

```bash
sudo pg_ctlcluster 16 main start
```

## Stop cluster:

```bash
sudo pg_ctlcluster 16 main stop
```

## Restart:

```bash
sudo pg_ctlcluster 16 main restart
```

---

# 9. Replication commands

## Check primary:

```sql
SELECT pg_is_in_recovery();
```

### Result:

```
false = Primary
true  = Replica
```

## Check replication status:

```sql
SELECT * FROM pg_stat_replication;
```

## Base backup:

```bash
sudo -u postgres pg_basebackup -h 192.168.26.3 -D /var/lib/postgresql/16/main -U replication_user -P -R -X stream
```

---

# 10. Performance / Monitoring

## Active sessions:

```sql
SELECT * FROM pg_stat_activity;
```

## Database sizes:

```sql
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database;
```

## Table sizes:

```sql
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

---

# 11. Maintenance

## Vacuum:

```sql
VACUUM;
```

## Analyze:

```sql
ANALYZE;
```

## Full vacuum:

```sql
VACUUM FULL;
```

## Reindex:

```sql
REINDEX DATABASE labdb;
```

---

# 12. Config files

## Main config:

```bash
sudo nano /etc/postgresql/16/main/postgresql.conf
```

## Authentication:

```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
```

## Reload config:

```bash
sudo systemctl reload postgresql
```

---

# 13. Logs

## Ubuntu:

```bash
sudo tail -f /var/log/postgresql/postgresql-16-main.log
```

---

# 14. Kill stuck query

## Find PID:

```sql
SELECT pid, query
FROM pg_stat_activity
WHERE state = 'active';
```

## Kill:

```sql
SELECT pg_terminate_backend(PID);
```

---

# 15. Networking

## Check listening:

```bash
ss -tulpn | grep 5432
```

## UFW:

```bash
sudo ufw allow 5432/tcp
```

---

# 16. Common troubleshooting

## Permission denied:

```bash
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
```

## Fix config:

```bash
sudo pg_conftool 16 main show
```

---

# DBeaver thực tế:

### Chạy query:

```sql
SELECT * FROM employees;
```

### Refresh tables:

- Right click DB → Refresh

---

# Quick DBA workflow:

```bash
sudo -u postgres psql
\l
\c labdb
\dt
SELECT * FROM employees;
```

---

# Debug mindset:

## Nếu PostgreSQL lỗi:

### 1. Service:

```bash
systemctl status postgresql
```

### 2. Port:

```bash
ss -tulpn | grep 5432
```

### 3. Logs:

```bash
tail -f /var/log/postgresql/postgresql-16-main.log
```

### 4. Config:

```bash
postgresql.conf
pg_hba.conf
```

---

