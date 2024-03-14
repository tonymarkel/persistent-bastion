# Persistent Bastion #
A linux bastion service that allows for persistent and long-lived connections.

## What do I need? ##

* A host machine serving as your bastion running Oracle Linux 9
* A network connection from the source to the bastion host on port 22
* A network connection from the bastion host to the target service on the appropriate port
* (optional) - Log aggregation service like Splunk, Greylog, or Elastic

## How do I install it? ##

### Terraform for OCI ###

* Edit the persistent-bastion.tf file and replace the following with the appropriate values:
  * compartment_id = ocid
  * availability_domain = AD (e.g. rgiR:US-SANJOSE-1-AD-1)
  * source_id = ocid [use this list to find the image in your region](https://docs.oracle.com/en-us/iaas/images/image/097440c7-9304-4e02-9cc4-e0cc730cdf6a/)
  * subnet_id = ocid of public subnet
  * "ssh_authorized_keys" = "contents of ~/.ssh/id_rsa.pub, or other public key"

```
vi persistent-bastion.tf
terraform plan
terraform apply
```

### Existing Machine ### 
* Obtain a shell prompt on the bastion host with a user account with sudo access
* Execute the following command, then exit your shell.
```
curl https://github.com/tonymarkel/persistent-bastion/install.sh | sudo bash
```

## How do I use it? ##

```
ssh -i /path/to/private/key user@host
sudo add-bastion-user
```

Copy the private key in the terminal output and send securely to the end user.
Instruct the user to use the following in a terminal, powershell, or console window:

```
$ ssh -i <privateKey> -N -L <localport>:<Target FQDN or IP>:<remoteport> -p <remotePort> <bastion-user>@<bastion-host>
```

*snort*
For detailed configuration steps, consult the official Snort documentation:
https://snort.org/documents#OfficialDocumentation