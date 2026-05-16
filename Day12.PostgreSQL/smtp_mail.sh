#!/bin/bash

#Create gmail app password for email sending
#https://myaccount.google.com/apppasswords?rapt=AEjHL4Pg_LFP4AZO1G2q2ZtJ-LLclAylOQlcm_0dR4a2ffoOglw71gsi2oCCadFoDdapD0Cr1qeydc5MhmOH0K_DJo4Anw3_7pFQ--EBjWlMBtaoTEBiAWM


#Postfix relay qua Gmail SMTP port 587
#Cài đặt Postfix
sudo apt update
sudo apt install postfix libsasl2-modules -y

#Cấu hình Postfix để sử dụng Gmail SMTP
sudo postconf -e "relayhost = [smtp.gmail.com]:587"
sudo postconf -e "smtp_tls_security_level = may"

#Cấu hình SASL để xác thực với Gmail SMTP
sudo nano /etc/postfix/main.cf

relayhost = [smtp.gmail.com]:587

smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt

#Tạo file sasl_passwd và thêm thông tin xác thực Gmail
echo "[smtp.gmail.com]:587 username@gmail.com password" | sudo tee /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd
sudo chmod 600 /etc/postfix/sasl_passwd.db

#Khởi động lại dịch vụ Postfix để áp dụng cấu hình
sudo systemctl restart postfix

#Test gửi mail
echo "Test mail from pg-master" | mail -s "Postfix Gmail relay test" yen.nguyenhoacat@gmail.com