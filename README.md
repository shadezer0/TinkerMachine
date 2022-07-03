## Home of TinkerMachine.

![TM crop](https://user-images.githubusercontent.com/25390807/163201079-c0967783-2b7a-4fbd-8247-58cc1620604e.png)

- Hugo to generate static site contents. 
- Using [this theme](https://github.com/janraasch/hugo-bearblog)
- Netlify to build and deploy. 
- Using [Bamboo CSS](https://github.com/rilwis/bamboo) for styling

### Steps to get setup:
```bash
# clone repo to local
git clone https://github.com/shadezer0/TinkerMachine.git

# set up hugo theme
git submodule init
git submodule update

# serve static files for testing
hugo serve
# hugo serve -D to include draft posts
# hugo serve --noHTTPCache to prevent caching

# to update changes from upstream
# git submodule update --rebase --remote
```
