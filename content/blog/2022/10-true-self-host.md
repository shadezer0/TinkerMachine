+++
title = "Self Hosting My Blog"
date = "2022-06-25T18:11:37+05:30"
tags = ["meta","self-hosting",]
description = "How I switched over from using Netlify to build and deploy my personal blog"
draft = true
+++

This post details my journey migrating the TinkerMachine blog from using Netlify to build and serve the site contents to a self-hosted DigitalOcean droplet VPS. Similar to the older setup, any changes to be made are done through commits on GitHub that trigger a webhook and subsequently updates the static files on the remote server. 

The learning and documentation here is the result of a monumental effort spanning a couple of weeks. Between working on the weekends and trying to fix obscure issues, I'm happy to say that the initial effort to serve the blog from my own server is finally complete. I'm also extremely grateful to the numerous people who were kind enough to share their own discoveries through blog posts which helped me in my setup. I'm hoping that this post also helps some future reader in their own journey. 

## Previous Setup
All contents of the blog sit in a GitHub repository. Any changes are pushed via commits that trigger a new build on Netlify which then takes care of deploying the site as well. The only thing I had to worry about was to ensure the DNS records were pointing the domain name to the Netlify site which hosted the blog.

This setup is very easy to setup and highly recommended in the early stages of your blog writing process. This is because it's important to focus more on the writing than the architecture of the blog deployment. I moved away from Netlify solely because I wanted to have a personal project to learn and practice new concepts. This included getting my hands dirty with a webserver and playing around with sending and receiving webhooks.

## Initial Idea for a self-hosted Setup
An easy way to implement a self-hosted blog would be:

Make change locally -> Run hugo to generate static files -> Copy static files through rsync/winscp to the remote serve -> Serve files with webserver

But I wanted to keep the existing workflow as much as possible. This meant pushing the changes via commits on GitHub which would trigger the build and deploy process. This would keep all changes tracked through a version control system. Even in this scenario, another easy shortcut would be to run the copy command after each commit as an independent step. This could be automated as well through the use of an alias to push the change to GitHub, generate the static files and copy the resulting folder to the remote server. But this didn't feel right to me as well

There were 2 possible approaches I could take:
1.  After the commit, run GitHub Actions to get blog contents after hugo build and copy the results to the remote server.
2.  After the commit, GitHub sends a payload to an HTTP endpoint which then runs a bash script to do the build process.

I didn't want to do method #1 since I would also need to set up Tailscale on the temporary Ubuntu VM that spins up not to mention setting up the SSH keys and having SSH happen over a non-standard SSH port.

So I went ahead with method #2.

Serve blog using Caddy. Webhook server listens for trigger from GitHub after commit. Once triggered, it runs a bash script. This script pulls the latest changes from the GH repository and then runs the hugo command to generate the updated static files. Caddy then serves these new updated files.

## Failure with Containerizing Everything
TODO: Do I need to write about initial docker attempts?

## Main tools being Used
- Caddy -- webserver of choice
- Webhook (Name of the app is the same as functionality it's providing. Gets confusing fast)
- CloudFlare DNS -- Any DNS managing service works. I just happen to use CloudFlare

### OS Setup
Setting up the user
- Create a new user which would be running the webserver and the webhook. 
- Create a location where caddy serves the files ~/deploy/tinkermachine.xyz/public
- When running hugo command, it takes the markdown and other config and generates the HTML/CSS output according to the theme I've setup.

### Caddy
Initially caddy did come built-in with a git module but this was done away with for v2 unless you want to build a custom binary using xcaddy and a third party module for git in order to respond to a webhook. This is now done through the use of another service named "Webhook"

- Install caddy through apt package manager
- Create Caddyfile with required configurations.
- `caddy run` to run with output for testing. `caddy start` to actually start the server in the background. https://caddyserver.com/docs/
- For the permission error because a user is using a lower numbered port, use this command: `sudo setcap CAP_NET_BIND_SERVICE=+eip $(which caddy)`. Refer https://serverfault.com/questions/807883/caddy-listen-tcp-443-bind-permission-denied
- 

### Webhook
Definition from GH repo:

> webhook is a lightweight configurable tool written in Go, that allows you to easily create HTTP endpoints (hooks) on your server, which you can use to execute configured commands. You can also pass data from the HTTP request (such as headers, payload or query variables) to your commands. webhook also allows you to specify rules which have to be satisfied in order for the hook to be triggered.

Listens at a particular URL endpoint and port that we specify for webhooks. In order to not use the IP address, we can add the webhook URL into the Caddyfile as well to expose it through Caddy's reverse proxy directive.

- https://github.com/adnanh/webhook
- 
- Set up a GH webhook that pushes a payload when there's any change to the repo like a commit. We configure the URL for as the one that we set up with the webhook server
- Webhook needs a hooks.json file that runs the script if the trigger conditions are satisfied. This is so that not anyone can hit the URL and run the script unauthorized. Therefore we provide a secret that the GH payload would need to send in the POST request.
- Add script which contains 2 commands: one to run git pull on an already initialized local github repo. It also runs the hugo command to recreate the static files according to the changes. 
- Create user defined systemd unit file for the service to run and enable it to start at boot. Make sure to set up linger so that it runs even when the user is not logged in.


### CloudFlare DNS
- Create an A record that points tinkermachine.xyz to the IPv4 address of the DigitalOcean VPS.
- Optional: Create a CNAME record for www pointing to tinkermachine.xyz
- Optional: Create another CNAME record for blog (blog.tinkermachine.xyz) pointing to tinkermachine.xyz. This makes sure the old links which were initially on the blog subdomain get gracefully redirected to the main host.
- Make sure to add the required entries in the Caddyfile for both the configurations above.

## Issues Faced
- While cloning a GH repo for hugo blog using a theme added as a submodule, make sure to run the relevant command to pull that down -- git submodule init and git submodule update.
- 

## Keep in mind for next time
- Always make sure to know where to look for logs or set up some way to print out the logs. This makes the head scratching process of finding where a silent bug is hiding much more painless.
- Sometimes, it pays to have a good night's sleep and come back to some nagging problem later in the morning. This is something I struggle with as I get completely absorbed in whatever I'm working on at the moment.
- Don't spend too much time and get caught up on the file/ directory naming atleast initially. 
- It doesn't need to a perfect setup in the beginning. It just needs to work and do what you want it to do. Improvements can be made over time.

## References
- https://tvc-16.science/caddy-2-update.html -- followed this as a general guide. Updated for Caddy v2.
- https://samjmck.com/en/blog/using-caddy-with-cloudflare/#configuration-with-proxy-enabled -- referred to this while setting up the certificates while having CloudFlare's proxy enabled for the site.

refer for webhook -- note that they both use nginx as the webserver
- https://ansonvandoren.com/posts/deploy-hugo-from-github/ -- how I got the webhook service to run as a systemd service
- https://davidauthier.com/blog/2017/09/07/deploy-using-github-webhooks/
- https://github.com/adnanh/webhook/blob/master/hooks.json.example