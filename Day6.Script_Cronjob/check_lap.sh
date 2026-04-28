#!/usr/bin/env bash

# ========================
# CONFIG
# ========================
BASIC_SCORE=0
ADV_SCORE=0
MAX_SCORE=5

PASS="[OK]"
FAIL="[FAIL]"

# ========================
# HELPER
# ========================
add_score() {
    local section=$1
    local point=$2

    if [ "$section" == "basic" ]; then
        BASIC_SCORE=$(echo "$BASIC_SCORE + $point" | bc)
    else
        ADV_SCORE=$(echo "$ADV_SCORE + $point" | bc)
    fi
}

print_result() {
    echo -e "$1 $2"
}

# ========================
# BASIC (2 điểm)
# ========================
echo "===== BASIC (2 điểm) ====="

# ---- 1. USER/GROUP (0.6)
echo "--- User & Group (0.6) ---"
for g in dev test admin; do
    if getent group "$g" > /dev/null; then
        print_result "$PASS" "Group $g exists"
        add_score basic 0.1
    else
        print_result "$FAIL" "Group $g missing"
    fi
done

for u in dev1 dev2 test1 admin1; do
    if id "$u" &>/dev/null; then
        print_result "$PASS" "User $u exists"
        add_score basic 0.075
    else
        print_result "$FAIL" "User $u missing"
    fi
done

# ---- 2. PERMISSION (0.8)
echo "--- Permission (0.8) ---"

check_perm() {
    local path=$1
    local expected_group=$2
    local expected_perm=$3
    local score=$4

    if [ -d "$path" ]; then
        group=$(stat -c %G "$path")
        perm=$(stat -c %a "$path")

        if [[ "$group" == "$expected_group" && "$perm" == "$expected_perm" ]]; then
            print_result "$PASS" "$path correct ($group:$perm)"
            add_score basic "$score"
        else
            print_result "$FAIL" "$path wrong ($group:$perm)"
        fi
    else
        print_result "$FAIL" "$path missing"
    fi
}

# dev: full access + setgid (2770)
check_perm ~/company/dev dev 2770 0.3

# test: read only (750)
check_perm ~/company/test test 750 0.2

# admin: full (770)
check_perm ~/company/admin admin 770 0.2

# shared: read for all (755)
check_perm ~/company/shared root 775 0.1

# ---- 3. SSH CONFIG (0.6)
echo "--- SSH Config (0.6) ---"

if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
    print_result "$PASS" "Root login disabled"
    add_score basic 0.3
else
    print_result "$FAIL" "Root login NOT disabled"
fi

#if sshd -T 2>/dev/null | grep -q "^passwordauthentication no"; then
#    print_result "$PASS" "Password auth disabled (effective config)"
#    add_score basic 0.3
#else
#    print_result "$FAIL" "Password auth enabled (effective config)"
#fi

if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
    print_result "$PASS" "Password auth disabled"
    add_score basic 0.3
else
    print_result "$FAIL" "Password auth enabled"
fi

# ========================
# ADVANCED (3 điểm)
# ========================
echo ""
echo "===== ADVANCED (3 điểm) ====="

# ---- Logging script (0.3)
if [ -x /usr/local/bin/write_log.sh ]; then
    print_result "$PASS" "Logging script OK"
    add_score adv 0.3
else
    print_result "$FAIL" "Logging script missing"
fi

# ---- ACL (0.8)
if getfacl ~/company/shared/app.log 2>/dev/null | grep -q "user:test1:r--"; then
    print_result "$PASS" "ACL test1 read-only"
    add_score adv 0.4
else
    print_result "$FAIL" "ACL test1 wrong"
fi

if getfacl ~/company/shared/app.log 2>/dev/null | grep -q "group:dev:rw-"; then
    print_result "$PASS" "ACL dev rw"
    add_score adv 0.4
else
    print_result "$FAIL" "ACL dev wrong"
fi

# ---- Backup + cron (1 điểm)
if [ -x /usr/local/bin/backup.sh ]; then
    print_result "$PASS" "Backup script OK"
    add_score adv 0.5
else
    print_result "$FAIL" "Backup script missing"
fi

if crontab -l 2>/dev/null | grep -q "backup.sh"; then
    print_result "$PASS" "Cron OK"
    add_score adv 0.5
else
    print_result "$FAIL" "Cron missing"
fi

# ---- Check script (0.3)
if [ -x /usr/local/bin/check_system.sh ]; then
    print_result "$PASS" "Check script exists"
    add_score adv 0.3
else
    print_result "$FAIL" "Check script missing"
fi

# ---- SSH hardening (0.3)
if grep -q "^allowgroups.*dev.*admin" /etc/ssh/sshd_config; then
    print_result "$PASS" "SSH restricted"
    add_score adv 0.6
else
    print_result "$FAIL" "SSH not restricted"
fi


# ========================
# FINAL
# ========================
TOTAL=$(echo "$BASIC_SCORE + $ADV_SCORE" | bc)

echo ""
echo "===== RESULT ====="
echo "Basic: $BASIC_SCORE / 2"
echo "Advanced: $ADV_SCORE / 3"
echo "TOTAL: $TOTAL / 5"

# Grade
if (( $(echo "$TOTAL >= 4.5" | bc -l) )); then
    echo "GRADE: EXCELLENT"
elif (( $(echo "$TOTAL >= 3.5" | bc -l) )); then
    echo "GRADE: GOOD"
elif (( $(echo "$TOTAL >= 2.5" | bc -l) )); then
    echo "GRADE: PASS"
else
    echo "GRADE: FAIL"
fi
