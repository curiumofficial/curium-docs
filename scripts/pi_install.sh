#!/bin/bash

clear
cd ~
echo "███████████████████████████████████████████████████████████████████████████████"
echo "███████████████████░░   ░▒█████████████████████████▓░    ░▒████████████████████"
echo "██████████████████▓░      ░▓██████████████████████▒      ░░████████████████████"
echo "██████████████████▓░        ▒███████████████████▓░       ░▓████████████████████"
echo "██████████████████▓░         ░▓████████████████▒       ░░██████████████████████"
echo "██████████████████▓░     ░     ░▒███████████▓░      ░▒█████████████████████████"
echo "██████████████████▓░     ░░      ░▓████████▒       ░▓██████████████████████████"
echo "██████████████████▓░     ░▓█▓░      ░▒█▓░        ░░████████████████████████████"
echo "██████████████████▓░     ░▓███▒      ░░░      ░░▓██████████████████████████████"
echo "██████████████████▓░     ░▓████▒             ░▓████████████████████████████████"
echo "██████████████████▓░     ░▓█████▓░          ░██████████████████████████████████"
echo "██████████████████▓░     ░▓███████▒       ░▓███████████████████████████████████"
echo "██████████████████▓░     ░▓████████▓░   ░▒█████████████████████████████████████"
echo "██████████████████▓░     ░▓███████████▓▓███████████████████████████████████████"
echo "██████████████████▓░     ░▓████████████████████████████████████████████████████"
echo "██████████████████▓░     ░▓██████████████████████████▓▓▓▓▓█████████████████████"
echo "██████████████████▓░     ░▓█████████████████████████▓▓▓▓▓▓▓████████████████████"
echo "███████████████████▒     ▒███████████████████████████▓▓▓▓▓█████████████████████"
echo "█████████████████████▓▓▓███████████████████████████████████████████████████████"
echo && echo && echo
sleep 2

# Gather input from user
echo "Enter your Masternode Private Key"
read -e -p "(e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h) : " key
if [[ "$key" == "" ]]; then
    echo "WARNING: No private key entered, exiting!!!"
    echo && exit
fi
read -e -p "VPS Server IP Address and Masternode Port like IP:18745 : " ip
echo && sleep 3

# Add swap
        echo && echo "Adding swap space..."
        sleep 3
        cd /
        sudo dd if=/dev/zero of=swapfile bs=1M count=3000
        sudo mkswap swapfile
        sudo swapon swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf


# Update system 
echo && echo "Upgrading system..."
sleep 3
sudo apt-get -y update
sudo apt-get -y upgrade

# Add Berkely PPA
echo && echo "Installing bitcoin PPA..."
sleep 3
sudo apt-get -y install software-properties-common
sudo apt-add-repository -y ppa:bitcoin/bitcoin
sudo apt-get -y update

# Install required packages
echo && echo "Installing base packages..."
sleep 3
sudo apt-get -y install \
build-essential \
libtool \
autotools-dev \
automake \
joe \
unzip \
pkg-config \
libssl-dev \
bsdmainutils \
software-properties-common \
dh-autoreconf \
libzmq3-dev \
libevent-dev \
libboost-all-dev \
libboost-chrono-dev \
libboost-filesystem-dev \
libboost-program-options-dev \
libboost-system-dev \
libboost-test-dev \
libboost-thread-dev \
protobuf-compiler \
libprotobuf-dev \
libdb++-dev \
libdb-dev \
libminiupnpc-dev \
python-virtualenv 

# Install firewall if needed
    echo && echo "Installing UFW..."
    sleep 3
    sudo apt-get -y install ufw
    echo && echo "Configuring UFW..."
    sleep 3
    sudo ufw allow ssh
    sudo ufw allow 11771/tcp
    sudo ufw allow 18745/tcp
    echo "y" | sudo ufw enable
    echo && echo "Firewall installed and enabled!"

# Create config for curium
echo && echo "Putting The Gears Curium..."
sleep 3
sudo mkdir /root/.curiumcore #jm

rpcuser=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
rpcpassword=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1`
sudo touch /root/.curiumcore/curium.conf
echo '
rpcuser='$rpcuser'
rpcpassword='$rpcpassword'
rpcallowip=127.0.0.1
listen=1
server=1
rpcport=11771
daemon=0 # required for systemd
logtimestamps=1
maxconnections=256
externalip='$ip'
masternodeprivkey='$key'
masternode=1
' | sudo -E tee /root/.curiumcore/curium.conf


#Download pre-compiled curium and run
mkdir curium 
mkdir curium/src
cd curium/src
wget https://github.com/curiumcrypto/curium/releases/download/v0.1.2/curium-v0.1.2-arm.zip
unzip curium-v0.1.2-arm.zip
chmod +x curiumd
chmod +x curium-cli
chmod +x curium-tx

# Move binaries do lib folder
sudo mv curium-cli /usr/bin/curium-cli
sudo mv curium-tx /usr/bin/curium-tx
sudo mv curiumd /usr/bin/curiumd

#run daemon
curiumd -daemon

sleep 10

# Download and install sentinel
echo && echo "Installing Sentinel..."
sleep 3
cd
sudo apt-get install python-dev
curl -O https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install virtualenv
sudo git clone https://github.com/curiumcrypto/sentinel.git /root/sentinel
cd /root/sentinel
virtualenv venv
. venv/bin/activate
pip install -r requirements.txt
export EDITOR=nano
(crontab -l -u root 2>/dev/null; echo '* * * * * cd /root/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1') | sudo crontab -u root -

# Create a cronjob for making sure curiumd runs after reboot
if ! crontab -l | grep "@reboot curiumd -daemon"; then
  (crontab -l ; echo "@reboot curiumd -daemon") | crontab -
fi

# cd to curium-cli for final, no real need to run cli with commands as service when you can just cd there
echo && echo "Curium Masternode Setup Complete!"

echo "If you put correct PrivKey and VPS IP the daemon should be running."
echo "Wait 2 minutes then run curium-cli getinfo to check blocks."
echo "When fully synced you can start ALIAS on local wallet and finally check here with curium-cli masternode status."
echo && echo
