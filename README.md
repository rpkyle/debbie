![debbie](https://user-images.githubusercontent.com/9809798/65625175-50cb4580-df99-11e9-9596-19db83305173.png)
===
`debbie` is an R package which aims to simplify installation of binary versions of CRAN packages hosted in Debian repositories from within an R session. While CRAN mirrors do offer source versions of R packages, repeatedly compiling these can be time-consuming, or present challenges whenever compilation fails.

This package was originally a basic set of functions I found useful when deploying web applications with Dash for R. I've attempted to make it a bit more user-friendly in case anyone else finds it useful.

**What does `debbie` do?**
===

It's pretty simple: `debbie` includes a function called `install_deb` which will retrieve the Debian binary version of an R package given its name -- so to install `data.table` given the default mirror, the following should work:

```
library(debbie)
install_deb("data.table")
```

If a package name is unknown or unretrievable, `install_deb` will try to present a helpful error message before exiting gracefully.

```
> install_deb("foo")
Error in install_deb("foo") : 
  the package 'foo' was not found; the response returned was 404.
```

**Where is `debbie` obtaining the resources it uses for the installation?**
===

Debian Sources provides a nice API which permits searching source and package information via HTTP request, returning the results in JSON format.

The information returned when searching sources is relatively detailed (https://sources.debian.org/api/src/r-cran-data.table/):

```
{
  "package": "r-cran-data.table", 
  "path": "r-cran-data.table", 
  "pathl": [
    [
      "r-cran-data.table", 
      "/src/r-cran-data.table/"
    ]
  ], 
  "suite": "", 
  "type": "package", 
  "versions": [
    {
      "area": "main", 
      "suites": [
        "bullseye", 
        "sid"
      ], 
      "version": "1.12.6+dfsg-1"
    }, 
    {
      "area": "main", 
      "suites": [
        "buster"
      ], 
      "version": "1.12.0+dfsg-1"
    }, 
    {
      "area": "main", 
      "suites": [
        "stretch"
      ], 
      "version": "1.10.0-1"
    }, 
    {
      "area": "main", 
      "suites": [
        "jessie-backports"
      ], 
      "version": "1.10.0-1~bpo8+1"
    }
  ]
}
```

...while the information returned when querying the corresponding package is somewhat less informative (https://sources.debian.org/api/search/r-cran-data.table/):

```
{
  "query": "r-cran-data.table", 
  "results": {
    "exact": {
      "name": "r-cran-data.table"
    }, 
    "other": []
  }, 
  "suite": ""
}
```

In the absence of a full-featured package searching API, `debbie` uses the information retrieved from the sources API to construct a URL to the R binary package `.deb` file manually. Given a package name and release "code name" (`sid`, for example), `install_deb` will parse the JSON result, build this URL, then download the package (the default is to use the R session temporary directory returned by `tempdir()`).

Once downloaded, `unpackPackage` will then extract the R package subdirectory from the `.deb` file, which is packed using `ar`. If the appropriate (un)archiver can be found, and the `.deb` file itself contains a `data.tar.xz` archive, `unpackPackage` will place its contents into the temporary directory using `ar` and `utils::untar`.

`install_deb` then installs any required dependencies for the given package. The function attempts to be somewhat intelligent about this process, in that it will identify dependencies recursively using `miniCRAN::pkgDep`, and sort the results such that any packages available from Debian repos will be installed first -- and then the rest via CRAN.

Finally, `callr::rcmd` is used to install the precompiled package.

**What's the point of `debbie` when users can already download the packages via `apt`?**
===

While it's preferable to use `apt` after adding the appropriate repositories to `sources.list`, it's slightly more involved to do so when deploying web applications to Dash Enterprise or Heroku. 

This package may enable faster deployment of apps to remote hosts, while reducing the complexity of installing the packages in an environment where administrator privileges are unavailable. Additionally, although the largest collection of R package binaries is available from `sid`, most users will not want to configure this as the default branch in `sources.list` for all installs and updates. While it seems possible to selectively install only `r-cran-*` or `r-base-*` packages from `sid`, this configuration may not be intuitive for some users.

This package is very experimental. Like R, `debbie` is free software and comes with absolutely no warranty.
