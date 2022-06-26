+++
title = "About"
menu = "main"
+++

# About Me

Hey, I'm Ashley. I'm looking to update this page in the near future.

In the meantime, here are some places you can find me:  

- Website (you are here!): https://tinkermachine.xyz/  
- Email: ashleyjames2800 [@] gmail.com  
- LinkedIn: https://www.linkedin.com/in/-ashley-james/

# Site Details
Blog contents can be found over at my [GitHub repo](https://github.com/shadezer0/TinkerMachine).

Main components while setting up the blog:
- [DigitalOcean 5$ droplet](https://www.digitalocean.com/)
- [Caddy](https://caddyserver.com/docs/)
- [Webhook](ttps://github.com/adnanh/webhook )
- [Hugo](https://gohugo.io/)

This site is hosted on a DigitalOcean VPS and served using Caddy. A webhook runs constantly on this server listening for any changes to the repo. After a commit is pushed, the webhook gets triggered which in turn runs a script to pull the latest changes from my GitHub repo and also uses hugo to generate the updated static HTML/CSS files to render the webpages. Caddy then serves these changes on the fly.