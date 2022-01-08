#!/bin/bash
yum install httpd -y
echo "$(hostname -f)" > /var/www/html/index.html
service httpd start
chkconfig httpd on
echo "You've successfully installed the http web server!"
