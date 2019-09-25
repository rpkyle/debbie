#' Retrieve an R package binary from Debian's package repository
#'
#' This function attempts to download an R package compiled for
#' Debian (which may work on hosts running Ubuntu also) using
#' curl to the directory specified in `path`.
#' @param url A character string which represents a valid URL to an R package.
#' @param path A character string describing the path where the package should be downloaded. Defaults to /tmp.
#' @keywords Debian download binary package 
#' @export
retrievePackage <- function(url, path="/tmp") {
  package_archive <- file.path(path, basename(url))
  curl::curl_download(url, destfile=package_archive)
}

#' Extract a Debian archive containing an R package binary
#'
#' This function uses `untar` to extract the R package from within a Debian
#' archive, and, if `clean` is `TRUE`, deletes all non-package directories
#' extracted from the archive.
#' @param pkg_path A character string describing the location of the compressed package.
#' @param dest_path A character string describing the intended destination directory of the package.
#' @param clean Logical. A Boolean flag indicating whether the non-package directories extracted from the archive should be deleted.
#' @keywords extract untar Debian binary 
#' @export
unpackPackage <- function(pkg_path, pkg_file, dest_path, clean=TRUE) {
  system(command = sprintf("ar x %s %s", file.path(pkg_path, pkg_file), "data.tar.xz"))
  utils::untar(file.path(dest_path, "data.tar.xz"), exdir=dest_path)
  
  if (clean) {
    file.copy(list.dirs(file.path(dest_path, "usr/lib/R/site-library"))[-1], to=dest_path, overwrite=TRUE, recursive=TRUE)
    unlink(file.path(dest_path, "usr/lib/R/site-library"), recursive=TRUE)
  }
}

#' Install an R package from the Debian Package Repository 
#'
#' This function attempts to retrieve a Debian binary package corresponding
#' to a (source) R package, which is then extracted and installed, without
#' having to configure or edit the apt sources.list file.
#'
#' This can be useful if you're in a hurry, or want to simplify the install
#' process for users who have limited familiarity with system configuration
#' but wish to avoid the time required to retrieve and compile R packages
#' for Debian or Ubuntu from CRAN or GitHub.
#'  
#' @param package A character string describing an R package, for which a search of the Debian package repository will be performed. 
#' @param url A character string which represents a valid URL to an R package.`
#' @param pkg_path A character string describing the location of the compressed package.
#' @param dest_path A character string describing the intended destination directory of the package.
#' @param clean Logical. A Boolean flag indicating whether the non-package directories extracted from the archive should be deleted.
#' @param ... Arguments to be passed on to `install.packages`.
#' @keywords Debian binary install packages 
#' @export
install_deb <- function(package=NULL, 
                        url=NULL, 
                        pkg_path="/tmp", 
                        dest_path="/tmp",
                        clean=TRUE,
                        ...) {
  if (!is.null(url)) {
    retrievePackage(url, pkg_path)
    unpackPackage(pkg_path=pkg_path, pkg_file=basename(url), dest_path=dest_path, clean=clean)
    
    packageMatch <- gregexpr(pattern="(?<=r-cran-)(.*?)(?=\\_)", basename(url), perl=TRUE)
    packageName <- unlist(regmatches(basename(url), packageMatch)) 

    options(install.packages.check.source = "no")
    utils::install.packages(file.path(path, packageName), repos=NULL, type="binary", ...)
  }
}
