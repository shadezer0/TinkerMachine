+++
title = "{{ replace .Name "-" " " | title }}"
date = "{{ .Date }}"
tags = [{{ range $plural, $terms := .Site.Taxonomies }}{{ range $term, $val := $terms }}"{{ printf "%s" $term }}",{{ end }}{{ end }}]
draft = true
+++

This is a page about »{{ replace .Name "-" " " | title }}«.
