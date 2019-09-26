![debbie](https://user-images.githubusercontent.com/9809798/65625175-50cb4580-df99-11e9-9596-19db83305173.png)
===
`debbie` is a basic R package to simplify installing binary versions of CRAN packages hosted in Debian repositories.

While it's preferable to use `apt` after adding the appropriate repositories to `sources.list`, it's slightly more involved to do so when deploying applications to Dash Enterprise or Heroku. This package may enable faster deployment of apps to remote hosts, while reducing the complexity of installing the packages in an environment where administrator privileges are unavailable.

This package is very experimental. Like R, `debbie` is free software and comes with absolutely no warranty.
