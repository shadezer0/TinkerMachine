+++
title = "Secure a public server"
date = "2022-04-24T18:45:00+05:30"
tags = ["reference","self-hosting"]
description = "Secure a public Ubuntu server"
+++

As mentioned in my previous post, I've setup [Tailscale](tailscale.com/) to connect to all my devices without going through any arduous VPN setup processes. In my opinion, the biggest features of Tailscale are:

1. Ease of managing and adding new devices.
2. No need to open/ forward any ports even behind a NAT (this has to be [magic](https://tailscale.com/blog/how-nat-traversal-works/)).
3. <cite>[Exit-nodes](https://tailscale.com/kb/1103/exit-nodes/) and [subnet routers](https://tailscale.com/kb/1019/subnets/) functionality[^1].</cite>  
4. No need to remember IPs anymore with [MagicDNS](https://tailscale.com/kb/1081/magicdns/). 

[^1]: Think of exit nodes like consumer VPNs that can mask your public IP address. Subnet routers are a way to connect to devices on the network which don't necessarily have Tailscale installed on them.

After thinking about it for a bit, I also wanted to keep my internet traffic private. This can be done by using a public Ubuntu server hosted on a DigitalOcean droplet as my VPN exit node, easily configured through Tailscale.

After provisioning a new droplet, security is of the highest importance since this server is exposed to the world unlike your LAN network which sits behind router firewall and also implements a [NAT](https://www.wikiwand.com/en/Network_address_translation).

The measures provided here were inspired after a quick glance into all the failed login attempts (check /var/log/auth.log) to the newly created server in just a couple of hours. 

To be honest, implementing authenticaion through SSH keys alone would secure the server to a reasonable extent. A lot of this was motivated by experimentation and learning the various ways by which we can prevent unwanted access. 

The aim is to lower the surface area of any potential attack as much as possible. Therefore, all these methods are not absolutely required and incorporating just one of them significantly reduces the chances of a malicious actor gaining access.

1. Change from default root user.
2. Change SSH port.
3. Allow traffic only from the Tailscale network.

### Pre-requisites
**1. SSH key-based authentication**  
While setting up the DigitalOcean droplet, select SSH key-based authentication instead of a password. This is an essential necessity that prohibits most unwanted access.

More info on setting up SSH keys on Ubuntu: https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys-on-ubuntu-20-04

Also ensure in the `/etc/ssh/sshd_config` file the *PasswordAuthentication* directive is set to "no" to disable password based login attempts altogether.

**2. Enable Firewall**  
On Ubuntu, we can use *ufw* (Uncomplicated Firewall) which comes prepackaged on a default installation. 

```bash
# Create rule to allow only SSH connections
sudo ufw allow 22/tcp

# Enable ufw if it isn't already
sudo ufw enable

# Restrict all incoming traffic by default
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Reload ufw to pick up changed configuration
sudo ufw reload

# Check the status
sudo ufw status
```

Make sure that while listing the ufw status, there's no other rules than what's absolutely necessary. Anytime a new port needs to be exposed to the public internet, we will need to explicitly add a new allow rule.

**3. Install Tailscale**  
Check [this link](https://tailscale.com/kb/1039/install-ubuntu-2004/) to install Tailscale on an Ubuntu server.

### 1. Change to non-root user

Create another user and give it sudo privileges. Login to the server with this new user. Also remember to disable SSH login by the root user.

Automated login attempts on the internet use common users like pi, admin and root. Changing to any other default user and disabling root would make their jobs much harder. 

```bash
# creates a new user called "myuser"
useradd myuser

# set password for myuser
passwd myuser

# disable SSH login through root user
sudo vim /etc/ssh/sshd_config
# ...
# Uncomment and change value to no
 PermitRootLogin no
# ...

# Reload SSH daemon to pick up changes
sudo systemctl reload sshd
```

Login to the server with `ssh myuser@<server-ip>`.

### 2. Change SSH port

By default, SSH traffic happens over 22/tcp. We can reduce a significant number of unwanted login attempts by changing this port to a non-standard one. Choose a port number above 1024 to avoid using a port mapped to another service.

```bash
sudo vim /etc/ssh/sshd_config
# Change this value to the required port
# Port 1234

sudo systemctl reload sshd
```
Now, we'll need to make some modifications to the firewall rules.

```bash
# Delete old rule for standard SSH port
sudo ufw delete 22/tcp

# Create new rule to allow SSH traffic from new port
sudo ufw allow 1234/tcp

# Reload ufw to pick up changes
sudo ufw reload
```
You can validate access to the port using https://portchecker.co/.

Login with `ssh -p 1234 myuser@<server-ip>`.

In order to avoid providing the port each time to the `ssh` command, a simple solution would be to set up a `~/.ssh/config` file like:

```
Host remoteserver
  HostName <server-ip>
  User myuser
  Port 1234
  IdentityFile ~/.ssh/vpskey
```
And you can login with the simple command `ssh remoteserver` instead of `ssh -p 1234 -i keys/vpskey myuser@<server-ip>`

### 3. Traffic only over Tailscale
I came across [this guide](https://tailscale.com/kb/1077/secure-server-ubuntu-18-04/) on the Tailscale docs while researching for this post and it definitely puts security over the top. On implementing this, not only would a bad actor have to gain access to my Tailnet (private Tailscale mesh network) which would be quite difficult in itself, but they still wouldn't be able to gain SSH access without knowing the non-default SSH port and user. Truly marvellous.

```bash
# Tailscale uses the tailscale0 interface and port 41641 for connections
sudo ufw allow in on tailscale0
sudo ufw allow 41641/udp

# We can delete the rule for SSH since the traffic will only be coming over Tailscale
sudo ufw delete 1234/tcp

# Reload ufw to pick up changes
sudo ufw reload
```

## Links
- [Linuxize - How to change ssh port in linux](https://linuxize.com/post/how-to-change-ssh-port-in-linux/)
- [Provide non-default port on an SSH config file](https://askubuntu.com/questions/1111994/login-with-ssh-authorized-key-with-changed-ssh-port/1111996#1111996)