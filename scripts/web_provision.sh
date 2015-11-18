#!/bin/sh
# reset locale to en_US
export LC_ALL=en_US
if [ -f "/var/vagrant_provision" ]; then
    exit 0
fi

echo "Provisioning web front end"

# install
rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/6/x86_64/zabbix-release-2.4-1.el6.noarch.rpm
yum install zabbix-web-pgsql.noarch -y

# configure
chkconfig --add httpd
chkconfig httpd on
sed -i "s/^;date.timezone =$/date.timezone = \"Europe\/Moscow\"/" /etc/php.ini |grep "^timezone" /etc/php.ini
iptables -I INPUT 1 -p tcp --dport 80 -j ACCEPT

# start
/etc/init.d/httpd start

touch /var/vagrant_provision
echo "Provisioning finished."
