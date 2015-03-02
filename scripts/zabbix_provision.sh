#!/bin/sh

echo "Provisioning zabbix server"

# install
rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/6/x86_64/zabbix-release-2.4-1.el6.noarch.rpm
yum install zabbix-server-pgsql -y

# configure
sed -i "s/^# DBHost=localhost$/DBHost=192.168.100.30/" /etc/zabbix/zabbix_server.conf | grep "^DBHost" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBName=zabbix$/DBName=zabbix_db/" /etc/zabbix/zabbix_server.conf | grep "^DBName" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=$/DBPassword=s3cr3t/" /etc/zabbix/zabbix_server.conf | grep "^DBPassword" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPort=3306$/DBPort=5432/" /etc/zabbix/zabbix_server.conf | grep "^DBPort" /etc/zabbix/zabbix_server.conf

chkconfig --add zabbix-server
chkconfig zabbix-server on
iptables -I INPUT 1 -p tcp --dport 10051 -j ACCEPT

# start
/etc/init.d/zabbix-server start
echo "Provisioning finished."
