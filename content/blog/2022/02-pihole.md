+++
title = "Setting up Pi-hole"
date = "2022-04-07"
description = "Setting up Pi-hole: a network-wide ad-blocker"
tags = ["self-hosting"]
+++

Pi-hole is a service which allows you to block ads on your entire network. That includes your smart TV where you usually wouldn't be able to install an ad-blocker. This technical wizardry happens because we are essentially running a [DNS sinkhole server](https://en.wikipedia.org/wiki/DNS_sinkhole). Pi-hole can do a couple of other nifty tricks but I'll just be focussing on setting up the ad-blocking capabilities for now. You could also pair this with a VPN (in case you want access from outside your home network) and even run it as your local DHCP server instead of your router.

This post will go over how to setup [Pi-hole](https://pi-hole.net/) on a Raspberry Pi. Pi-hole will be running from a Docker container and managed using Docker Compose.

### Initial Setup
-  Download the [Raspbian OS Lite image](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit) and flash it onto an SD card using [Balena Etcher](https://www.balena.io/etcher/).
-  Add an empty file named `ssh` in the root directory named boot once the flashing of the image is completed. Ensure that there is no extension to the file.
-  Connect the Raspberry Pi to the router via ethernet. Alternatively, Wifi can be setup, but the process is slightly longer.
- Assign a static IP to the Pi through the router management settings so that the router doesn't assign the same IP through <cite>DHCP[^1]</cite> to any other device.
-  Try to SSH into the Pi with the static IP. In case you didn't assign a static IP from the earlier step, check the router management page to see what IP the router has dynamically assigned the Raspberry Pi. 
- Get the latest updates for Raspbian and finish the initial setup.

[^1]: DHCP or *Dynamic Host Configuration Protocol* describes the process by which the router dynamically assigns IP addresses to all the devices being connected on your home network. You can read more about it [here](https://docs.microsoft.com/en-us/windows-server/networking/technologies/dhcp/dhcp-top).

```bash
sudo apt update && sudo apt upgrade -y
# set country for date/ time
sudo raspi-config

# install preferred editor
sudo apt install vim
```

### Install Docker and Docker Compose
Run the commands below to install [Docker](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/).

```bash
# install docker 
curl -sSL https://get.docker.com | sh
# add user to docker group
sudo usermod -aG docker ${USER}

# install docker-compose
sudo apt install libffi-dev libssl-dev
sudo apt install python3-dev
sudo apt install -y python3 python3-pip
sudo pip3 install docker-compose

# start docker containers on boot
sudo systemctl enable docker
```

### Setting up Pi-hole
- Copy the docker compose script below into the `~/pihole` directory and run the commands from this directory. Note that I'm using the jacklul/pihole image so that I can set up pihole-updatelists easier. Pihole-updatelists allows me to manage adlists, whitelists and automatically check for updates. I'm also using Cloudflare as my upstream DNS provider.

```yaml
version: "3"

services:
  pihole:
    container_name: pihole
    image: jacklul/pihole:latest
	hostname: pihole-docker
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "67:67/udp" # Only required if you are using Pi-hole as your DHCP server
      - "80:80/tcp"
    environment:
      TZ: 'yourtimezone'
      WEBPASSWORD: supersecretpassword
      PIHOLE_DNS_: 1.1.1.1;1.0.0.1
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
      - './etc-pihole-updatelists/:/etc/pihole-updatelists/'
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
```
- Run `docker-compose up -d`. 

Navigate to the web UI for Pi-hole which would be for example `192.168.1.2/admin` assuming 192.168.1.2 was the IP assigned to the Pi. Hopefully you are able to see the admin login page where you can login with the password provided in the docker compose file.

- Monitor logs using `docker logs pihole` in pi-hole does not start up correctly. 
- Use the Pi-hole web UI to change the DNS settings under *Interface Behavior* to "Permit all origins", if using Docker's default `bridge` network setting. 
- Edit the `/etc-pihole-updatlists/pihole-updatelists.conf` file to add recommended adlists and whitelist. Restart with `docker-compose restart`

```bash
.
.
ADLISTS_URL="https://v.firebog.net/hosts/lists.php?type=tick"
.
.
WHITELIST_URL="https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt"
.
.
```

- Disable the default gravity update schedule since pihole-updatelists will be taking care of that. Open a bash shell on the running pihole container and run the sed command below.

```bash
# Open an interactive shell on the pihole container
docker exec -it pihole bash

# Now in the container shell, run
sed -e '/pihole updateGravity/ s/^#*/#/' -i /etc/cron.d/pihole
# This will comment out the line in /etc/cron.d/pihole 
# that runs the pihole updateGravity command
```

- Now that you've got Pi-hole running successfully, don't forget to configure your router's DHCP to use the Pi as the DNS server for all clients. Another alternative would be to manually change the DNS server on individual devices.

### Issues

- In case of an issue with the DNS, check the `/etc/resolv.conf` file and check if the nameserver is 127.0.0.1 (localhost). If it isn't that, create a `resolv.conf` file on the Pi host with the correct entries and mount that as a volume to `/etc` on the container.
- In case the adlists are not updating on the web UI, manually run `pihole-updatelists` on the pihole container shell.

### Links
- [GitHub repo for Docker Pi-hole](https://github.com/pi-hole/docker-pi-hole/#running-pi-hole-docker)
- [GitHub repo for pihole-updatelists](https://github.com/jacklul/pihole-updatelists)
- [Pi-hole README](https://github.com/pi-hole/pi-hole/blob/master/README.md)
- [Test if Pi-hole is working with this site](https://canyoublockit.com/extreme-test/)
- [Reddit thread with common issues](https://www.reddit.com/r/pihole/comments/saotvn/the_complete_guide_to_common_issues/)
