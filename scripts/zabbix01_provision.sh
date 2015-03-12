#!/bin/sh
set -e

if [ -f "/var/vagrant_provision" ]; then
    exit 0
fi

echo "Provisioning zabbix server"

DB_PASSWORD=$1

# install
rpm -ivh http://repo.zabbix.com/zabbix/2.4/rhel/6/x86_64/zabbix-release-2.4-1.el6.noarch.rpm
yum install zabbix-server-pgsql -y

# configure
sed -i "s/^# DBHost=localhost$/DBHost=192.168.100.30/" /etc/zabbix/zabbix_server.conf || grep "^DBHost" /etc/zabbix/zabbix_server.conf
sed -i "s/^DBName=zabbix$/DBName=zabbix_db/" /etc/zabbix/zabbix_server.conf || grep "^DBName" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPassword=\$/DBPassword=$DB_PASSWORD/" /etc/zabbix/zabbix_server.conf || grep "^DBPassword" /etc/zabbix/zabbix_server.conf
sed -i "s/^# DBPort=3306$/DBPort=5432/" /etc/zabbix/zabbix_server.conf || grep "^DBPort" /etc/zabbix/zabbix_server.conf

chkconfig --add zabbix-server
chkconfig zabbix-server on
iptables -I INPUT 1 -p tcp --dport 10051 -j ACCEPT

sed -i 's/^# ListenIP=0.0.0.0/ListenIP=10.10.1.9/' /etc/zabbix/zabbix_server.conf
sed -i 's/^# SourceIP=/SourceIP=10.10.1.9/' /etc/zabbix/zabbix_server.conf

# start
/etc/init.d/zabbix-server start

# configure corosync/pacemaker
yum install pacemaker corosync -y

cp /etc/corosync/corosync.conf.example /etc/corosync/corosync.conf

export MULTICAST_PORT=4000
export MULTICAST_ADDRESS=226.94.1.2
export BIND_NET_ADDRESS=`ip addr | grep "inet " |grep brd |tail -n1 | awk '{print $4}' | sed s/255/0/`

sed -i.bak "s/ *mcastaddr:.*/mcastaddr:\ $MULTICAST_ADDRESS/g" /etc/corosync/corosync.conf
sed -i.bak "s/ *mcastport:.*/mcastport:\ $MULTICAST_PORT/g" /etc/corosync/corosync.conf
sed -i.bak "s/ *bindnetaddr:.*/bindnetaddr:\ $BIND_NET_ADDRESS/g" /etc/corosync/corosync.conf

cat <<'EOF' > /etc/corosync/service.d/pcmk
service {
  # Load the Pacemaker Cluster Resource Manager
  name: pacemaker
  ver: 1
}
EOF

/etc/init.d/corosync start
/etc/init.d/pacemaker start

wget http://download.opensuse.org/repositories/network:/ha-clustering:/Stable/CentOS_CentOS-6/network:ha-clustering:Stable.repo -O /etc/yum.repos.d/etwork:ha-clustering:Stable.repo
yum install crmsh -y

crm configure property stonith-enabled="false"
crm configure property no-quorum-policy=ignore
crm configure property default-resource-stickiness="100"

crm configure primitive Zbxvip ocf:heartbeat:IPaddr2 \
  params ip="10.10.1.9" nic="eth1" cidr_netmask="24" \
  iflabel="httpvip" op monitor interval="5"
crm configure primitive Zabbix lsb::zabbix-server op monitor interval="5"
crm configure group Zbx_server Zbxvip Zabbix meta target-role="Started"
crm configure colocation Ip_Zabbix inf: Zbxvip Zabbix
crm configure order StartOrder inf: Zbxvip Zabbix

# TODO: this should be fixed, for now turn off firewall at all
iptables -F

touch /var/vagrant_provision
echo "Provisioning finished."
