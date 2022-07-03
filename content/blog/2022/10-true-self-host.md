+++
title = "Self Hosting My Blog"
date = "2022-06-25T18:11:37+05:30"
tags = ["meta","self-hosting",]
description = "How I switched over from using Netlify to build and deploy my personal blog"
draft = true
+++

This post details my journey migrating the TinkerMachine blog from using Netlify to build and serve the contents to using a DigitalOcean droplet VPS running Caddy. Similar to the older setup, any change made to GitHub now triggers a webhook server running on this VPS and executes a bash script that runs hugo to generate the static files which then gets served with Caddy.

This post was a huge endeavour spanning a couple of long weeks. I was nearing the stages of burnout at the later parts of setting this up. I had to pick up a lot of skills, overcome a lot of edge case issues (mostly by following helpful guides by other folks who were kind enough to share their learning with the world). 

Previous Blog Setup
All the contents of the blog sits in GitHub. After any change was done through a commit, Netlify takes care of it from there. It goes through the build process where the static files are generated with Hugo and then performs a deployment. All I had to do was make the relevant entries in the DNS entries for the blog so that it pointed to the Netlify deployed site.

Idea for New Setup
Blog contents are still at GitHub. I could just directly make the changes on my local machine and copy the newly generated files from Hugo through rsync or winscp. But I wanted to go through the same process and have all the blog contents available on GitHub. I also wanted to learn more about the process of how a webhook works. This lead me down the path you see below.

Serve blog using Caddy. Webhook server listens for trigger from GitHub after commit. Once triggered, it runs a bash script. This script pulls the latest changes from the GH repository and then runs the hugo command to generate the updated static files. Caddy then serves these new updated files.

Main subtopics:
- Initial attempt to dockerize everything

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