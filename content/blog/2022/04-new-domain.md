+++
title = "New Domain"
date = "2022-04-12T00:00:00+05:30"
tags = ["self-hosting",]
draft = true
+++

My blog finally has a name🎉 TinkerMachine might seem like an average name to you but believe it or not, it was the result of many hours of toil. Some names were not catchy enough. Others were already taken on Google. Some sounded great but just didn't have the meaning I was looking for. Some were perfect till I just didn't like them anymore after a bit of time. TinkerMachine finally gave me a sense of peace so that I could finally rest instead of thinking up different names even during the family dinner. 

This post will go over how I set up my Netflify site to use a custom 'blog' subdomain and how I set up Cloudflare as my authoritative DNS service.

### Buy the Domain
My domain registrar of choice was Namecheap simply because I had already registered a domain there previously. The `.xyz` TLDs (Top Level Domains) in particular are quite cheap if you are not looking for something professional like `.com`.

### Cloudflare DNS
While adding the site on Cloudflare, one nifty feature is that it automatically scans and adds the DNS records. Make sure the required A record and the CNAME record are created. Once this is done, all you have to do is add the 2 nameservers that Cloudflare provides under the custom nameservers section on Namecheap.

Simply put,  
*A record*: A name that points to an IPv4 address  
*CNAME record*: An alias of another name.

There are a lot more DNS records but these seem to be the absolute necessary ones to focus on while starting out.

### Netlify Custom Domain
On the Netlify dashboard, all you'd need to do is to navigate to *Site Settings*, then *Domain Management* and add an entry under *Custom Domains*. Netlify will prompt to add a CNAME record on our DNS records host.

**Note**  
Make sure to change the baseURL for the blog in the Hugo `config.toml` file. This would ensure that the links for the blog don't break. 

### Blog subdomain
Setting up the `blog` subdomain was slightly tricker but <cite>Cloudflare Docs[^1]</cite> helped out quite a bit. Essentially I am hosting the blog on the blog subdomain of the root domain which is tinkermachine.xyz. Now the tricky bit was to redirect the root domain to the subdomain so that it wouldn't have an ugly error if someone visited the link. This was done through the Bulk Redirects functionality on Cloudflare.

Here is fantastic comic by [Julia Evans](https://jvns.ca) explaining the basic inner workings of a DNS query.
![dns query comic](https://wizardzines.com/comics/life-of-a-dns-query/life-of-a-dns-query.png)

[^1]: [Redirect root domain to a subdomain](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/manage-subdomains/#redirect-root-domain-to-a-subdomain). 

### References
- [Set up DNS records for your domain in Cloudflare](https://www.namecheap.com/support/knowledgebase/article.aspx/9607/2210/how-to-set-up-dns-records-for-your-domain-in-cloudflare-account/)
- [DNS Record Types](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/)
- [Redirect root domain to a subdomain](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/manage-subdomains/#redirect-root-domain-to-a-subdomain)
- [DNS query comic](https://wizardzines.com/comics/life-of-a-dns-query/) by Julia Evans. Definitely check out her other comics at https://wizardzines.com