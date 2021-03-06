#!/bin/sh
set -e

if [ -f "/var/vagrant_provision" ]; then
    exit 0
fi

DB_PASSWORD=$1

echo "Provisioning database"

# exclude postgres from default repository
pcregrep -q -M "\[base\]\nexclude=postgresql\*" /etc/yum.repos.d/CentOS-Base.repo || sed -i "s/^\[base\]$/\[base\]\nexclude=postgresql\*/" /etc/yum.repos.d/CentOS-Base.repo
pcregrep -q -M "\[updates\]\nexclude=postgresql\*" /etc/yum.repos.d/CentOS-Base.repo || sed -i "s/^\[updates\]$/\[updates\]\nexclude=postgresql\*/" /etc/yum.repos.d/CentOS-Base.repo

# install
yum install http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-centos94-9.4-1.noarch.rpm -y
yum install postgresql94 postgresql94-server postgresql94-contrib -y

# configure
service postgresql-9.4 initdb

pcregrep -q "^listen_addresses = '*'" /var/lib/pgsql/9.4/data/postgresql.conf || echo "listen_addresses = '*'" >> /var/lib/pgsql/9.4/data/postgresql.conf
pcregrep -q "^# configuration for Zabbix" /var/lib/pgsql/9.4/data/pg_hba.conf || echo -e "\n# configuration for Zabbix\nlocal\tzabbix_db\tzabbix\tmd5\nhost\tzabbix_db\tzabbix\t192.168.100.0/24\tmd5" >> /var/lib/pgsql/9.4/data/pg_hba.conf

# start postgresql database
/etc/init.d/postgresql-9.4 start

# create zabbix user
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null
sudo -u postgres psql -c "CREATE DATABASE zabbix_db WITH OWNER zabbix ENCODING='UTF8';" 2>/dev/null

# get zabbix source to import db schemes
wget http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/2.4.4/zabbix-2.4.4.tar.gz/download -O zabbix-2.4.4.tar.gz
tar -zxvf zabbix-2.4.4.tar.gz
cd zabbix-2.4.4/database/postgresql/

# add db password for non interactive script execution
echo "*:*:zabbix_db:zabbix:$DB_PASSWORD" > ~/.pgpass
chmod 600 ~/.pgpass

# import db schemes
cat schema.sql | psql -h 192.168.100.30 -U zabbix zabbix_db
cat images.sql | psql -h 192.168.100.30 -U zabbix zabbix_db
cat data.sql | psql -h 192.168.100.30 -U zabbix zabbix_db

# get SQL script for db partitioning
wget https://raw.githubusercontent.com/smartmarmot/Mastering_Zabbix/master/chapter1/PostgreSQL_Zabbix_Partitioning.sql -O /tmp/PostgreSQL_Zabbix_Partitioning.sql
sudo -u postgres psql -d zabbix_db -a -f /tmp/PostgreSQL_Zabbix_Partitioning.sql

chkconfig --add postgresql-9.4
chkconfig postgresql-9.4 on
iptables -I INPUT 1 -p tcp --dport 5432 -j ACCEPT

touch /var/vagrant_provision
echo "Provisioning finished."
