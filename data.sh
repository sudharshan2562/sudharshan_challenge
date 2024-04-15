#!/bin/bash

yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

touch /var/www/html/Index.html

cat > Index.html << EOF

<!DOCTYPE html>
<html>
  <head>
    <title>Hello World</title>
  </head>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>

EOF
