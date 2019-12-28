#' Retrieve an R package binary from Debian's package repository
#'
#' This function attempts to download an R package compiled for
#' Debian (which may work on hosts running Ubuntu also) using
#' curl to the directory specified in \code{path}.
#' @param url A character string which represents a valid URL to an R package.
#' @param path A character string describing the path where the package should be downloaded. Defaults to \code{tempdir()}.
#' @keywords Debian download binary package 
#' @export
retrievePackage <- function(url, path=tempdir()) {
  package_archive <- file.path(path, basename(url))
  curl::curl_download(url, destfile=package_archive)
}

#' Extract a Debian archive containing an R package binary
#'
#' This function uses \code{untar} to extract the R package from within a Debian
#' archive.
#' @param pkg_path A character string describing the location of the compressed package.
#' @param pkg_file A character string describing the filename of the Debian package.
#' @param dest_path A character string describing the intended destination directory of the package.
#' @keywords extract untar Debian binary 
#' @export
unpackPackage <- function(pkg_path = tempdir(), pkg_file, dest_path = tempdir()) {
  if (Sys.which("ar") == "")
    stop("the ar command is required to unpack the Debian package binaries, and was not found. Please ensure ar is available and in your current path.")
  
  system(command = sprintf("cd %s && ar x %s %s", dest_path, file.path(pkg_path, pkg_file), "data.tar.xz"))
  
  if (!file.exists(file.path(dest_path, "data.tar.xz"))) {
    reports <- utils::packageDescription("debbie")$BugReports
    stop(sprintf("the Debian package does not contain data.tar.xz; please consider reporting this error via %s.", reports))
  }
  
  utils::untar(file.path(dest_path, "data.tar.xz"), exdir=dest_path)
}

#' Determine Whether an R Package Exists in Debian Sources Repository
#'
#' This function attempts to query the Debian sources repository API for
#' an R package, provided as a string. The function returns a list with the
#' API's response as well as a value of \code{TRUE} if found, and \code{FALSE}
#' otherwise.
#' 
#' @param package A character string describing an R package, for which a search of the Debian package repository will be performed. 
#' @param deb_mirror A character string which represents a valid URL to a Debian package mirror's R package tree. Default is to use http://deb.debian.org/debian/pool/main/r.
#' @param sources_url A character string which represents a valid URL to a Debian sources API. Default is https://sources.debian.org/api/src.
debPkgAvailable <- function(package, deb_mirror, sources_url) {
  if (httr::http_error(deb_mirror))
    stop("the specified Debian mirror URL does not exist or is unavailable. Please ensure that the URL describes the path to a valid Debian R package tree.")
  
  # remove r-cran from package name if present
  package <- gsub("r-cran-", "", package)
  
  # remove trailing slash(es) from URLs if present
  deb_mirror <- gsub("/+$", "", deb_mirror)
  sources_url <- gsub("/+$", "", sources_url)
  
  result <- jsonlite::fromJSON(sprintf("%s/r-cran-%s/", sources_url, tolower(package)))
  
  if ("error" %in% names(result)) {
    return(list(FALSE, result))
  } else {
    return(list(TRUE, result))
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
#' @param pkg_ver A character string describing a particular version of an R package, for which a search will be performed. 
#' @param deb_mirror A character string which represents a valid URL to a Debian package mirror's R package tree. Default is to use http://deb.debian.org/debian/pool/main/r.
#' @param cran_mirror A character string which represents a valid CRAN mirror URL, for use when code{fallback = TRUE}. Default is to use https://cloud.r-project.org/.
#' @param sources_url A character string which represents a valid URL to a Debian sources API. Default is https://sources.debian.org/api/src.
#' @param release A character string describing the desired Debian release code name, default is \code{sid}.
#' @param pkg_path A character string describing the intended destination directory of the package when downloaded. Default is the session temporary directory given by \code{tempdir()}.
#' @param opts A vector of character strings containing command line arguments for \code{INSTALL}, used when installing the downloaded package. Default is \code{--no-docs}, \code{--no-multiarch}, \code{--no-demo}.
#' @param echo Logical. A Boolean flag passed to \code{callr::rcmd} which indicates whether the complete command should be echoed to the R console.
#' @param show Logical. A Boolean flag passed to \code{callr::rcmd} which indicates whether the standard output of the \code{INSTALL} command run by \code{callr::rcmd} should be displayed while the process is running.
#' @param fail_on_status Logical. A Boolean flag passed to \code{callr::rcmd} which controls whether an error should be thrown if the underlying process terminates with a status code other than 0. Default is \code{TRUE}.
#' @param use_binary Logical. A Boolean flag specifying whether dependencies should be fetched using \code{install_deb}. Default is \code{TRUE}.
#' @param recursive Logical. A Boolean flag specifying whether \code{install_deb} should recursively search for dependencies. Default is \code{TRUE}.
#' @param upgrade Logical. A Boolean flag specifying whether to automatically upgrade packages using \code{install_deps}. Has no effect unless \code{recursive = FALSE}
#' @param fallback Logical. A Boolean flag specifying whether to fall back to using CRAN for a given dependency if no binary package is available. Default is \code{TRUE}.
#' @param ... Arguments to be passed on to \code{remotes::install_deps}.
#' @keywords Debian binary install packages 
#' @export
install_deb <- function (package = NULL, 
                         pkg_ver = NULL,
                         deb_mirror = "http://deb.debian.org/debian/pool/main/r", 
                         cran_mirror = "https://cloud.r-project.org/",
                         sources_url = "https://sources.debian.org/api/src",
                         release = "sid",
                         download_path = tempdir(), 
                         opts = c("--no-docs", "--no-multiarch", "--no-demo"),
                         echo = FALSE,
                         show = TRUE,
                         fail_on_status = TRUE,
                         use_binary = TRUE,
                         recursive = TRUE,
                         upgrade = "never",
                         fallback = TRUE,
                         ...) 
{
  if (!is.null(package)) {
    pkg_data <- debPkgAvailable(package, deb_mirror, sources_url)
    
    pkg_status <- pkg_data[[1]]
    result <- pkg_data[[2]]
    
    if (pkg_status == FALSE && fallback == FALSE) {
      stop(sprintf("the package '%s' was not found; the response returned was %s.", package, result$error))
    } else if (pkg_status == FALSE && fallback == TRUE) {
      install.packages(package, repos = cran_mirror)
    } else {
      # ensure that release is available
      indexes <- vapply(result$versions$suites, function(x) any(release %in% x), logical(1))
      if (!any(indexes == TRUE)) 
        stop(sprintf("no matches found for release '%s' given package '%s'.", release, package))
      
      # retrieve newest package unless provided  
      if (is.null(pkg_ver)) {
        pkg_ver <- result$versions$version[indexes][[1]]
      } else {
        if (result$versions[indexes,]$version != pkg_ver)
          stop(sprintf("no matches found for release '%s' and version '%s' of package '%s'.", release, pkg_ver, package))
      }
      
      base_url <- sprintf("%s/r-cran-%s/", deb_mirror, tolower(package))
      filename <- sprintf("r-cran-%s_%s_amd64.deb", tolower(package), pkg_ver, ".deb")
      url <- sprintf("%s%s", base_url, filename)
      
      if (!httr::http_error(url))
        retrievePackage(url, download_path)
      else {
        url <- sprintf("%s%s", 
                       base_url, 
                       sprintf("r-cran-%s_%s_all.deb", tolower(package), pkg_ver, ".deb"))
        if (!httr::http_error(url))
          retrievePackage(url, download_path)
        else {
          reports <- utils::packageDescription("debbie")$BugReports
          stop(sprintf("Error: the package '%s' could not be retrieved. The URL used was '%s'; if a valid Debian mirror was specified, please consider submitting a message with a bug report to %s",
                       package, 
                       url,
                       reports))
        }
      }
      
      unpackPackage(download_path, 
                    pkg_file=basename(url), 
                    dest_path=download_path)
      package_match <- gregexpr(pattern = "(?<=r-cran-)(.*?)(?=\\_)", 
                                basename(url), 
                                perl = TRUE)
      package_name <- unlist(regmatches(basename(url), package_match))
      
      # try to protect ourselves from case sensitivity; some
      # Debian packages store their assets in a subfolder whose
      # case does not match the package name; this is a workaround
      path_to_assets <- file.path(download_path, "usr/lib/R/site-library")
      actual_path <- list.files(path_to_assets)[(tolower(package_name) == tolower(list.files(path_to_assets)))]
      package_path <- file.path(path_to_assets, actual_path)
      
      browser()
      
      if (!dir.exists(package_path))
        stop(sprintf("the inferred package path is invalid; check to see whether the Debian package includes the subdirectory 'usr/lib/R/site-library/%s'.", actual_path))
      
      path_to_description <- file.path(package_path, "DESCRIPTION")
      raw_deps <- read.dcf(path_to_description, fields = c("Depends", "Imports"))
      pruned_deps <- gsub(",* *R \\([^()]*\\),* *", "", raw_deps)
      pruned_deps <- pruned_deps[!is.na(pruned_deps)]
      
      if (recursive == TRUE && use_binary == TRUE && !all(pruned_deps == "")) {
        unformatted_deps <- pruned_deps[!pruned_deps == ""]
        comma_separated_deps <- paste0(unformatted_deps, collapse = ", ")
        list_of_deps <- strsplit(comma_separated_deps, ", ")
        list_of_deps <- lapply(list_of_deps, function(x) gsub(" *\\([^()]*\\)", "", x)) # ignore version for now
        deps_to_install <- unlist(list_of_deps)
        # limit to those packages not currently installed
        # using invisible avoids an annoying warning about workspaces and R versions
        installed_packages <- invisible(as.data.frame(installed.packages())[,"Package"])
        deps_to_install <- deps_to_install[!deps_to_install %in% installed_packages]
        
        if (length(deps_to_install) != 0) {
          # recursively find all necessary dependencies        
          deps_to_install <- miniCRAN::pkgDep(deps_to_install, suggests=FALSE)
          
          available <- vapply(deps_to_install, 
                                function(x) 
                                  debPkgAvailable(x, 
                                                  deb_mirror, 
                                                  sources_url)[[1]],
                                                  logical(1)
                                )
          
          if (any(available == TRUE)) 
            message(sprintf("debbie is now attempting to install precompiled packages %s for %s from the Debian repository ...", 
                            paste0(deps_to_install[available], collapse = ", "),
                            package_name))
          
          if (any(available == FALSE))
            message(sprintf("debbie will also install source packages %s for %s from CRAN (not currently available as binaries)...", 
                            paste0(deps_to_install[!available], collapse = ", "),
                            package_name))
          
          # try to install binary package versions first
          sorted_deps <- sort(deps_to_install, decreasing=TRUE)
                    
          invisible(lapply(c(deps_to_install[available], deps_to_install[!available]), 
                           function(x) {
                             install_deb(
                               package = x,
                               deb_mirror = deb_mirror,
                               cran_mirror = cran_mirror,
                               sources_url = sources_url,
                               release = release,
                               download_path = download_path,
                               opts = opts,
                               echo = echo,
                               show = show,
                               fail_on_status = fail_on_status,
                               use_binary = TRUE,
                               recursive = FALSE)
                           }
          ))
        } else if (use_binary == FALSE) {
          remotes::install_deps(pkgdir = package_path, upgrade = upgrade, ...)
        }
      }
      
      invisible(callr::rcmd("INSTALL", c(package_path, opts), echo = echo, show = show, fail_on_status = fail_on_status))
    }
  } else stop("no R package name was provided. Please supply the name of the R package to install as a character string.")
}
