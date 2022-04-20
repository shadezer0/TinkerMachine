+++
title = "Research Burnout"
date = "2022-04-17T10:58:01+05:30"
tags = ["mindfulness", "non-technical"]
description = "Perils of delving into research for a project without any completion criteria"
+++

I stumble upon a variety of interesting applications or ideas to implement as personal projects. Here, I want to bring up the importance of strictly defined boundaries while doing research.

For example, I've been reading voraciously about VPNs currently. The idea of ad-blocking on the go by connecting to my local pihole instance remotely is where I initially started looking into VPNs and how they work. This includes everything from different approaches to VPN networks (central hub vs mesh network) and the various ways for management.

Apart from a basic [Wireguard](https://www.wireguard.com/) install, there are many OSS projects that implement a web GUI to make administration and management of the keys more seamless ([wg-easy](https://github.com/WeeJeWel/wg-easy) is a great option). There are other options that also build on top of the basic infrastructure like [Tailscale](tailscale.com/), [Nebula](https://github.com/slackhq/nebula) and [innernet](https://github.com/tonarino/innernet). This aimless meandering quickly lead to a state of burnout where I was clicking on links for all sorts of applications and ways to set up a VPN but confused on whether I should take that particular approach. How much should I be self-hosting at the risk of extra work, should I rent out a cloud server to host my VPN, is there a noticeable hit to my network speed or should I set it up in a container? 

The problem with this approach of digging around first before putting down what exactly I'm aiming to accomplish is that there's no defined end state. I can keep looking up new and interesting VPN projects but I'll never know for certain what it is that I'm hoping to set up for myself and where I can draw the line for project completion.

I realize that I love to delve deep into a topic and figure out the nitty-gritty details on how something works. But rarely do I ask myself - is this something I want to spend my time researching? I forget to consider the big picture view of how the content I'm reading ties in with achieving my larger project goals. I find something interesting and jump right in realizing only later that it might not be relevant. 

In my VPN scenario, I concluded that my primary requirement was to connect to my devices from outside my LAN. This basic constraint helps me to filter out relevant content from what's not. So a simple Tailscale setup allowed me to connect to my devices remotely without worrying too much about implementation details.

The scope of obtainable information from the internet is vast while your time and energy are limited. The main takeaway here is to set aside some initial time figuring out what you aim to accomplish through a project before diving deep into any specific topics.
