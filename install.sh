#!/bin/sh

# persistent-bastion
# installer script

#Globals
export current_directory=$(pwd)
export snortpath=/usr/local/snort
export snortlog=/var/log/snort
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export ifname=$(nmcli connection show | grep System | awk '{print $2}')
export bastionIP=$(curl https://ipinfo.io/ip)

export motd=$(cat <<EOF
##  ###  ##  Persistent Bastion
 ###   ###   To add a bastion user:
  #     #    -----------------------
  #     #    $ sudo add-bastion-user
  #     #    -----------------------
 #       #   Copy the ssh Private Key and
###########  send securely to the user.
             
To use the bastion from a remote machine:
-----------------------------------------
$ ssh -i <privateKey> -N -L <localport>:<Target FQDN or IP>:<remoteport> -p <remotePort> <bastion-user>@$bastionIP
example:
ssh -i ~/.ssh/bastionKey.pem -N -L 1522:database.mydomain.net:1522 -p 22 acme@$bastionIP
-----------------------------------------
NOTE: Accounts are removed after 90 Days of inactivity.
EOF
)

export service=$(cat <<EOF
[Unit]
Description=Snort 3 Intrusion Detection and Prevention service
After=syslog.target network.target
[Service]
Type=simple
ExecStart=/usr/local/snort/bin/snort -c /usr/local/snort/etc/snort/snort.lua --plugin-path /usr/local/snort/extra -i $ifname -l /var/log/snort -D -u snort -g snort --create-pidfile -k none
ExecReload=/bin/kill -SIGHUP \$MAINPID
User=snort
Group=snort
Restart=on-failure
RestartSec=5s
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_IPC_LOCK
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_IPC_LOCK
[Install]
WantedBy=multi-user.target
EOF
)
export weeklycron=$(cat << EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root HOME=/
0 0 * * 0 yum update -y && reboot >/dev/null 2>&1
EOF
)

export dailycron=$(cat << EOF
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root HOME=/
30 12 * * * snort wget -qO- https://www.snort.org/downloads/community/snort3-community-rules.tar.gz | tar xz --overwrite --transform 's/snort3-community-rules\///g' -C $snortpath/etc/snort snort3-community-rules/snort3-community.rules snort3-community-rules/sid-msg.map
EOF
)

export delete_inactive_user=$(cat << EOF
#!/bin/bash
for user in $(ls /bastion/persistent-access); do
        is_old = $(sudo lastlog -b 90 -u $user)
        if [ ! $is_old ]; then
                echo "$user is current"
        else
                echo "$user is inactive"
                sudo userdel -f $user
        fi
done
EOF
)

function install_sshd {

    echo "Installing openssh-server"
    sudo dnf install -y openssh-server
    sudo systemctl enable sshd
    echo "Starting openssh-server"
    sudo systemctl start sshd

}

function install_snort {

    #Where to install snort?
    sudo mkdir -p $snortpath

    cd $current_directory

    sudo dnf update -y
    sudo dnf config-manager --enable ol9_developer --save
    sudo dnf config-manager --enable ol9_developer_EPEL --save
    sudo dnf config-manager --enable ol9_codeready_builder --save
    sudo dnf install perl libdnet-devel hwloc-devel luajit-devel libpcap-devel pcre-devel dh-autoreconf cmake -y

    wget https://github.com/snort3/libdaq/archive/refs/heads/master.zip
    mv master.zip libdaq.zip
    unzip -o libdaq.zip
    cd libdaq-master
    ./bootstrap
    # no idea why, but running bootstrap twice works
    ./bootstrap
    ./configure
    make
    sudo make install
    echo "/usr/local/lib" > libdaq.conf
    sudo mv libdaq.conf /etc/ld.so.conf.d/libdaq.conf
    sudo ldconfig

    cd $current_directory

    wget https://github.com/snort3/snort3/archive/refs/heads/master.zip
    mkdir -p $snortpath/etc
    mv master.zip snort.zip
    unzip -o snort.zip
    cd snort3-master
    ./configure_cmake.sh --prefix=$snortpath \
                       --with-daq-includes=/usr/local/include/ \
                       --with-daq-libraries=/usr/local/lib/
    cd build
    sudo make -j $(nproc) install
    sudo ldconfig
    sudo ln -s $snortpath/bin/snort /usr/sbin/snort
    sudo /usr/sbin/snort -V

}

function configure_snort {

    # get the latest rule sets
    sudo cd $snortpath
    echo $snortpath
    echo $(pwd)
    sudo wget -qO- https://www.snort.org/downloads/community/snort3-community-rules.tar.gz | sudo tar xz --overwrite --transform 's/snort3-community-rules\///g' -C $snortpath/etc/snort snort3-community-rules/snort3-community.rules snort3-community-rules/sid-msg.map
    echo "-- community rules" | sudo tee -a $snortpath/etc/snort/snort.lua
    echo "file_id = { rules_file = 'snort3-community.rules' }" | sudo tee -a $snortpath/etc/snort/snort.lua
    echo "file_policy = { }" | sudo tee -a $snortpath/etc/snort/snort.lua
    sudo snort -T -c $snortpath/etc/snort/snort.lua
    sudo chown -R snort:snort $snortpath
    sudo chown -R snort:snort $snortlog
    sudo chmod -R 5700 $snortlog

    # install snort as a service
    echo -e "$service" | sudo tee /etc/systemd/system/snort.service
    sudo systemctl daemon-reload
    sudo systemctl enable snort.service

    # install cron jobs to update snort community rules and linux every day
    echo -e "$dailycron" | sudo tee /etc/cron.d/snort-community-updates
    echo -e "$weeklycron" | sudo tee /etc/cron.d/bastion-os-updates

}

function install_fail2ban {

    sudo dnf erase denyhosts
    sudo dnf install fail2ban
    sudo systectl start fail2ban

}

function install_bastion_script {

    # bastion users
    sudo mkdir -p /bastion/persistent-access
    semanage fcontext -a -e /home /bastion/persistent-access
    restorecon -R /bastion/persistent-access
    sudo groupadd bastion
 
    # user management
    sudo echo -e "$delete_inactive_user" | sudo tee /etc/cron.daily/delete_inactive_users
    sudo chmod a+x /etc/cron.daily/delete_inactive_users

    # bastion program
    sudo mkdir -p /usr/local/persistent-bastion
    sudo wget https://raw.githubusercontent.com/tonymarkel/persistent-bastion/main/add-bastion-user --backups=1 -P /usr/sbin/
    sudo chmod a+x /usr/sbin/add-bastion-user
    sudo wget https://raw.githubusercontent.com/tonymarkel/persistent-bastion/main/persistent-bastion.py --backups-1 -P /usr/local/persistent-bastion/

    # motd
    sudo echo -e "$motd" | sudo tee -a /etc/motd

}

function main {

    # Add Snort User and Group
    echo "Adding snort user and group"
    sudo groupadd snort &> /dev/null
    id -u snort &>/dev/null || sudo useradd snort -r -M -g snort -s /sbin/nologin -c SNORT_SERVICE_ACCOUNT
    sudo mkdir -p $snortpath
    sudo mkdir -p $snortlog

    # Do we have sshd?
    if ! test -f /usr/sbin/sshd; then
        echo "installing sshd"
        install_sshd
    fi

    # Do we have snort?
    if ! test -f /usr/sbin/snort; then
        echo "no snort installed. Installing"
        install_snort
    else
        echo "ERROR: Previous install of Snort detected. Exiting."
        exit 1
    fi

    # Install fail2ban
    install_fail2ban

    # Configure Snort as IPS with community rules
    configure_snort

    # Install the user provisioning script
    install_bastion_script

    # Reboot
    echo "Installation Complete. Rebooting the system."
    sudo reboot

}

main