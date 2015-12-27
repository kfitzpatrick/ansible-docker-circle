Vagrant.configure(2) do |config|

    # ==> Choose a Vagrant box to emulate Linux distribution...
    config.vm.box = "williamyeh/ubuntu-trusty64-docker"

    config.vm.define "ansible-docker-test" do |machine|
      machine.vm.provider "virtualbox"
    end

    # ==> Executing Ansible...
    config.vm.provision "shell", inline: <<-SHELL
      cd /vagrant
      docker build -t test-box .
    SHELL

end


