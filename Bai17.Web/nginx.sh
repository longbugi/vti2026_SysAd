#!/bin/bash

#Install nginx web server
sudo apt update && sudo apt install nginx -y
systemctl status nginx

#Create a simple web page
sudo tee /var/www/html/index.html > /dev/null << EOF
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
</head>
<body>
<h1>Success! nginx is working!</h1>
</body>
</html>
EOF

#Create virtual host configuration file
sudo tee /etc/nginx/sites-available/company.conf > /dev/null << EOF
server {
    listen 80;
    server_name company.local;
    root /var/www/html;
    index index.html;
}
EOF
#Enable virtual host
sudo ln -s /etc/nginx/sites-available/company.conf /etc/nginx/sites-enabled
#Test nginx configuration
sudo nginx -t
#Reload nginx service
sudo systemctl reload nginx


