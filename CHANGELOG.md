# CHANGELOG :airplane:

The following is a history of the changes made to this project.

## v2.8.9 *(November 11th, 2025)*

* Added the option to install the AirNav Radar rbfeeder client.
* Removed scripting for FlightAware's version of the tcl-tls package.
* Updated current feeder client versions in the variables file.
* Removed support for Ubuntu 20.04 Focal Fossa.

## v2.8.8 *(October 18th, 2024)*

* FlightAware's version of the tcl-tls is now built and installed on Bullseye.
* Clones the trixie branch directly when using the forked version of piaware_builder.
* The portal upgrade path to v2.8.7 was missing.

## v2.8.7 *(August 23rd, 2024)*

* The ability to install dumpvdl2 is now available as a decoder option.
* The ability to install vdlm2dec is now available as a decoder option.
* The ability to install Readsb is now available as a decoder option.
* The ability to install Graphs1090 is now available as an extras option.
* The ability to install tar1090 is now available as an extras option.
* Added missing Noble dependency to PiAware install script.
* Fixed Noble detection problem found within the PiAware install script.
* All decoder menus have been modified to support additional installation options.
* Device assignment scripting has been modified to work within functions.sh.
* Cleanup and consolidation performed on the PHP ADS-B Portal installation scripts.
* Merged the dump1090-tools copyright notice into the file dump1090.py.

## v2.8.6 *(August 13th, 2024)*

* The option to install ACARSDEC and ACARSSERV is now available as a decoder option.
* ACARS data stored by ACARSSERV can be viewed via the existing PHP portal.
* Added the ability to reconfigure, rebuild, and reinstall both dump1090-fa and dump978.fa.
* Decoder scripts now ask for device assignments when additional decoders are being installed.
* Added "Contributors" to the copyright notice in the software license.
* Had to remove logging of check_package output due to whiptail issue encountered with pipe.

## v2.8.5 *(July 23rd, 2024)*

* The PiAware installation script now supports Ubuntu Noble Numbat. *(unofficial fix)*
* The installation of PiAware is no longer required when choosing to install dump1090-fa.
* The dump1090-fa installation script now mimics the current dump1090-fa installation instructions.
* All scripts excluding those related to the portal now utilize the new logging functions.
* Logging to the logs directory is enabled by default but can be disabled with --no-logging or -n.
* Added variables which can be modified to adjust text colors used by the bash scripts.
* Added the --version and -v arguments in order to display the current project version.
* Additional script cleanup done to various files.
* Removed scripting used for image setup.
* Updated the latest Flightradar24 Client version to 1.0.48-0.

## v2.8.4 *(July 13th, 2024)* :rooster:

* Added the option to install the airplanes.live feeder client and web interface.
* Can now toggle daily data purges as well specify the number of days to keep within the portal.
* Rewrote the aircraft.py script and fixed issues found with newer versions of dump1090.
* Rewrote the maintenance.py script and addressed issue mentioned in an incompatible pull request.
* The page displaying plots now shows missing data in the side bar revealing when clicking on marker.
* Added images to the side bar displayed when the marker is clicked when viewing the plots page.
* The flights page now only shows links when position information is present in the database.

## v2.8.3 *(July 7th, 2024)* :chicken:

* Added the option to install the Fly Italy ADS-B feeder client.
* Tested installation processes on Armbian Bookworm.
* Tested installation processes on Armbian Jammy.
* Unnecessary RTL-SDR kernel modules are once again blacklisted during decoder installs. 
* ADS-B Receiver Project repository updates now work properly when executed by the script.
* Instead of creating a new branch, changes to tracked files are now stashed before updating.
* The --development and -d parameters are now respected by the install scripts.
* The --branch <branch_name> and -b <branch_name> parameters properly specify the branch to use.
* Fixed issue noticed in the line downloading the Duck DNS log during setup.
* Refactoring and standards compliance changes were made to multiple bash scripts.
* The proper collectd CPU temperature configuration is inserted for Raspberry PI 4 Model B devices.

## v2.8.2 *(June 29th, 2024)* :baby_chick:

* Added the option to install the ADS-B Exchange stats package after feeder installation.
* Added the option to install the ADS-B Exchange web interface after feeder installation.
* Added support for Ubuntu Jammy Jellyfish.
* Added support for Ubuntu Focal Fossa.
* Added support for DietPi Bookworm.
* Added support for DietPi Bullseye.
* Fixed issue where navigation element toggling was not working in lite installs. 
* Added eno1 and wlo1 to network options in the administration settings section of the portal.
* The ADS-B Max Range temperature graph is now displayed in system performace the graphs collection.
* The Core Temperature graph is now displayed in system performace the graphs collection.

## v2.8.1 *(June 27th, 2024)* :hatched_chick:

* Plane Finder Feeder now installs properly on aarch64 operating systems.
* Fix problem where multiple instances of flights.py and maintenance.py were being launched.
* Addressed portal map centering settings not being added to the database on fresh installs.
* An issue was addressed allowing existing receivers to upgrade to phoenix properly.

## v2.8.0 *(June 24th, 2024)* :hatching_chick:

* The dump1090-fa and piaware_builder install process has been updated to support the latest versions.
* The dump978 script has been rewritten in order to use FlightAwares version of dump978.
* The Beast Splitter script has been updated to work with the current version of Beast Splitter.
* The Flightradar24 script has been updated to work with the current install script.
* The Plane Finder script has been updated to work with current client releases.
* The ADS-B Exchange script has been updated to work with the current install script.
* The ADSB Exchange script has been updated to work with the current install script.
* The OpenSky Feeder script has been updated to work with the current install script.
* Version check for dump1090-fa has been fixed.
* Fix bug where PiAware was installed every run even if already installed.
* Removed the unattended install option for the time being.
* Removed the option to install dump1090-mutability.
* Removed the option to install dump1090 HPTOA.
* Removed the option to install AboveTustin.
* Removed the option to install ADSBHub support due to the fact it was incomplete.
* Removed incomplete RTL-SDR OGN setup scripting.
* The portal install scripts have been updated to work on current operation systems.
* All portal related Python scripts have been updated to work with Python 3.
* TinyMCE has been replace by CKeditor in the portal.

## v2.7.2 *(prerelease)*

* Updated current PiAware and dump1090-fa versions to 3.9.3. 
* When installing dump1090-fa the maintainer packages for libbladerf are used.
* Removed installation restriction for dump1090-fa on Ubuntu.
* Fixed reported JSON incompatabilities with dump1090-fa. *(advanced)*
* Removed Flightradar24 ARM client version from variables file.
* Fixed issue pertaining to theremoval of old style ADS-B Exchange rc.local enties.
* Added indexes to tables to improve performance. (thanks to @target-drone) *(advanced)*

## v2.7.1 *(not released)*

* Added missing purgeAircraft setting to the database. *(advanced)*

## v2.7.0 *(not released)*

* Added option to install dump1090-hptoa.
* Added ADSBHub support.
* Added OpenSky Network support
* Graph data now restored properly by the backup script.
* Script now checks for php7.2-sqlite3 instead on php7.2-sqlite on Ubuntu 18.04+.

## v2.6.3 *(June 23rd, 2018)*

* Fix to navigation bar auto hiding code submitted by @vitaliy-sk.
* SQLite query fix submitted by @vitaliy-sk.
* DefaultCenterLat and DefaultCenterLon in dump1090-mutabilities config.js is now set.
* Checks for the location of socat and uses the proper path to feed ADS-B Exchange.
* Added switch to force apt update when executing install.sh.
* Updated current Planefinder client versions to 4.1.1.
* Updated current dump1090-fa version to 3.2.3.
* The system page bandwidth meter now defaults to MB/sec on fresh installations.

## v2.6.2 *(April 6th, 2018)*

* Images created using the latest version of Raspbian which supports the Raspberry Pi 3 b+.
* Option to install dump1090-fa removed on Ubuntu 17.10 or higher due to cx_freeze issue.
* Fixed so Ubunbtu 17.10 and higher properly installs PHP 7.1 and its related packages.
* ADS-B Exchange run script now uses socat instead of netcat to send data.
* Removed Mapzen support from the scripts due to the service shutting down.
* Added option to auto hide portal navigation and footer elements. (thanks to @Mictronics)
* User can opt to skip the installation of the Postfix MTA using the --mta= flag.
* OS and release variables temporarily exported to save repeating the detection process.

## v2.6.1 *(February 28th, 2018)*

* Readded missing RTL-SDR kernel module blacklist to dump1090-mutability script.
* Password recovery token column used for password retrieval not added properly in the past.
* Postix package installation was removed at some point and is now reintroduced.
* When created remote database users are now allowed to access the server remotly.
* Fixes to issues contained within maintenance.py. (thanks to @mkrzysztofowicz)
* Consolidated simple queries which run on both MySQL and SQLite in maintenance.py.
* Dump1090-mutability wget permission error fixed. (thanks to SCX77)
* Latitude and longitude sent to get altitude was hard coded in ADS-B Exchange script.
* The ADS-B Exchange script was not getting latitude and longitude from dump1090-mutability.
* Fixed RTLSDR device permissions issue by downloading rtl-sdr.rules if not present.
* The option to upgrade the Planefinder client now appears when one is available.
* Updated to install planefinder.net ARM client version 3.7.40.
* Updated to install PiAware version 3.5.3.
* The version of mlat-client installed has been reverted back to v0.2.6 from v0.2.9.
* Fixed path variable to where the built dump1090-mutability packages are archived.
* Fixed path variable used to check if the ADS-B Exchange build directory exists.
* Simplified and fixed lines killing existing ADS-B Exchange processes during reinstallation.
* Simplified and fixed lines killing existing AboveTustin processes during reinstallation.
* Simplified and fixed lines killing existing BeastSplitter processes during reinstallation.
* Fixed many minor bash script output syntax and formating issues.
* Some Whiptail dialogs have been expanded to be more descriptive.
* AboveTustin script was not retriving the current longitude when upgrading it.

## v2.6.0 *(October 21st, 2017)*

* Added "Extras" option to install process.
* Added the ability to install beast-splitter as an extra.
* Added the ability to setup Duck DNS dynamic DNS service as an extra.
* Added the ability to setup the AboveTustin Twitter bot.
* Ubuntu 16.04 and above now detected properly when deciding which version of PHP to use.
* Raspbian 9 and above now detected properly when deciding which version of PHP to use.
* Debian 9 and above now detected properly when deciding which version of PHP to use.
* As requested users must now claim PiAware receivers via the FlightAware site.
* Updated to install mlat-client version 0.2.9.
* Updated to install planfinder.net ARM client version 3.7.20.
* Updated to install planfinder.net I386 client version 3.7.1.
* Updated to install PiAware version 3.5.1.
* Creates and enables /etc/rc.local if dump978 is installed.
* Creates and enables /etc/rc.local if ADS-B Exchange support is added.
* Added check for the dvb_usb_rtl28xxu kernel module before trying to remove it.
* Checks for the package dirmngr before executing the Flightradar24 setup script.
* Fixed text displaying date time formats which were swapped in the portal settings.
* Help pertaining to the new switches is available using the -h or --help switch.
* An installation log file can be kept by using either the -l or --log-output switch.
* The branch you wish to use can be specified using the -b or --branch switch.
* Pagination on the flights page has been minimized.
* Corrected the page count on the flights page.
* Added -d --development flags to install.sh to avoid overwriting changes made.
* All .deb packages built by the scripts are archived in an archive folder.
* Addressed issue where altitude was not returned when setting up ADS-B Exchange feed.
* Dump1090-mutability --measure-noise argument moved to the configuration file.

## v2.5.0 *(December 5th, 2016)*

* Can now specify the unit of measurement for dump1090-mutability during setup.
* Users can now specify the repository branch they wish to use in the file install.sh.
* Possible fix for blog post containing characters not UTF-8 compatible. *(lite)*
* Added script to automate the portal backup process.
* Added ability to specify the latitude and longitude of the receiver for dump978.
* Administrators can now specify custom links to be displayed within the portal.
* The loading speed for the flights page has been dramatically reduced. *(advanced)*
* When upgrading dump1090 the user is once again asked for the LAT and LON settings.
* Portal related python scripts are now located in the folder named python.
* A Google Maps API key can now be specified for use with portal maps.
* When setting up dump1090-mutability the user is asked for a Bing Maps API key.
* When setting up dump1090-mutability the user is asked for a Mapzen API key.
* Portal upgrade scripts have been split into multiple files.
* The path to the SQLite database is no longer hard coded in the portal PHP files.
* Pagination links now show first and last page links properly.
* When no patch is applied N\A is given for the patch version on the system page.
* Yes set to default when asked whether to bind dump1090-mutability to all IP addresses.
* Fixed issue with install script causing PiAware to not upgrade.
* Fixed collectd graph generation script so it works with newer versions of rrdtool.
* The navigation bar for the default portal template has been modified to fit better.

## v2.4.0 *(September 27th, 2016)*

* Users can now choose to install dump1090-fa instead of dump1090-mutability.
* Scripts are now updated from the master branch each time install.sh is ran.
* The file install.sh now executes ~/bash/main.sh after updates are applied.
* Changed dump1090-mutability build directory to ~/build/dump1090-mutability.
* Removed dump1090-fa map option from portal due to the fact it is no longer needed.
* Flights.py has been temporariliy switched back to reading aircraft.json over HTTP.

## v2.3.0 *(September 15th, 2016)*

* Massive clean up and in some cases an overhaul of the installation bash scripts.
* Updated the dump978 map by modifying newer dump1090-mutability map.
* Crontab errors pertaining to collectd no longer emailed to the root user.
* The image setup script now executes the portal install scripts to setup the portal.
* Script now comments out NET_BIND_ADDRESS to bind dump1090-mutability to all IPs.
* Moved the logging portion of the portal install script into it's own file. *(advanced)*
* Flights.py has been optimized even further. *(advanced)*
* Flights.py now logs the aircraft ID when logging positions. *(advanced)*
* Many bug fixes pertainng to the advanced portal features setup process. *(advanced)*
* Fix aircraft column issue not allowing SQLite installs to upgrade properly. *(advanced)*

## v2.2.0 *(August 31st, 2016)*

* ADS-B Exchange script now sets up mlat-client to connect to their mlat-server.
* Added the ability to disply either the dump1090-fa or dump1090-mutability map.
* Changed the bash function which retrieves config file variables so it works properly.
* Fixed issue causing a package installation error when PiAware versions change.

## v2.1.0 *(August 30th, 2016)*

* Added flight information side bar to plot map. *(advanced)*
* Added flight data API to web site. *(advanced)*
* Fixed an issue where settings were not being saved properly during upgrades.
* The PiAware script has been modified to support the installation of PiAware 3.
* PiAware is no longer automatically configured to share MLAT data with 3rd parties.

## v2.0.3 *(May 19th, 2016)*

* Added password confirmation for MySQL database user to bash script. *(advanced)*
* Changes applied to image configuration script including fixes for bugs and wording.
* The device's IP address is now properly displayed at end of the bash setup process.
* MySQL upgrades failed to detect local or remote installs properly. *(advanced)*
* Changes to resolve PHP errors after running the PHP portal installer. *(advanced)*

## v2.0.2 *(May 12th, 2016)*

* When reinstalling dump1090-mutability the user is no longer asked for LAT and LON.
* When using a remote MySQL database the database must already exist. *(advanced)* 
* System information page now displays portal and patch versions.
* SQLite database permissions set properly so flight data can be recorded. *(advanced)*
* Adjusted the postback check function to possibly fix POST issues.
* Fixed bug where a malformed if statement was causing upgrade problems. *(advanced)*
* Links to aggregate site stats pages now open in a new web browser windows.
* The Postfix MTA package is now installed if not present.
* The bash scripts now detect Ubuntu 16.04 LTS and install the proper PHP packages.
* The current MySQL database size is displayed on the maintainance tab. *(advanced)*

## v2.0.1 *(April 29th, 2016)*

* Flight logging is now inserted properly into SQLite databases. *(advanced)*
* Remote MySQL database servers now handled properly by install scripts. *(advanced)*
* Separate flights now separated properly when viewing flight plots page. *(advanced)*
* Fixed issue where having the text ";&nbsp" was causing issues when stored in XML.
* Flights with no positions no longer display a PHP error when viewing plots. *(advanced)*
* Flight search box hidden on non advanced installations.
* All times are now stored as UTC time.
* Added the ability to specify the timezone the portal uses to display data.
* MySQL root password check added during script installation. *(advanced)*
* Directory where install/upgrade PHP files reside has been changed.
* Added warning not to remove the adsb-receiver directory after installation.

**Previous patches included in this release...**

* Added the version setting to be used to identifying the currently installed release.
* Added the patch setting to identify the current patch installed.
* Fixed issue with wireless bandwidth not being displayed on the system information page.
* The Python script flights.py should now import the proper libraries. *(advanced)*
* Wlan0 traffic now be displayed by the system gauges.
* Fixed issues pertaining to updating settings using the administration backend.

## v2.0.0 *(April 14th, 2016)*

* Versioning no longer going by date.
* MySQL is now a data storage option.
* SQLite is now a data storage option.
* Added an advanced portal option for use by those using more durable storage solutions.
* History of all flights seen including positions is available by choosing the advanced option.
* Added a way to reset forgotten portal passwords.
* Flight notifications can now process wildcards.
* The bandwidth gauge can now be set to a smaller scale.
* When posting blog entries existing titles are now checked for.

## March 7th, 2016

* Added the option to install the Flightradar24 client.
* Added administrator name and email address settings.
* Administrators are no longer required to change their password after their first login.
* Added the ability to display links to aggregate site statistics pages.
* Added near real time charts displaying current CPU, memory, and bandwidth usage.
* The author's name is now displayed when blog posts are rendered instead of their login.
* The settings page has been categorized and split into tabs.
* The portal no longer uses public CDN's to server jQuery and Bootstrap files.
* Scripts now exit properly when package fails to install.
* Flight notification alerts now display properly on map pages.

## March 4th, 2016

* Image created using Rasbian Jessie Lite version February 2016 in order to support Raspberry Pi 3.
* Improved readability of messages/aircraft graph.
* Added fix pertaining to the Planfinder link.

## February 18th, 2016

* Greatly improved the template system used by the web portal.
* Vistitors to the web portal can be alerted to the presence of aircraft using specified flight numbers.
* The user is now asked if they wish to bind dump1090-mutability to all IP addresses.
* Users can now choose to display range graph distances in nautical miles.
* Performance graph image sizes have been standardized.

## February 5th, 2016

* Initial tagged release.
* Raspbian Jessie Lite image now available.
