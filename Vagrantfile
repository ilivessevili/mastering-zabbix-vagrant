# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# Hosts configuration parameters
WEB01_HOST_IP = "192.168.100.20"
WEB02_HOST_IP = "192.168.100.21"
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

  config.vm.define :web01 do |web01_config|
      web01_config.vm.host_name = "web01"
      web01_config.vm.network "private_network", ip:WEB01_HOST_IP
      web01_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      web01_config.vm.provision "shell", path: "scripts/web01_provision.sh"
  end

  config.vm.define :web02 do |web02_config|
      web02_config.vm.host_name = "web02"
      web02_config.vm.network "private_network", ip:WEB02_HOST_IP
      web02_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      web02_config.vm.provision "shell", path: "scripts/web02_provision.sh"
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
