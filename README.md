FITScope
========

[![Build Status](https://img.shields.io/github/actions/workflow/status/macmade/FITScope/ci-mac.yaml?label=macOS&logo=apple)](https://github.com/macmade/FITScope/actions/workflows/ci-mac.yaml)
[![Issues](http://img.shields.io/github/issues/macmade/FITScope.svg?logo=github)](https://github.com/macmade/FITScope/issues)
![Status](https://img.shields.io/badge/status-active-brightgreen.svg?logo=git)
![License](https://img.shields.io/badge/license-mit-brightgreen.svg?logo=open-source-initiative)  
[![Contact](https://img.shields.io/badge/follow-@macmade-blue.svg?logo=twitter&style=social)](https://twitter.com/macmade)
[![Sponsor](https://img.shields.io/badge/sponsor-macmade-pink.svg?logo=github-sponsors&style=social)](https://github.com/sponsors/macmade)

### About

FITS Image Viewer for macOS.

### Supported Formats

FITScope renders the first image HDU of a FITS file (the primary HDU, or the
first image extension when the primary header is empty). The following formats
are supported:

  - **Pixel format (`BITPIX`):** `8`, `16`, `32`, `-32`, `-64`
  - **Geometry (`NAXIS`):** `2` (a single two-dimensional image)
  - **Scaling:** `BSCALE` / `BZERO`, in integer or floating-point form
  - **Color:** optional Bayer demosaicing via `BAYERPAT`

The following are not currently supported and surface a clear error message:

  - `BITPIX` `64` (64-bit integer pixels)
  - `NAXIS` other than `2` (e.g. 3-D cubes or multi-plane images)

### Cloning

This project uses submodules.  
To clone it, use the following command:

```bash
git clone --recursive https://github.com/macmade/FITScope.git
```

License
-------

Project is released under the terms of the MIT License.

Repository Infos
----------------

    Owner:          Jean-David Gadina - XS-Labs
    Web:            www.xs-labs.com
    Blog:           www.noxeos.com
    Twitter:        @macmade
    GitHub:         github.com/macmade
    LinkedIn:       ch.linkedin.com/in/macmade/
    StackOverflow:  stackoverflow.com/users/182676/macmade
