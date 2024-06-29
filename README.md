# The ADS-B Receiver Project :airplane:

This repository contains a set of scripts and files which can be used to setup an ADS-B receiver on a clean installation of a Debian derived operating system. The scripts are executed in order by the main install script depending on the installation options chosen by the user.

**ADS-B Receiver Web Portal Features**

* Saves all flights seen as well as displays a plot for the flight. (advanced)
* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessible dump1090 and system performance graphs.
* A web accessible live dump1090 map.
* A web accessible live dump978 map.
* A blog which can be used to share your plane tracking experiences with others.
* Informs visitors when specific flights are being tracked by dump1090.
* Easily customize the look of your portal using the template system.

The ADS-B Receiver Project website is located at https://www.adsbreceiver.net.

### Obtaining And Using This Software

When setting up the portal you will have to choose between a lite or advanced installation. Advanced features adds flight logging and plotting and should only be chosen on devices running a more sturdy data storage solution.

*It is recommended that anyone using a SD card as they storage medium not attempt to use the advanced features.*

#### Manual installations...

    sudo apt-get update
    sudo apt-get install git
    git clone https://github.com/jprochazka/adsb-receiver.git
    cd ~/adsb-receiver
    chmod +x install.sh
    ./install.sh

#### Updating existing installations...

Your local repository will be updated each time install.sh is executed.

    cd ~/adsb-receiver
    ./install.sh

#### Portal setup...

This step pertains to both fresh installations as well as when updating an existing installation. After running the installation scripts you will need to setup the portal by visiting the following web address.

    http://<IP_ADDRESS_OF_YOUR_DEVICE>/install/

Supply the information asked for and submit the form once done to complete the setup.

### What Can Be Installed

The following software can be installed using these scripts.

**Decoders**

* Dump1090 (FlightAware): https://github.com/flightaware/dump1090
* Dump978 (FlightAware):  https://github.com/mutability/dump978

**Site Feeders**

* ADS-B Exchange:              https://adsbexchange.com
* FlightAware's PiAware:       https://flightaware.com
* Flightradar24 Feeder Client: https://flightradar24.com
* OpenSky Feeder:              https://opensky-network.org
* Plane Finder ADS-B Client:   https://planefinder.net

**Extras**

* ADS-B Receiver Project Portal: https://www.adsbreceiver.net
* Beast-Splitter:                https://github.com/flightaware/beast-splitter
* DuckDNS.org Support:           https://www.duckdns.org/

### Supported Operating Systems

The project currently supports the following Linux distributions.

* Debian Bookworm
* Debian Bullseye
* DietPi (Bookworm)
* DietPi (Bullseye)
* Rasbperry PI OS (Bookworm)
* Rasbperry PI OS Legacy (Bullseye)
* Ubuntu Jammy Jellyfish
* Ubuntu Focal Fossa

### Useful Links

- GitHub Repository - https://github.com/jprochazka/adsb-receiver
- GitHub Wiki - https://github.com/jprochazka/adsb-receiver/wiki
- Changelog - https://github.com/jprochazka/adsb-receiver/blob/master/CHANGELOG.md
