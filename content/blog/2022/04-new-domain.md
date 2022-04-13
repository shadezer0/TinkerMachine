+++
title = "New Domain"
date = "2022-04-13T18:00:00+05:30"
description = "Setting up a new domain for the blog 🎉"
tags = ["self-hosting","meta"]
+++

My blog finally has a name 🎉. TinkerMachine might seem quite average but believe it or not, it was the result of many hours of toil. Some names were not catchy enough. Others were already taken after a quick Google search. Some sounded great but didn't have the intended meaning. At a certain point, I finally settled on TinkerMachine not because it was the best I could come up with, but realizing that writing content would be a better outlet of my time.

This post will go over how I set up my Netflify site to use a custom *blog* subdomain and Cloudflare as the authoritative DNS service.

## Buy the Domain
My domain registrar (entity that sells you the domain name) of choice was [Namecheap](https://www.namecheap.com/) simply because I had already registered a domain there previously. Domains on the *.xyz* TLDs in particular are quite cheap if you are not looking for something professional like *.com*. 

The [MDN Web Docs page on TLD](https://developer.mozilla.org/en-US/docs/Glossary/TLD) explains the various terminologies succintly.
> Consider an example Internet address: https://developer.mozilla.org Here org is the **TLD**; mozilla.org is the **second-level domain name**; and developer is a **subdomain name**. All together, these constitute a **fully-qualified domain name**; the addition of https:// makes this a **complete URL**. 

I will be referring to the second-level domain name as the main/root domain name (or even just domain) which is *tinkermachine.xyz* in my case. These are the names that we purchase from domain registrars and the memorable part of the website URL. 

## Cloudflare DNS
After buying the domain, the next step is to add the domain on Cloudflare in order to [manage the DNS functionality](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/manage-domains/).

One nifty feature is the automatic scanning and addition of the DNS records for the domain. Make sure the required A record and the CNAME record are created in the process.  

Simply put,  
*A record*: A name that points to an IPv4 address  
*CNAME record*: An alternate name for a domain.

There are many more [DNS records](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/) but these seem to be the absolute necessary ones to focus on while starting out.

Once done, all you have to do is [add the Cloudflare nameservers](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/) under the *Nameservers* section on Namecheap. Make sure to set it to *Custom DNS* first.

## Add Custom Domain on Netlify
On the Netlify dashboard, navigate to *Site Settings*, then *Domain Management* and add an entry under *Custom Domains*. Netlify will now prompt with the required CNAME record we would need to add on our DNS service which is Cloudflare in my case.

Netlify also provides it's own [DNS management service](https://docs.netlify.com/domains-https/netlify-dns/) in case you want to manage all the details of the site in one place.  

**Note**  
Make sure to change the *baseURL* setting for the blog in the Hugo `config.toml` file to ensure the links for the blog don't break. 

## Subdomain setup on Cloudflare
This site is hosted on the *blog* subdomain of the main/root domain which is *tinkermachine.xyz*. This can be easily done by adding a CNAME record which Netlify helpfully suggests from the earlier section.

It would look something like this:  
`CNAME  blog  tinkermachine.netlify.app`

where *tinkermachine.netlify.app* is the internal, Netlify generated URL for the blog based on the name I provided for the site.

The tricky bit was to find how to [redirect the root domain to the subdomain](https://developers.cloudflare.com/fundamentals/get-started/basic-tasks/manage-subdomains/#redirect-root-domain-to-a-subdomain) so that it wouldn't show an ugly error if someone might visit it. 

This was done through the [Bulk Redirects](https://developers.cloudflare.com/rules/bulk-redirects/concepts/) functionality on Cloudflare. Here, we set up a rule so that any traffic to the source URL *tinkermachine.xyz*  would be redirected (via an HTTP 301) to the target URL *https://blog.tinkermachine.xyz*.

## Links
- [Overview on domains](https://moz.com/learn/seo/domain)
- [How to set up DNS records for your domain in Cloudflare account](https://www.namecheap.com/support/knowledgebase/article.aspx/9607/2210/how-to-set-up-dns-records-for-your-domain-in-cloudflare-account/)