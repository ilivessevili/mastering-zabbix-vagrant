#!/bin/sh
set -e

if [ -f "/var/vagrant_provision" ]; then
    exit 0
fi

DB_PASSWORD=$1

echo "Provisioning database"

iptables -F

cat <<'EOF' >> /etc/hosts
192.168.100.30 db01
192.168.100.31 db02
EOF

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
cat schema.sql | psql -v ON_ERROR_STOP=1 -h 192.168.100.30 -U zabbix zabbix_db
cat images.sql | psql -v ON_ERROR_STOP=1 -h 192.168.100.30 -U zabbix zabbix_db
cat data.sql | psql -v ON_ERROR_STOP=1 -h 192.168.100.30 -U zabbix zabbix_db

# TODO: this step is temporaty disabled, because the SQL script is buggy.
# get SQL script for db partitioning
# wget https://raw.githubusercontent.com/smartmarmot/Mastering_Zabbix/master/chapter1/PostgreSQL_Zabbix_Partitioning.sql -O /tmp/PostgreSQL_Zabbix_Partitioning.sql
# sudo -u postgres psql -v ON_ERROR_STOP=1 -d zabbix_db -a -f /tmp/PostgreSQL_Zabbix_Partitioning.sql

chkconfig --add postgresql-9.4
chkconfig postgresql-9.4 on
iptables -I INPUT 1 -p tcp --dport 5432 -j ACCEPT

# configure extended LVM filter
grep "^ *filter =" /etc/lvm/lvm.conf || sed -i 's/\(^\( *\)# filter = \[ "a\/\.\*\/" \]\)/\1\n\2filter = \["a|sd.*|", "a|drbd.*|", "r|.*|"\]/' /etc/lvm/lvm.conf
# turn off LVM cache
grep "write_cache_state = 0" /etc/lvm/lvm.conf || sed -i 's/write_cache_state = 1/write_cache_state = 0/' /etc/lvm/lvm.conf
rm -f /etc/lvm/cache/.cache

# rebuild initramfs for the current kernel version
dracut -f

# create LVM for drbd
pvcreate /dev/sdb
pvcreate /dev/sdc
vgcreate vgpgdata /dev/sdb /dev/sdc
lvcreate --name rpgdata0 --size 10G vgpgdata

# install drbd
rpm -Uvh http://www.elrepo.org/elrepo-release-6-6.el6.elrepo.noarch.rpm
yum -y install drbd84-utils kmod-drbd84

cat <<'EOF' > /etc/drbd.d/rpgdata0.res
resource rpgdata0 {
  device /dev/drbd0;
  disk /dev/vgpgdata/rpgdata0;
  meta-disk internal;
  on db01 { address 192.168.100.30:7788; }
  on db02 { address 192.168.100.31:7788; }
}
EOF

# disable drbd startup
chkconfig drbd off
# create drbd device
drbdadm create-md rpgdata0
# enable rpgdata0 resource
drbdadm up rpgdata0


# set this node primary
# This command can fail until resource on the second node in unvalidated,
# so here we loop until command will succseed.
n=0
until [ $n -ge 20 ]
do
  drbdadm primary rpgdata0 && break
  n=$[$n+1]
  echo [$n] Waiting for second instance to be available...
  sleep 15
done

if [ $n -ge 20 ]
then
  >&2 echo "Failed to set primary!"
  exit 101
fi

# create LVM ontop of DRBD
pvcreate /dev/drbd0
vgcreate secured_vg_pg /dev/drbd0
lvcreate -L 6G -n secured_lv_pg secured_vg_pg

# configure XFS file system
mkdir -p -m 0700 /db/pgdata
yum install -y xfsprogs
mkfs.xfs /dev/secured_vg_pg/secured_lv_pg
mount -t xfs -o noatime,nodiratime,attr2 /dev/secured_vg_pg/secured_lv_pg /db/pgdata
chown postgres:postgres /db/pgdata
chmod 0700 /db/pgdata

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

# configure
crm configure primitive drbd_pg ocf:linbit:drbd \
  params drbd_resource="rpgdata0" \
  op monitor interval="15" \
  op start interval="0" timeout="240" \
  op stop interval="0" timeout="120"

crm configure ms ms_drbd_pg drbd_pg \
  meta master-max="1" master-node-max="1" clone-max="2" \
  clone-node-max="1" notify="true"

crm configure primitive pg_lvm ocf:heartbeat:LVM \
  params volgrpname="secured_vg_pg" \
  op start interval="0" timeout="30" \
  op stop interval="0" timeout="30"

crm configure primitive pg_fs ocf:heartbeat:Filesystem \
  params device="/dev/secured_vg_pg/secured_lv_pg" directory="/db/pgdata" \
  options="noatime,nodiratime" fstype="xfs" \
  op start interval="0" timeout="60" \
  op stop interval="0" timeout="120"

crm configure primitive pg_lsb lsb:postgresql-9.4 \
  op monitor interval="30" timeout="60" \
  op start interval="0" timeout="60" \
  op stop interval="0" timeout="60"

crm configure primitive pg_vip ocf:heartbeat:IPaddr2 \
  params ip="192.168.124.3" iflabel="pgvip" \
  op monitor interval="5"

crm configure group PGServer pg_lvm pg_fs pg_lsb pg_vip
crm configure colocation col_pg_drbd inf: PGServer ms_drbd_pg:Master
crm configure order ord_pg inf: ms_drbd_pg:promote PGServer:start

touch /var/vagrant_provision
echo "Provisioning finished."
