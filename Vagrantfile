# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

# Hosts configuration parameters
WEB01_HOST_IP = "192.168.100.20"
WEB02_HOST_IP = "192.168.100.21"
ZBX01_HOST_IP = "192.168.100.10"
ZBX02_HOST_IP = "192.168.100.11"
DB01_HOST_IP  = "192.168.100.30"
DB02_HOST_IP  = "192.168.100.31"

DB_PASSWORD = 's3cr3t'

VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))
db01_disk01 = File.join(VAGRANT_ROOT, 'hdd/db01_disk01.vdi')
db01_disk02 = File.join(VAGRANT_ROOT, 'hdd/db01_disk02.vdi')

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "puppetlabs/centos-6.6-64-nocm"

  config.vm.define :zabbix01 do |zabbix01_config|
      zabbix01_config.vm.host_name = "zabbix01"
      zabbix01_config.vm.network "private_network", ip:ZBX01_HOST_IP
      zabbix01_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      zabbix01_config.vm.provision "shell", path: "scripts/zabbix01_provision.sh", args: [DB_PASSWORD]
  end

  config.vm.define :zabbix02 do |zabbix02_config|
      zabbix02_config.vm.host_name = "zabbix02"
      zabbix02_config.vm.network "private_network", ip:ZBX02_HOST_IP
      zabbix02_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
      end
      zabbix02_config.vm.provision "shell", path: "scripts/zabbix02_provision.sh", args: [DB_PASSWORD]
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

  config.vm.define :db01 do |db01_config|
      db01_config.vm.host_name = "db01"
      db01_config.vm.network "private_network", ip:DB01_HOST_IP
      db01_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
          unless File.exist?(db01_disk01)
              vb.customize ['createhd', '--filename', db01_disk01, '--size', 10 * 1024]
          end
          vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', db01_disk01]

          unless File.exist?(db01_disk02)
              vb.customize ['createhd', '--filename', db01_disk02, '--size', 20 * 1024]
          end
          vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 1, '--type', 'hdd', '--medium', db01_disk02]

      end
      db01_config.vm.provision "shell", path: "scripts/db01_provision.sh", args: [DB_PASSWORD]
  end

  config.vm.define :db02 do |db02_config|
      db02_config.vm.host_name = "db02"
      db02_config.vm.network "private_network", ip:DB02_HOST_IP
      db02_config.vm.provider :virtualbox do |vb|
          vb.customize ["modifyvm", :id, "--memory", "256"]
          vb.customize ["modifyvm", :id, "--cpus", "1"]
          unless File.exist?(db02_disk01)
              vb.customize ['createhd', '--filename', db02_disk01, '--size', 10 * 1024]
          end
          vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', db02_disk01]

          unless File.exist?(db02_disk02)
              vb.customize ['createhd', '--filename', db02_disk02, '--size', 20 * 1024]
          end
          vb.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 1, '--type', 'hdd', '--medium', db02_disk02]

      end
      db02_config.vm.provision "shell", path: "scripts/db02_provision.sh", args: [DB_PASSWORD]
  end
end
