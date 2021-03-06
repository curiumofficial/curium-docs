#!/bin/bash

clear
cd ~
echo "          _____          "
echo "         /\    \         "
echo "        /::\    \        "
echo "       /::::\    \       "
echo "      /::::::\    \      "
echo "     /:::/\:::\    \     "
echo "    /:::/  \:::\    \    "
echo "   /:::/    \:::\    \   "
echo "  /:::/    / \:::\    \  "
echo " /:::/    /   \:::\    \ "
echo "/:::/____/     \:::\____\ "
echo "\:::\    \      \::/    / "
echo " \:::\    \      \/____/"
echo "  \:::\    \            "
echo "   \:::\    \           "
echo "    \:::\    \         "
echo "     \:::\    \        "
echo "      \:::\    \        "
echo "       \:::\____\        "
echo "        \:::\    \        "
echo "         \::/    /     "
echo "          \/____/           "
echo && echo && echo
sleep 2

# Check if is root
if [ "$(whoami)" != "root" ]; then
  echo "Script must be run as user: root"
  exit -1
fi

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04 (Xenial)?"  >&2; exit 1; }

# Gather input from user
KEY=$1
if [ "$KEY" == "" ]; then
    echo "Enter your Masternode Private Key"
    read -e -p "(e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h) : " KEY
    if [[ "$KEY" == "" ]]; then
        echo "WARNING: No private key entered, exiting!!!"
        echo && exit
    fi
fi
IP=$(curl http://icanhazip.com --ipv4)
PORT="18745"
if [[ "$IP" == "" ]]; then
    read -e -p "VPS Server IP Address: " IP
fi
echo "Your IP and Port is $IP:$PORT"
if [ -n "$3" ]; then
    echo "Saving IP"
    DOCUMENTID=$(curl https://us-central1-curium-masternode-installer.cloudfunctions.net/saveIp?ip=$IP)
    echo "Your DocumentId is $DOCUMENTID"
fi
if [ -z "$2" ]; then
echo && echo "Pressing ENTER will use the default value for the next prompts."
    echo && sleep 3
    read -e -p "Add swap space? (Recommended) [Y/n] : " add_swap
fi
if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
    if [ -z "$2" ]; then
        read -e -p "Swap Size [2G] : " swap_size
    fi
    if [[ "$swap_size" == "" ]]; then
        swap_size="2G"
    fi
fi
if [ -z "$2" ]; then
    read -e -p "Install Fail2ban? (Recommended) [Y/n] : " install_fail2ban
    read -e -p "Install UFW and configure ports? (Recommended) [Y/n] : " UFW
fi

# Add swap if needed
if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
    if [ -n "$3" ]; then
        curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=2"
    fi

    if [ ! -f /swapfile ]; then
        echo && echo "Adding swap space..."
        sleep 3
        sudo fallocate -l $swap_size /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
        echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
    else
        echo && echo "WARNING: Swap file detected, skipping add swap!"
        sleep 3
    fi
fi


# Update system 
echo && echo "Upgrading system..."
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=3"
fi
sleep 3
sudo apt-get -y update
sudo apt-get -y upgrade

# Install required packages
echo && echo "Installing base packages..."
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=4"
fi
sleep 3
sudo apt-get -y install \
unzip \
python-virtualenv 

# Install fail2ban if needed
if [[ ("$install_fail2ban" == "y" || "$install_fail2ban" == "Y" || "$install_fail2ban" == "") ]]; then
    if [ -n "$3" ]; then
        curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=5"
    fi

    echo && echo "Installing fail2ban..."
    sleep 3
    sudo apt-get -y install fail2ban
    sudo service fail2ban restart 
fi

# Install firewall if needed
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
    if [ -n "$3" ]; then
        curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=6"
    fi

    echo && echo "Installing UFW..."
    sleep 3
    sudo apt-get -y install ufw
    echo && echo "Configuring UFW..."
    sleep 3
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 11771/tcp
    sudo ufw allow 18745/tcp
    echo "y" | sudo ufw enable
    echo && echo "Firewall installed and enabled!"
fi

# Create config for curium
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=7"
fi
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
externalip='$IP:$PORT'
masternodeprivkey='$KEY'
masternode=1
' | sudo -E tee /root/.curiumcore/curium.conf


#Download pre-compiled curium and run
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=8"
fi
mkdir curium 
mkdir curium/src
cd curium/src
#Select OS architecture
    if [ `getconf LONG_BIT` = "64" ]
        then
            wget https://github.com/curiumofficial/curium/releases/download/v1.0.1/curium-1.0.1-x86_64-linux-gnu.tar.gz
            unzip tar -xzf curium-1.0.1-x86_64-linux-gnu.tar.gz
    else
        wget https://github.com/curiumofficial/curium/releases/download/v1.0.1/curium-1.0.1-i686-pc-linux-gnu.tar.gz
        unzip tar -xzf curium-1.0.1-i686-pc-linux-gnu.tar.gz
    fi
chmod +x curium-1.0.1/bin/curiumnd
chmod +x curium-1.0.1/bin/curiumn-cli
chmod +x curium-1.0.1/bin/curiumn-tx

# Move binaries do lib folder
sudo mv curium-1.0.1/bin/curiumn-cli /usr/bin/curiumn-cli
sudo mv curium-1.0.1/bin/curiumn-tx /usr/bin/curiumn-tx
sudo mv curium-1.0.1/bin/curiumnd /usr/bin/curiumnd

#run daemon
curiumnd -daemon -datadir=/root/.curiumcru

TOTALBLOCKS=$(curl http://explorer.curiumofficial.com//api/getblockcount)

sleep 10


# Create a cronjob for making sure curiumd runs after reboot
if ! crontab -l | grep "@reboot curiumd -daemon"; then
  (crontab -l ; echo "@reboot curiumd -daemon") | crontab -
fi

# cd to curium-cli for final, no real need to run cli with commands as service when you can just cd there
echo && echo "Curium Masternode Setup Complete!"
echo && echo "Now we will wait until the node get full sync."

COUNTER=0
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=10"
fi
while [ $COUNTER -lt $TOTALBLOCKS ]; do
    echo The current progress is $COUNTER/$TOTALBLOCKS
    let COUNTER=$(curium-cli -datadir=/root/.curiumcru getblockcount)
    sleep 5
done
echo "Sync complete"
if [ -n "$3" ]; then
    curl "https://us-central1-curium-masternode-installer.cloudfunctions.net/step?id=${DOCUMENTID}&step=11"
fi

echo && echo "If you put correct PrivKey and VPS IP the daemon should be running."
echo "Now you can start ALIAS on local wallet and finally check here with curiumn-cli masternode status."
echo && echo
