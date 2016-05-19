# CHANGELOG :airplane:

The following is a history of the changes made to this project.

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
