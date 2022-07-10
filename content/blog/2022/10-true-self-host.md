+++
title = "Self Hosting My Blog"
date = "2022-07-06T18:00:00+05:30"
tags = ["meta","self-hosting",]
description = "How I moved away from using Netlify to build and deploy my blog"
draft = true
+++

This post details my journey migrating the TinkerMachine blog from using Netlify to build and serve the site contents to doing the same thing from a  DigitalOcean VPS.

Just so that it's absolutely clear - Netlify is a wonderful way to get started with your blog on GitHub. I'm trying to do the heavy lifting here with my own cloud server just as a personal project to learn more about the steps involved with hosting your own site.

I'm extremely grateful to the numerous people on the internet who were kind enough to share their own discoveries through blog posts which helped me in my setup. I'm hoping that this post also helps some future reader in their own journey. 

## Previous Setup
All contents of the blog sit in a GitHub repository. Any changes are pushed via commits that trigger a new build on Netlify which then takes care of deploying the site as well. The only thing I had to worry about was to ensure the DNS records were pointing the domain name to the Netlify site which hosted the blog.

This is very easy to setup and highly recommended in the early stages of the blog writing process. Start with focussing more on the writing than the implementation details around the blog.

## Idea for a Self-Hosted Setup
An easy way to implement a self-hosted blog would be:

Make change locally -> Use hugo to generate static files -> Copy static files through rsync/winscp to the remote serve -> Serve files with webserver

In my case, I wanted to keep the existing workflow as much as possible. This meant pushing the changes via commits on GitHub which would trigger the build and deploy process. This would keep all changes tracked through a version control system. Even in this scenario, you could possibly run hugo and copy over the static files after each commit. But I wanted a more automated and elegant approach that does the build and serves the files seamlessly after each commit.

There were 2 possible approaches:
1. After a commit, run the GitHub Actions CI tool to pick up the latest repo contents, use hugo to generate the static files and copy these over to my remote server through rsync.
2. After a commit, GitHub sends a payload to an HTTP endpoint which then runs a bash script to do the build process.

I didn't want to do method #1 since I would also need to set up Tailscale on the temporary Ubuntu VM used by GitHub Actions. This is because I've set up the remote server to only be accessed from another device on my Tailscale network. There would also be the hassle of setting up the SSH keys and having SSH happen over a non-standard SSH port.

So I went ahead with method #2.

Serve blog using Caddy. Webhook server listens for POST request from GitHub on a specified HTTP endpoint after a commit. Once triggered, it runs a bash script. This script pulls the latest changes from the GH repository and then runs the hugo command to generate the updated static files. Caddy then serves these new updated files.

Also, while working on these changes, I decided to move away from the blog subdomain and use the main `tinkermachine.xyz` domain itself to serve the blog. This requires some config in Caddy and CloudFlare DNS for redirecting anyone visiting the old `blog.tinkermachine.xyz/post-1` links to the new one with `tinkermachine.xyz/post-1`.

The major steps were followed from this extremely helpful and detailed blog post which is also thankfully updated for Caddy v2 -- https://tvc-16.science/caddy-2-update.html

## Main tools being Used
- [Caddy](https://caddyserver.com/docs/) -- Web server of choice to serve files and also be used for reverse proxy purposes.
- [Webhook](https://github.com/adnanh/webhook) (Name of the app is the same as functionality it's providing. Gets confusing fast)
- [Cloudflare DNS](https://www.cloudflare.com/dns/) -- Replace with whatever DNS managing service you're using.

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
sudo mkdir /home/bloguser
sudo chown -R bloguser:bloguser /home/bloguser

# optional step to copy over SSH keys
sudo cp ~/.ssh /home/bloguser/
sudo chown -R bloguser:bloguser /home/bloguser/.ssh

# switch to the new user
su - bloguser

```

- Setup a local copy of the blog repo in the deploy directory. This is a one-time activity after which the webhook script will run `git pull` to get the latest changes to this location.

```bash
# create new dir
mkdir ~/deploy/tinkermachine.xyz/

# clone repo into dir
git clone https://github.com/shadezer0/TinkerMachine.git ~/deploy/tinkermachine.xyz

# set up hugo theme
git submodule init
git submodule update
```

- Once hugo is run as part of the webhook script, it will create a new directory called `public` where the static files will be present. This location will be served by Caddy.

### Caddy
Initially caddy did come built-in with a git module but this was done away with for v2. Now, you could build a custom caddy binary using xcaddy and a third party module for git in order to respond to a webhook. 

I decided to go with the dedicated webhook service itself and use Caddy just as a web-server and reverse-proxy.

- Install caddy through apt package manager by following [these steps](https://caddyserver.com/docs/install#debian-ubuntu-raspbian).

- Create a Caddyfile with the required configurations. You can find docs on writing a Caddyfile [here](https://caddyserver.com/docs/caddyfile-tutorial). This is how my Caddyfile looks like currently:

```
$ cat ~/deploy/Caddyfile
tinkermachine.xyz {
        tls /etc/ssl/certs/CF_certificate.pem /etc/ssl/private/CF_key.pem

        # Set this path to your site's directory.
        root * /home/ghdeploy/deploy/tinkermachine.xyz/public

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
- There are entries for serving the static contents for the blog, redirecting old links to the new one and configuring a reverse proxy to serve the endpoint for the webhook.

- The certificates for Cloudflare were needed since I was not going to use the built-in HTTPS functionality by Caddy. Refer to [this link](https://samjmck.com/en/blog/using-caddy-with-cloudflare/#configuration-with-proxy-enabled) for configuring Caddy to be used with Cloudflare when proxy is enabled. I followed the steps for using Cloudflare's origin certificate.

- `caddy run` to run with output for testing. `caddy start` to actually start the server in the background. 

- Provide the required capability for Linux to allow caddy to serve contents on port 80. This is needed because it's a port below 1024 which needs special permissions. Refer [this thread](https://serverfault.com/a/807884) for more info. 

```bash
sudo setcap CAP_NET_BIND_SERVICE=+eip $(which caddy)
``` 

### Webhook
Here's the definition from the GH repo which explains the functionality succinctly:

> webhook is a lightweight configurable tool written in Go, that allows you to easily create HTTP endpoints (hooks) on your server, which you can use to execute configured commands. You can also pass data from the HTTP request (such as headers, payload or query variables) to your commands. webhook also allows you to specify rules which have to be satisfied in order for the hook to be triggered.

Listens at a particular URL endpoint and port that we specify for webhooks. In order to not use the IP address, we can add the webhook URL into the Caddyfile as well to expose it through Caddy's reverse proxy directive.

- Webhook needs a hooks.json file that runs the script if the trigger conditions are satisfied. This is so that not anyone can hit the URL and run the script unauthorized. Therefore we provide a secret that the GH payload would need to send in the POST request.

```
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

- Add a script which contains 2 commands: one to run git pull on an already initialized local github repo. It also runs the hugo command to recreate the static files according to the changes. Don't forget to check the owner of the script and provide execute permissions to run the it.

```bash
$ cat /var/scripts/redeploy.sh

#!/bin/bash
# pull changes and favour remote in case of merge conflicts
git pull -s recursive -X theirs
# run hugo through a docker container
docker run --rm -v $(pwd):/src klakegg/hugo:0.93.2
# send output to a log file for debugging
echo Received webhook at $(date) >> /home/bloguser/deploy/log

```

- Create user defined systemd unit file for the service to be managed by systemd.
```
$ cat ~/.config/systemd/user/webhook.service
[Unit]
Description=Webhook Server

[Service]
ExecStart=/usr/bin/webhook -hooks /home/bloguser/deploy/hooks.json -port 3000 -hotreload -verbose

[Install]
WantedBy=multi-user.target
```

- Reload systemd daemon so it picks up the configuration for the new service. Don't forget to enable it to start at boot and to set up linger so that it runs even when the blog user is not logged in.

```
systemctl --user daemon-reload
systemctl --user enable --now webhook
sudo loginctl enable-linger
```

- Set up the webhook on the GitHub repo so that it pushes a payload when there's any change to the repo like a commit. 

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

### Cloudflare DNS
- Create an A record that points tinkermachine.xyz to the IPv4 address of the DigitalOcean VPS.
- Optional: Create a CNAME record for www pointing to tinkermachine.xyz
- Optional: Create another CNAME record for blog (blog.tinkermachine.xyz) pointing to tinkermachine.xyz. This makes sure the old links which were initially on the blog subdomain get gracefully redirected to the main host.
- Make sure that the required entries for these configurations are also present in the Caddyfile.

![CloudFlare DNS Settings](/static/images/posts/10_cf_dns_config.png)

## Keep in Mind for Next Time
- Always make sure to know where to look for logs or set up some way to print out the logs. This makes the head scratching process of finding where a silent bug is hiding much more painless.
- Usually, it pays to have a good night's sleep and come back to some nagging problem later in the morning. This is something I struggle with as I get completely absorbed in whatever I'm working on at the moment.
- Don't spend too much time and get caught up on the file/ directory naming initially. 
- The setup doesn't need to be perfect in the beginning. It just needs to work and do what you want it to do. Improvements can always be made over time. Think about what the MVP would look like and aim for that.

## Other References
webhook references (note, they use nginx instead of caddy)
- https://ansonvandoren.com/posts/deploy-hugo-from-github/ -- how I got webhook to run as a user defined systemd service
- https://davidauthier.com/blog/2017/09/07/deploy-using-github-webhooks/
- https://github.com/adnanh/webhook/blob/master/hooks.json.example