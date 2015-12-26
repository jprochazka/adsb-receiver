# CHANGELOG :airplane:

The following is a history of the changes made to this project.

## December 25th, 2015

* Scripts now properly detect if an ADS-B Exchange sharing has already set up.
* The PiAware 2.1-5 tag is now used when installing the PiAware software.
* Added link to portal pointing to the local Plane Finder ADS-B Client web interface.
* The path to Lighttpd's root directory is now read from the Lighttpd configuration.

## December 23st, 2015

* Terrain limitation data able to be downloaded for display in the dump1090 map.
* Added check to make sure whiptail is installed.

## December 21rd, 2015

* Can now choose to install only certain items while leaving others out.
* Uses whiptail dialogs during the intital portion of the setup.
* Data sharing options are now presented in multiple choice form.
* Does not display installation options for software already installed.
* Dump1090-mutability map now positioned correctly within the map page.
* Removed option to install the MalcolmRobb version of dump1090.

## December 16th, 2015

* Bandwidth graph now displays information for the eth0 interface by default.
* Script halts if critical packages do not install.
* Script halts if prerequisite packages are not installed within 5 attempts.
* The piaware_builder source is now ran from the v2.1-3 tag.
* Renamed the collectd folder to graphs.
* Added navigation header to the Dump1090 map.
* Added adsbexchange-maint.sh to this repository.
* Performance graph cron jobs moved to file located in /etc/cron.d.
* Can share data to ADS-B Exchange without PiAware installed.
* Plane Finder ADS-B Client package now installs on Debian x86_64.
* Plane Finder ADS-B Client package now installs on Ubuntu x86_64.
