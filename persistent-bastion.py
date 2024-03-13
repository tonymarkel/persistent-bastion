# Persistent Bastion
# author: Tony Markel

# Import Core Modules
import os
import subprocess
import sys
import syslog

# Import Cryptography Modules
from cryptography.hazmat.primitives import (
    serialization as crypto_serialization
)
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.backends import (
    default_backend as crypto_default_backend
)

# defining defaults
base_dir = '/bastion/persistent-access/'
shell = '/bin/false'
private_key_file = 'id_rsa'
public_key_file = 'id_rsa.pub'
authorized_keys_file = 'authorized_keys'
group = 'bastion'


def abort_reset(user_name, home_dir):
    print("Failed to add user.")
    syslog.syslog(syslog.LOG_ERR, "Failed to add user.")
    subprocess.run(['userdel', user_name])
    subprocess.run(['rm -rf', home_dir])
    sys.exit(1)


def am_i_root():
    user_uid = os.getuid()
    if user_uid == 0:
        print('''
              \\^%//
              |. .|   I AM (G)ROOT!
            - \\ - / _
             \\_| |_/
               \\ \\
             __/_/__
            |_______|
             \\     /
              \\___/
        ''')
        add_bastion_user()
    else:
        print("Execution was not done with root privileges, aborting.")
        abort_reset("none", "none")


def create_firewall_rule( ip_addresses, customer_name, user_name, home_dir, tech ):
    customer_zone = "--zone=" + user_name
    zone = "--new-zone=" + user_name

    print(f'''

        Adding zone to the Bastion
        Zone: {user_name} for {customer_name}

    ''')

    subprocess.run(
        [
            'firewall-cmd', zone, '--permanent'
        ]
    )

    subprocess.run(
        [
            'firewall-cmd', '--add-service=ssh', customer_zone, '--permanent'
        ]
    )

    for ip_address in ip_addresses.split(","):
        
        source = "--add-source=" + ip_address
        try:
            # To Do : Investigate doing this with Python
            # https://www.mankier.com/5/firewalld.dbus
            print(f'''

                Adding IP to the Bastion
                {ip_address} for {customer_name} in zone {user_name} by {tech}

            ''')
            subprocess.run(
                [
                    'firewall-cmd', customer_zone, '--permanent', source
                ]
            )
            subprocess.run(['firewall-cmd', '--reload'])
        except BaseException:
            print(f'''

                Error adding {ip_address} for {user_name} by {tech}, aborting.

            ''')

            syslog.syslog(
                syslog.LOG_ERR,
                "Error adding " + ip_address + "for" +
                user_name + "by" + tech
            )

            abort_reset(user_name, home_dir)


def create_ssh_keypair(private, public, authorized):
    key = rsa.generate_private_key(
        backend=crypto_default_backend(),
        public_exponent=65537,
        key_size=4096
    )

    private_key = key.private_bytes(
        crypto_serialization.Encoding.PEM,
        crypto_serialization.PrivateFormat.PKCS8,
        crypto_serialization.NoEncryption()
    )

    public_key = key.public_key().public_bytes(
        crypto_serialization.Encoding.OpenSSH,
        crypto_serialization.PublicFormat.OpenSSH
    )

    generated_key = open(private, "wb")
    generated_key.write(private_key)
    generated_key.close()
    subprocess.run(['chmod', '600', private])
    generated_public_key = open(public, "wb")
    generated_public_key.write(public_key)
    generated_public_key.close()
    generated_authorized_keys = open(authorized, "wb")
    generated_authorized_keys.write(public_key)
    generated_authorized_keys.close()
    print()
    print("### SSH Private Key ###")
    with open(private, 'r') as f:
        print(f.read())
    print()
    print("### SSH Public Key ###")
    with open(public, 'r') as f:
        print(f.read())


def add_bastion_user():
    tech_login = subprocess.getoutput('logname')
    tech = str(tech_login)
    print("Creates a local bastion user for remote access.")
    user_name = input(
        "Enter the user name (ex: acme): "
    )

    print(f"Checking for user {user_name} in all directories")
    user_check = subprocess.run(['id', user_name], stdout=subprocess.DEVNULL)

    friendly_name = input(
        "Enter the Full Name (ex: Acme Corporation): "
    )

    ip_addresses = input(
        "Enter the allowed ip addresses. Separate each with a comma: "
    )

    # Debug: print(f"result: {user_check.returncode}")
    if user_check.returncode == 0:
        print(f"User {user_name} exists. Try again.")
        abort_reset()

    else:
        print(f"You Entered: {user_name}.")
        try:
            home_dir = base_dir + user_name
            ssh_dir = os.path.join(home_dir, '.ssh')
            print(f"Creating user {user_name}")
            # executing useradd command using subprocess module
            subprocess.run(['useradd', '-b', base_dir, '-s', shell, '-g', group, '-c', friendly_name, user_name])
            os.mkdir(home_dir)
            os.mkdir(ssh_dir, 0o700)
            private_key_location = os.path.join(ssh_dir, private_key_file)
            public_key_location = os.path.join(ssh_dir, public_key_file)
            authorized_keys_location = os.path.join(ssh_dir, authorized_keys_file)
            user_group = user_name + ':' + group
            print(f"Creating ssh keys for {user_name}")
            create_ssh_keypair(private_key_location, public_key_location, authorized_keys_location)
            subprocess.run(['chown', '-R', user_group, base_dir])
            create_firewall_rule(
                ip_addresses, friendly_name, user_name, home_dir, tech
            )
            print("Writing to the log and exiting safely.")
            syslog.syslog(
                syslog.LOG_INFO,
                "Bastion User Created for " + " " +
                friendly_name + " " +
                "by" + " " +
                tech)

        except BaseException:
            abort_reset(user_name, home_dir)


am_i_root()
