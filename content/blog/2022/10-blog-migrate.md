+++
title = "Moving the Blog to a Cloud Server"
date = "2022-07-14T22:15:00+05:30"
tags = ["meta","self-hosting",]
description = "Reworking the build and deploy process for my blog as a learning project. The blog currently runs on a DigitalOcean droplet and picks up changes from GitHub."
+++

This post details my journey migrating the TinkerMachine blog from using [Netlify](https://www.netlify.com/) to build and serve the site contents to doing the same thing from a $5 (<cite>now hiked to $6[^1]</cite>) [DigitalOcean](https://www.digitalocean.com/) droplet.

[^1]: It's extremely unfortunate that DigitalOcean has [bumped up their prices](https://www.digitalocean.com/try/new-pricing) and there doesn't seem to be a straight-forward way [to downsize](https://docs.digitalocean.com/products/droplets/concepts/downsizing-considerations/) to their $4 droplet. Certainly a perfect excuse to get some practical knowledge writing an Ansible playbook.

Just so that it's absolutely clear - Netlify is a wonderfully easy and effective way to get started with your blog on GitHub. I'm trying to do the heavy lifting here, setting it all up on my own cloud server as a project to learn more about the steps involved with hosting your own site.

I'm also extremely grateful to the numerous people on the internet who were kind enough to share their own discoveries through blog posts which helped me in my setup. I'm hoping that this post also helps some future reader in their own journey.

## Old Setup
All contents of the blog sit in a [GitHub repository](https://github.com/shadezer0/TinkerMachine). Any changes are pushed via commits that trigger a new build on Netlify which then takes care of deploying the site as well. I only had to worry about maintaining the DNS records pointing the domain name to the Netlify created site which hosted the blog.

This is very easy to setup and highly recommended in the early stages of the blog writing process. Start with focussing more on the writing than the implementation details around the blog.

## Ideas for the New Setup
An easy way to implement a self-hosted blog on a remote server would be:

Make change locally -> Use hugo to generate static files -> Copy static files using rsync/winscp to the remote server -> Serve files with web server

In my case, I wanted to keep the existing workflow as much as possible. This meant pushing the changes via commits to GitHub that would trigger the build and deploy process. In this manner, all changes could be tracked through a version control system. But even in this scenario, you could possibly run hugo and copy over the static files after each commit. But I wanted a more automated and elegant approach that performs the build and serves the files seamlessly after each commit.

These were 2 possible approaches I came up with:
1. After a commit, run a workflow through GitHub Actions to pick up the latest repo contents, use hugo to generate the static files and copy these over to my remote server using rsync.
2. After a commit, GitHub sends a payload to a URL which triggers a webhook on the remote server that runs a bash script to do the build process.

I was hesitant to go with method #1 since that would mean configuring SSH keys, non-standard SSH ports and Tailscale auth keys on the temporary Ubuntu VM used by GitHub Actions. Since I didn't have too much experience writing the YAML files for GitHub Actions, I decided to go with method #2.

Serve blog using Caddy. Webhook on the VPS listens for a POST request from GitHub on a specified HTTP (or HTTPS) endpoint after a commit. Once triggered, a bash script is executed. This script pulls the latest changes from the repository and then runs the hugo command to generate the static files with all the changes. Caddy then serves these updated files.

While working on these changes, I decided to move away from the blog subdomain and use the main `tinkermachine.xyz` domain to serve the blog. This requires some config in Caddy and Cloudflare DNS for redirecting anyone visiting the old `blog.tinkermachine.xyz/post-1` links to the new one with `tinkermachine.xyz/post-1`.

The major steps were picked up from this extremely helpful and detailed blog post which is also thankfully updated for Caddy v2 -- https://tvc-16.science/caddy-2-update.html. I can't stress how useful this post was while setting up my own process.

## Services Being Used
- [Caddy](https://caddyserver.com/docs/) -- Web server of choice to serve files and also be used for reverse proxy purposes.
- [Webhook](https://github.com/adnanh/webhook) (Name of the app is the same as functionality it's providing. Gets confusing fast)
- [Cloudflare DNS](https://www.cloudflare.com/dns/) -- Replace with whatever DNS managing service you're using.

Note that the DigitalOcean droplet is running Ubuntu 20.04.4 LTS.

### User and Deploy Directory Setup

- Create a new user which would be running the web server and the webhook.

```bash
# create the user that will be used to run Caddy and webhook
sudo useradd bloguser
# set a password for the user
passwd bloguser

# change default shell since it wasn't bash
sudo chsh -s /bin/bash bloguser

# create the home dir
# use adduser instead of useradd while creating a user to skip this step
sudo mkdir /home/bloguser
sudo chown -R bloguser:bloguser /home/bloguser

# optional step to copy over SSH keys
sudo cp ~/.ssh /home/bloguser/
sudo chown -R bloguser:bloguser /home/bloguser/.ssh

# [optional] provide superuser privileges to the user
sudo usermod -aG sudo bloguser

# switch to the new user
su - bloguser

```

- Setup a local copy of the blog repo in the deploy directory. This is a one-time activity after which the webhook script will run `git pull` to pull the latest changes to this location.

```bash
# create new dir
mkdir ~/deploy/tinkermachine.xyz/

# clone repo into dir
git clone https://github.com/shadezer0/TinkerMachine.git ~/deploy/tinkermachine.xyz

# set up hugo theme
git submodule init
git submodule update
```

- Once hugo is run as part of the webhook script, it will create a new directory called `public` where the static HTML/CSS files are created from the markdown files with which the posts are written. This is the location that will be served by Caddy.

### Caddy Setup
Initially, Caddy v1 did come built-in with a git module but this was removed for v2. Now, you would need to build a custom caddy binary using xcaddy with a third party module for git in order to implement a webhook server. 

I decided to go with another dedicated webhook service written in Go and use Caddy just as a web-server and reverse-proxy.

- Install Caddy using the apt package manager (for Ubuntu/Debian) by following [these steps](https://caddyserver.com/docs/install#debian-ubuntu-raspbian).

- Create a Caddyfile with the required configurations. You can find docs on writing a Caddyfile [here](https://caddyserver.com/docs/caddyfile-tutorial). This is how my Caddyfile looks like currently:

```bash
$ cat ~/deploy/Caddyfile

tinkermachine.xyz {
        tls /etc/ssl/certs/CF_certificate.pem /etc/ssl/private/CF_key.pem

        # Set this path to your site's directory.
        root * /home/bloguser/deploy/tinkermachine.xyz/public

        # Enable the static file server.
        file_server
}

# Redirect any old URLs to the new domain
blog.tinkermachine.xyz {
        redir https://tinkermachine.xyz{uri} permanent
}

www.tinkermachine.xyz {
        redir https://tinkermachine.xyz{uri}
}

# configuration for the webhook endpoint
webhook.tinkermachine.xyz {
        tls /etc/ssl/certs/CF_certificate.pem /etc/ssl/private/CF_key.pem
        reverse_proxy localhost:3000
}

```
- There are entries for serving the static contents for the blog and redirecting old links to the blog towards the new one. In order to avoid using the IP address for the webhook service, we are adding an entry to expose it using a subdomain through Caddy’s reverse proxy directive.

- The certificates for Cloudflare were needed since I was not going to use the built-in HTTPS functionality and Let's Encrypt certificates provided by Caddy. Refer to [this link](https://samjmck.com/en/blog/using-caddy-with-cloudflare/#configuration-with-proxy-enabled) for configuring Caddy to be used with Cloudflare when enabling proxy. I followed the steps which go over using Cloudflare's origin certificate.

- Run `caddy run` to run the web server with output to STDOUT while testing. Run `caddy start` in the `~/deploy` dir to actually start the server in the background. 

- Provide the required capability for Linux to allow Caddy to serve contents on port 80. This is needed because it's a port below 1024 which needs special permissions. Refer [this thread](https://serverfault.com/a/807884) for more info. 

```bash
sudo setcap CAP_NET_BIND_SERVICE=+eip $(which caddy)
``` 

### Webhook Setup
Here's the description of the webhook service from its GitHub repo which explains the functionality succinctly:

> webhook is a lightweight configurable tool written in Go, that allows you to easily create HTTP endpoints (hooks) on your server, which you can use to execute configured commands. You can also pass data from the HTTP request (such as headers, payload or query variables) to your commands. webhook also allows you to specify rules which have to be satisfied in order for the hook to be triggered.

- Install the community packaged version for the Go binary of webhook through the apt package manager for Ubuntu.

```bash
sudo apt-get install webhook
```

- Create a `hooks.json` file that will be used by webhook to set up the script to execute, the endpoint for the route (it uses the configured id) and also setting trigger rules (the rules that need to match before the script can run). We provide a secret as part of these rules so that no unauthorized requests will be able to trigger that script on our server. We will be configuring the GitHub webhook to use the same secret that we provide here. You can use [this file](https://github.com/adnanh/webhook/blob/master/hooks.json.example) as reference.

```bash
$ cat ~/deploy/hooks.json

[
    {
        "id": "redeploy-webhook",
        "execute-command": "/usr/local/bin/redeploy.sh",
        "command-working-directory": "/home/bloguser/deploy/tinkermachine.xyz",
        "trigger-rule": {
            "and": [
                {
                    "match": {
                        "type": "payload-hash-sha1",
                        "secret": "SUPERSECRET",
                        "parameter": {
                            "source": "header",
                            "name": "X-Hub-Signature"
                        }
                    }
                },
                {
                    "match": {
                        "type": "value",
                        "value": "refs/heads/main",
                        "parameter": {
                            "source": "payload",
                            "name": "ref"
                        }
                    }
                }
            ]
        }
    }
]

```

- The deploy bash script `redeploy.sh` contains 2 steps - one to pull the latest changes on a local github repo and then to run hugo to recreate the static files according to the changes. I've optionally added another command to log the timestamp when the webhook server receives a request. Don't forget to check the owner of the script and provide execute permissions to run it.

```bash
$ cat /var/scripts/redeploy.sh

#!/bin/bash
# pull changes and favour remote in case of merge conflicts
git pull -s recursive -X theirs
# run hugo
hugo
# [optional] send output to a log file for debugging
echo Received request on $(date) >> /home/bloguser/deploy/log

```

- For the sake of convenience, create a user defined systemd unit file for managing the service with systemctl. Take care to create the service unit file at the right location in the user's home directory. I used the steps from [this post](https://ansonvandoren.com/posts/deploy-hugo-from-github/) to set up the service. Do note that he uses nginx instead of Caddy but the unit file setup stays mostly the same.

```bash
$ cat ~/.config/systemd/user/webhook.service

[Unit]
Description=Webhook Server

[Service]
ExecStart=/usr/bin/webhook -hooks /home/bloguser/deploy/hooks.json -port 3000 -hotreload -verbose

[Install]
WantedBy=multi-user.target

```

- Reload the systemd daemon so it picks up the configuration for the new service. Don't forget to enable it to start at boot and to set up linger so that it runs even when the blog user is not logged in. 

```bash
# pick up latest configuration
systemctl --user daemon-reload

# start service on boot
systemctl --user enable --now webhook

# enable linger to run the service even when user is not logged in
sudo loginctl enable-linger bloguser
```

- Configure a webhook on the GitHub repo for the blog so that it pushes a payload when there's any change to the repo like a commit. 

![GitHub Webhook Screenshot](/images/posts/10_webhook_gh.png)


This is how the deploy directory structure looks like now

```bash
$ tree -L 2 ~/deploy

deploy/
├── Caddyfile
├── hooks.json
├── log
└── tinkermachine.xyz
    ├── README.md
    ├── archetypes
    ├── config.toml
    ├── content
    ├── layouts
    ├── public
    ├── resources
    ├── static
    └── themes

```

### Cloudflare DNS Setup
- Create an A record that points `tinkermachine.xyz` to the IPv4 address of the DigitalOcean VPS.
- Create a CNAME record for the webhook endpoint which will be configured on GitHub.
- Optional: Create a CNAME record for www pointing to tinkermachine.xyz
- Optional: I've added a CNAME record for blog (blog.tinkermachine.xyz) to make sure the old links initially on the blog subdomain get gracefully redirected to the main host.

Make sure that the required entries for these configurations are also present in the Caddyfile.

![CloudFlare DNS Settings](/images/posts/10_cf_dns_config.png)


After these changes, you will be able to hit the domain and see the blog if everything was done properly.

## Lessons Learnt
- Always make sure to know where to look for logs or set up some way to print out the logs. This makes the head scratching process of finding where a silent bug is hiding much more painless.
- Usually, it pays to have a good night's sleep and come back to some nagging problem later in the morning. This is something I struggle with as I get completely absorbed in whatever I'm working on at the moment.
- Don't spend too much time and get caught up on the file/directory naming from the very start. This can be reworked later.
- The setup doesn't need to be perfect in the beginning. It just needs to work and do what you want it to do. Improvements can always be made over time. Think about what the MVP would look like and aim for that.

## Future Plans
Use containerization to easily recreate this entire setup with the help of docker and docker compose.