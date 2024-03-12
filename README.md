# Persistent Bastion #
A linux bastion service that allows for persistent and long-lived connections.

### What do I need? ###

* A host machine serving as your bastion running Oracle Linux 9
* A network connection from the source to the bastion host on port 22
* A network connection from the bastion host to the target service on the appropriate port
* (optional) - Log aggregation service like Splunk, Greylog, or Elastic

### How do I install it? ###

* Obtain a shell prompt on the bastion host with a user account with sudo access
* Execute the following command, then exit your shell.
```
curl https://github.com/tonymarkel/persistent-bastion/install.sh | sudo bash
```

### How do I use it? ###

*add-bastion-user*
execute add-bastion-user either through sudo or as root.

*snort*
For detailed configuration steps, consult the official Snort documentation:
https://snort.org/documents#OfficialDocumentation