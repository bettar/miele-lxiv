## Miele-LXIV compilation

Alex Bettarini - 15 Mar 2015

Some of the pre-built toolkits in the `Binaries` directory are no longer provided. It's more appropriate to rebuild the toolkits from the sources downloaded from the respective repositories. The Xcode project expects rebuilt OpenJPEG and DCMTK artifacts under `Binaries/openjpeg` and `Binaries/DCMTK`, respectively.

As of March 2019 the most convenient way of configuring and building the application is by following the instructions from the README file of this project: <https://github.com/bettar/miele-lxiv-easy>

Fresh clones use the defaults in `options.in.h` and `url.in.h`. If you want to
fork the project and create your own branding, customize those templates and:

- create your own logo and icon
- customize the strings in `options.in.h` and `url.in.h`
- setup your own web server hosting a home page, and a page to allow checking for updates
- setup a server for bug reporting and management, for example [MantisBT](https://www.mantisbt.org), or you can use the system of issue tracking built into the GitHub
