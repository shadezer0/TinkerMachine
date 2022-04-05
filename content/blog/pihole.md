+++
title = "Setting up Pi-hole"
date = "2022-04-05T21:28:42+05:30"
tags = ["self-hosting", "technical"]
draft = true
+++

This post will go over how to setup [Pi-hole](https://pi-hole.net/) on a Raspberry Pi. Pi-hole will be running from a Docker container and managed using Docker Compose.

### Initial Setup
1. Download the [Raspbian OS Lite image](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-32-bit) and flash it onto the SD card using Balena Etcher.
2. Add an empty file named `ssh` in the root directory named boot once the flashing of the image is completed. Ensure that there is no extension to the file.
3. Connect the Raspberry Pi to the router via ethernet. Wifi can also be setup but the process is slightly longer.
4. Assign a static IP to the Pi through the router management settings so that the router doesn't the same IP through DHCP to any other device.
5. Get the latest updates for Raspbian and finish the initial setup.

```bash
sudo apt update && sudo apt upgrade -y
# set country for date/ time
sudo raspi-config

# install preferred editor
sudo apt install vim
```

### Install Docker and Docker Compose
Run the commands below to install Docker and Docker Compose.

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
1. Copy the docker compose script below into `~/pihole` and change into the directory. Note that I'm using the jacklul/pihole image so that I can set up pihole-updatelists which allows me to manage adlists, whitelists and automatically check for updates. I'm also using Cloudflare as my upstream DNS provider.

```yaml
version: "3"

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: jacklul/pihole:latest
	hostname: pihole-docker
    ports:
      - "53:53/tcp"
      - "53:53/udp"
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
2. Run `docker-compose up -d`. 

Navigate to the web UI for Pi-hole which would be `192.168.1.2/admin` assuming 192.168.1.2 was the static IP assigned earlier. Hopefully you are able to see the admin login page where you can login with the password provided in the docker compose file.

3. Monitor logs using `docker logs pihole`
4. Use the Pi-hole web UI to change the DNS settings _Interface listening behavior_ to "Listen on all interfaces, permit all origins", if using Docker's default `bridge` network setting
5. Edit the `/etc-pihole-updatlists/pihole-updatelists.conf` file to add recommended adlists and whitelist. Restart with `docker-compose restart`

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

6. Disable the default gravity update schedule since pihole-updatelists will be taking care of that. Open a bash shell on the running pihole container and run the sed command given below.

```bash
docker exec -it pihole bash

# in the container shell
sed -e '/pihole updateGravity/ s/^#*/#/' -i /etc/cron.d/pihole
```

### Issues

- In case of an issue with the DNS, check the `/etc/resolv.conf` file and check if the nameserver is 127.0.0.1 (localhost). If it isn't that, create a `resolv.conf` file on the Pi host with the correct entries and mount that as a volume to `/etc` on the container.
- In case the adlists are not updating on the web UI, run `pihole-updatelists` after opening up a bash shell on the pihole container.

### Links
- [GitHub repo for Docker Pi-hole](https://github.com/pi-hole/docker-pi-hole/#running-pi-hole-docker)
- [GitHub repo for pihole-updatelists](https://github.com/jacklul/pihole-updatelists)
- [Pi-hole README](https://github.com/pi-hole/pi-hole/blob/master/README.md)
- [Test if Pi-hole is working](https://canyoublockit.com/extreme-test/)
- [Reddit thread with common issues](https://www.reddit.com/r/pihole/comments/saotvn/the_complete_guide_to_common_issues/)
