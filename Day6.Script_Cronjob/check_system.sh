#!/usr/bin/env bash

set -euo pipefail

PASS="[OK]"
FAIL="[FAIL]"

# ========================
# LIST TO CHECK
# ========================
GROUPS=("dev" "test" "admin")
USERS=("dev1" "dev2" "test1" "admin1" "test2")  # test2 cố tình để fail

# ========================
# CHECK GROUPS
# ========================
for g in "${GROUPS[@]}"; do
    if getent group "$g" > /dev/null 2>&1; then
        echo "$PASS Group $g exists"
    else
        echo "$FAIL Group $g missing"
    fi
done

# ========================
# CHECK USERS
# ========================
for u in "${USERS[@]}"; do
    if id "$u" > /dev/null 2>&1; then
        echo "$PASS User $u exists"
    else
        echo "$FAIL User $u missing"
    fi
done