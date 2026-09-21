# Publish the AKsf package website

The site is built with [pkgdown](https://pkgdown.r-lib.org/) and is intended for
**https://jimianelli.github.io/AKsf/**. It includes the README, function reference,
tutorials (including GMT), and release notes. GitHub Pages hosts documentation;
it does not register the package with CRAN or make a private source repository
installable by everybody.

## First publication

1. Choose source visibility. A public repository supports Pages on GitHub Free.
   Keeping the source private requires an eligible paid plan; the documentation
   site can still be publicly visible. See [GitHub's Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages).
2. Open repository **Settings → Pages**, then choose **GitHub Actions** as the
   build/deployment source.
3. Open **Actions → Package website → Run workflow** on `main`.
4. The deploy job reports the website URL. Allow time for the first deployment.

The workflow builds on every push, but publishes only when manually dispatched.
This makes a public documentation release deliberate while the repository's
visibility is being decided. To publish on every main-branch push after setup,
remove the deploy job's `if: github.event_name == 'workflow_dispatch'` line.

## Local preview

```r
install.packages("pkgdown")
source("pkgdown/build.R")
pkgdown::preview_site()
```

Generated HTML goes in ignored `_site/`, not the maintained `docs/` folder.
The build copies supporting maps and integration examples into the site.
GMT is not needed to build the documentation; its rendered example is a static
asset. The website and R package checks have separate workflows.
