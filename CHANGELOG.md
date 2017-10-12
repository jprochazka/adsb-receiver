# CHANGELOG :airplane:

The following is a history of the changes made to this project.

## v2.6.0 (*prerelease*)

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
