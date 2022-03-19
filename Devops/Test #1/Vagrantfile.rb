# -*- mode: ruby -*-

Vagrant.configure("2") do |config| #method do |varname| assigns method output to varname and creates a scope for it
    config.vm.define "workshop" do |workshop|
        
        #vm OS
        workshop.vm.box = "ubuntu/bionic64"
        workshop.vm.hostname = "workshop"

        #Vm networking
        workshop.vm.networking = "forwarded_port", guest; 8080, host_ip: "127.0.0.1"
        workshop.vm.networking = "forwarded_port", guest; 5000, host_ip: "127.0.0.1"
        workshop.vm.networking = "forwarded_port", guest; 10443, host_ip: "127.0.0.1"

        workshop.vm.networking "private_network", ip: "192.168.1.10"

        #Vm Hardware specs
        workshop.vm.provider "virtualbox" do |vb|
            vb.memory = 4000
            vb.cpus = 8
        end

        #Adding configurations
        #vm.provision "file" adds local files
        if File.exists?(File.expand_path("~/.gitconfig")) 
            workshop.vm.provision "file", source: "~/.gitconfig", destination "~/.gitconfig"
        end

        if File.exists?(File.expand_path("~/.ssh/id_rsa"))
            workshop.vm.provision "file", source: "~/.ssh/id_rsa", destination "~/.ssh/id_rsa"
        end

        if File.exists?(File.expand_path("~/.vimrc"))
            workshop.vm.provision "file", source: "~/.vimrc", destination "~/.vimrc"
        end

        workshop.vm.provision "shell", inline: <<-SHELL #runnin some shell commands ya feel homes
            # Update and install
            apt-get update
            apt-get install -y git tree wget build-essential python3-dev python3-pip python3-venv apt-transport-https
            apt-get upgrade python3
            # Create a Python3 Virtual Environment and Activate it in .profile
            sudo -H -u vagrant sh -c 'python3 -m venv ~/venv'
            sudo -H -u vagrant sh -c 'echo ". ~/venv/bin/activate" >> ~/.profile'
            sudo -H -u vagrant sh -c '. ~/venv/bin/activate && cd /vagrant && pip install -r requirements.txt'
            # Check versions to prove that everything is installed
            python3 --version
            # Install Visual Studio Code server
            # curl -fsSL https://code-server.dev/install.sh | sh
            # sudo systemctl enable --now code-server@vagrant
        SHELL

        workshop.vm.provision :docker do |d|
            d.pull_images "python:3.8-slim"
            d.pull_images "redis:6-alpine"
            d.run "redis:6-alpine",
              args: "-d --name redis -p 6379:6379 -v redis:/data"
        end
      
          ############################################################
          # Create a Kubernetes Cluster
          ############################################################
        workshop.vm.provision "shell", inline: <<-SHELL
            # snap install kubectl --classic
            snap install microk8s --classic
            microk8s.status --wait-ready
            microk8s.enable dns dashboard registry
            # microk8s.kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
            microk8s.enable ingress
            snap alias microk8s.kubectl kubectl
            usermod -a -G microk8s vagrant
            echo "alias mk='/snap/bin/microk8s'" >> /home/vagrant/.bash_aliases
            echo "alias kc='/snap/bin/kubectl'" >> /home/vagrant/.bash_aliases
            chown vagrant:vagrant /home/vagrant/.bash_aliases
            sudo -H -u vagrant sh -c 'mkdir ~/.kube && microk8s.kubectl config view --raw > ~/.kube/config'
            kubectl version --short
            # Install Helm
            # snap install helm --classic
            # helm version
            # helm repo add stable https://kubernetes-charts.storage.googleapis.com/
            # helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
            # helm repo add bitnami https://charts.bitnami.com/bitnami
            # helm repo update

            microk8s.config > /home/vagrant/.kube/config
            chown vagrant:vagrant /home/vagrant/.kube/config
            chmod 600 /home/vagrant/.kube/config
            SHELL

    end
end        
