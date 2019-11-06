## Miele-LXIV compilation

Alex Bettarini - 15 Mar 2015

Some of the pre-built toolkits in the `Binaries` directory are no longer provided. It's more appropriate to rebuild the toolkits from the sources downloaded from the respective repositories.

As of March 2019 the most convenient way of configuring and building the application is by following the instructions from the README file of this project: <https://github.com/bettar/miele-lxiv-easy>

If you want to fork the project and create your own branding, you should:

- create your own logo and icon
- customize the strings in `options.h` and `url.h`
- setup your own web server hosting a home page, and a page to allow checking for updates
- setup a server for bug reporting and management, for example [MantisBT](https://www.mantisbt.org), or you can use the system of issue tracking built into the GitHub
