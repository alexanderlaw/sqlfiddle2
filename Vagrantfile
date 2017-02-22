# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

# for aws provisioning, this assumes you have configured your aws provider elsewhere (~/.vagrant.d/Vagrantfile is a good choice)
# example of that config:
#
#Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
#
#  config.vm.provider "aws" do |aws, override|
#    aws.access_key_id = "YourAccessKeyId"
#    aws.secret_access_key = "YourSecretAccessKey"
#
#    aws.ami = "ami-29ebb519" #Ubuntu trusty 64bit (public)
#    aws.region = "us-west-2"
#    aws.availability_zone = "us-west-2b"
#    aws.instance_type = "t2.small"
#    aws.associate_public_ip = true
#    aws.subnet_id = "subnet-99999999"
#    aws.security_groups = "sg-99999999"
#    aws.keypair_name = "sqlfiddle2.pem"
#
#    override.vm.box = "dummy"
#    override.ssh.username = "ubuntu"
#    override.ssh.private_key_path = "/path/to/pem.pem"
#  end
#
#end


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.provider "aws" do |aws, override|
      override.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: [".vagrant/", ".git/", "target/", "node_modules/"]
  end

  config.vm.define "postgresql95" do |pg|
    pg.vm.provision :shell, :path => "vagrant_scripts/pg_bootstrap.sh", :args => ["9.5", ENV["LANG"]]
    pg.vm.provision :shell, :inline => 'echo "0 */4 * * *       service postgresql restart 2>&1" | crontab'

    pg.vm.box = "ubuntu/xenial64"
    pg.vm.network "private_network", ip: "10.0.0.95"

    pg.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      v.customize ["storagectl", :id, "--name", "SCSI", "--hostiocache", "on"]
    end

    pg.vm.provider "aws" do |aws, override|
      aws.instance_type = "t2.micro"
      aws.private_ip_address = "10.0.0.95"
    end
  end

  config.vm.define "postgresql96" do |pg|
    pg.vm.provision :shell, :path => "vagrant_scripts/pg_bootstrap.sh", :args => ["9.6", ENV["LANG"]]
    pg.vm.provision :shell, :inline => 'echo "0 */4 * * *       service postgresql restart 2>&1" | crontab'

    pg.vm.box = "ubuntu/xenial64"
    pg.vm.network "private_network", ip: "10.0.0.96"

    pg.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      v.customize ["storagectl", :id, "--name", "SCSI", "--hostiocache", "on"]
    end

    pg.vm.provider "aws" do |aws, override|
      aws.instance_type = "t2.micro"
      aws.private_ip_address = "10.0.0.96"
    end
  end

  config.vm.define "postgrespro96" do |pg|
    pg.vm.provision :shell, :path => "vagrant_scripts/pgpro_bootstrap.sh", :args => ["9.6", ENV["LANG"]]
    pg.vm.provision :shell, :inline => 'echo "0 */4 * * *       service postgresql restart 2>&1" | crontab'

    pg.vm.box = "ubuntu/xenial64"
    pg.vm.network "private_network", ip: "10.0.0.196"

    pg.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      v.customize ["storagectl", :id, "--name", "SCSI", "--hostiocache", "on"]
    end

    pg.vm.provider "aws" do |aws, override|
      aws.instance_type = "t2.micro"
      aws.private_ip_address = "10.0.0.196"
    end
  end

  config.vm.define "postgresproee96" do |pg|
    pg.vm.provision :shell, :path => "vagrant_scripts/private/pgproee_bootstrap.sh", :args => ["9.6", ENV["LANG"]]
    pg.vm.provision :shell, :inline => 'echo "0 */4 * * *       service postgresql restart 2>&1" | crontab'

    pg.vm.box = "ubuntu/xenial64"
    pg.vm.network "private_network", ip: "10.0.0.206"

    pg.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      v.customize ["storagectl", :id, "--name", "SCSI", "--hostiocache", "on"]
    end

    pg.vm.provider "aws" do |aws, override|
      aws.instance_type = "t2.micro"
      aws.private_ip_address = "10.0.0.206"
    end
  end

  config.vm.define "postgrespro96-beta", autostart: false do |pg|
    pg.vm.provision :shell, :path => "vagrant_scripts/pgpro_bootstrap.sh", :args => ["9.6-beta", ENV["LANG"]]
    pg.vm.provision :shell, :inline => 'echo "0 */4 * * *       service postgresql restart 2>&1" | crontab'

    pg.vm.box = "ubuntu/xenial64"
    pg.vm.network "private_network", ip: "10.0.0.197"

    pg.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      v.customize ["storagectl", :id, "--name", "SCSI", "--hostiocache", "on"]
    end

    pg.vm.provider "aws" do |aws, override|
      aws.instance_type = "t2.micro"
      aws.private_ip_address = "10.0.0.197"
    end
  end

  config.vm.define "appdb1" do |appdb1|
    appdb1.vm.provider "aws" do |aws, override|
      aws.private_ip_address = "10.0.0.16"
      aws.block_device_mapping = [{
        'VirtualName' => "postgresql_data",
        'DeviceName' => '/dev/sda1',
        'Ebs.VolumeSize' => 50,
        'Ebs.DeleteOnTermination' => true,
        'Ebs.VolumeType' => 'io1',
        'Ebs.Iops' => 500
      }]

      override.vm.provision :shell, :path => "vagrant_scripts/appdb_aws.sh"
    end

    appdb1.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
    end

    appdb1.vm.provision :shell, :path => "vagrant_scripts/pg_bootstrap.sh", :args => ["9.6", ENV["LANG"]]
    appdb1.vm.provision :shell, :path => "vagrant_scripts/appdb_bootstrap.sh"
    appdb1.vm.box = "ubuntu/xenial64"
    appdb1.vm.network "private_network", ip: "10.0.0.16"
  end

  config.vm.define "idm", primary: true do |idm|

    idm.vm.box = "ubuntu/xenial64"
    idm.vm.network "private_network", ip: "10.0.0.14"
    idm.vm.network "forwarded_port", guest: 8080, host: 18080
    idm.vm.network "forwarded_port", guest: 6081, host: 6081

    idm.vm.provider "aws" do |aws, override|
      aws.private_ip_address = "10.0.0.14"
      override.vm.provision :shell, :path => "vagrant_scripts/idm_aws.sh"

      # reboot instance every day at 4am server time
      override.vm.provision :shell, :inline => 'echo "0 4 * * *       /root/reboot-clean.sh >> /root/reboot.out 2>&1" | crontab'
    end

    idm.vm.provider "virtualbox" do |v, override|
      v.customize ["modifyvm", :id, "--nictype1", "virtio", "--nictype2", "virtio", "--chipset", "ich9", "--uartmode1", "disconnected"]
      override.vm.provision :shell, path: "vagrant_scripts/idm_startup.sh", run: "always"
    end

    idm.vm.provision :shell, path: "vagrant_scripts/idm_prep.sh", :args => [ENV["LANG"]]
    idm.vm.provision :shell, path: "vagrant_scripts/idm_build.sh"
    idm.vm.provision :shell, :inline => "cp /vagrant/src/main/resources/conf/boot/boot.node1.properties /vagrant/target/sqlfiddle/conf/boot/boot.properties"

  end

  config.vm.define "idm2", autostart: false do |idm2|

    idm2.vm.box = "ubuntu/xenial64"
    idm2.vm.network "private_network", ip: "10.0.0.24"
    idm2.vm.network "forwarded_port", guest: 8080, host: 28080

    idm2.vm.provision :shell, path: "vagrant_scripts/idm_prep.sh"

    idm2.vm.provider "aws" do |aws, override|
      aws.private_ip_address = "10.0.0.24"

      # In aws, we can reuse the build output from the main idm box, since everything is local to each machine. So we have to build again:
      override.vm.provision :shell, path: "vagrant_scripts/idm_build.sh"

      override.vm.provision :shell, :inline => "cp /vagrant/src/main/resources/conf/boot/boot.node2.properties /vagrant/target/sqlfiddle/conf/boot/boot.properties"
      override.vm.provision :shell, :inline => "cp /vagrant/target/sqlfiddle/bin/openidm /etc/init.d"
      override.vm.provision :shell, :path => "vagrant_scripts/idm_aws.sh"

      # reboot instance every day at 3am server time
      override.vm.provision :shell, :inline => 'echo "0 3 * * *       /root/reboot-clean.sh >> /root/reboot.out 2>&1" | crontab'
    end

    idm2.vm.provider "virtualbox" do |v, override|

      # when running virtualbox, we can use the built target from the main idm box to skip having to build it for this one
      # however, we don't want them to be shared when running, as that could cause conflicts with logs and what-not. A copy is best, so we just rsync:
      override.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"

      v.memory = 1024
      override.vm.provision :shell, :inline => "cp /vagrant/src/main/resources/conf/boot/boot.node2.properties /vagrant/target/sqlfiddle/conf/boot/boot.properties"
      override.vm.provision :shell, :inline => "cp /vagrant/target/sqlfiddle/bin/openidm /etc/init.d"
      override.vm.provision :shell, path: "vagrant_scripts/idm_startup.sh", run: "always"
    end

  end

end
