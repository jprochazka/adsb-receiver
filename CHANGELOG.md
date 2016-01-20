# CHANGELOG :airplane:

The following is a history of the changes made to this project.

## January 20th, 2016

* Added the ability to build and execute dump978.

## January 14th, 2016

* When the portal is installed the argument --measure-noise is added to the dump1090-mutability init script.
* Added "noise" level line and information to the signal level performance graph.

## January 8th, 2016

* The dump1090-mutability install Script now asks user for the latitude and longitude of the feeder.
* Dump1090-mutability is now set to listen for BEAST input on port 30104.
* PiAware is no longer configured to send MLAT data over port 30001.
* Behind the scenes work mainly dealling with cleaning up the scripting a little.
* Consolidated software version variables into a single file.
* The CheckPackage function is no longer repeatative throughout all the scripts needing it.
* Added the ChangeConfig function as a way to easily change settings stored in a configuration file.
* Removed the ability to use rpi-updater to update Raspberry Pi firmware from the scripts.

## January 5th, 2016

* The PiAware 2.1-5-jessie tag is now used when installing the PiAware software to address certificate errors.
* There is a known issue with upgrade detection for PiAware since changing to the 2.1-5-jessie tag.
* Fixed PiAware mlatResultsFormat setting were not being set on clean installations.
* Changes relating to Orange Pi compatability mainly pertaining to prerequisite packages.

## December 29th, 2015

* Now asks if the user wishes to reinstall dump1090-mutability.
* Added ability to upgrade FlightAware's PiAware if a newer verison is available.
* Added ability to upgrade the Plane Finder ADS-B Client if a newer version is available.
* PiAware mlatResultsFormat setting is no longer reset when ran more than once.

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
