# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# Hosts configuration parameters
WEB_HOST_IP = "192.168.100.20"
ZBX_HOST_IP = "192.168.100.10"
PG_HOST_IP  = "192.168.100.30"

DB_PASSWORD = 's3cr3t'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "puppetlabs/centos-6.6-64-nocm"

  config.vm.define :zabbix do |zabbix_config|
      zabbix_config.vm.host_name = "zabbix"
      zabbix_config.vm.network "private_network", ip:ZBX_HOST_IP
      zabbix_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      zabbix_config.vm.provision "shell", path: "scripts/zabbix_provision.sh", args: [DB_PASSWORD]
  end

  config.vm.define :web do |web_config|
      web_config.vm.host_name = "web"
      web_config.vm.network "private_network", ip:WEB_HOST_IP
      web_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      web_config.vm.provision "shell", path: "scripts/web_provision.sh"
  end

  config.vm.define :db do |db_config|
      db_config.vm.host_name = "db"
      db_config.vm.network "private_network", ip:PG_HOST_IP
      db_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      db_config.vm.provision "shell", path: "scripts/db_provision.sh", args: [DB_PASSWORD]
  end
end
