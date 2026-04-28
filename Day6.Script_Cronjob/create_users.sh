#/bin/bash

# Script to create multiple users on Linux at the same time

# List of usernames to create (edit this array as needed)
USERNAMES=("user1" "user2" "user3" "user4")

for username in "${USERNAMES[@]}"; do
    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping."
    else
        # Create user without password and default home dir
        sudo useradd -m -s /bin/bash "$username"
        echo "Created user $username"
        # Optionally set a default password (uncomment and set accordingly)
        echo "$username:mypassword" | sudo chpasswd
    fi
done


# Run the script as a cron job
# crontab -e
# Add the following line to run the script every day at 12:00 AM
# 0 12 * * * /path/to/create_users.sh

# Check the cron job
# crontab -l

# Run the script manually
# bash create_users.sh  

