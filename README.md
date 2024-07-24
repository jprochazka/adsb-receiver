# The ADS-B Receiver Project :airplane:

## Run ADS-B/UAT related applications without the overhead!

This project continues to realize that for some, Docker and premade images are not the most optimal solution.

It would seem as of late the move towards premade as well as Docker and other PaaS images with preinstalled software has become popular within the community. Docker images require additional software and overhead in order to run and premade images lack installation options. Most of these solutions come with preinstalled software you may never use as part of the image as well. This project offers the ability to choose and install only what you want or need across a wide range of devices with minimal command line experience.

## Obtaining And Using This Software

### Manual installations...

    sudo apt-get update
    sudo apt-get install git
    git clone https://github.com/jprochazka/adsb-receiver
    cd ~/adsb-receiver
    chmod +x install.sh
    ./install.sh

### Updating existing installations...

Your local repositories master branch will be updated each time install.sh is executed that is unless either the `--development` or `--branch <branch>` switch is used. Unless you are testing an upcoming release or wishing to contribute to the project you will generally not need to use either of these switches.

    cd ~/adsb-receiver
    ./install.sh

## What Can Be Installed

The following software can be installed using these scripts.

### The ADS-B Portal

Included is the option to install the ADS-B Portal which offers the following features.

* Saves all flights seen as well as displays a plot for the flight.
* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessible dump1090 and system performance graphs.
* Easy access to live dump1090 and dump978 maps.
* A blog which can be used to share your plane tracking experiences with others.
* Visitors can be informed when specific flights are being tracked.
* Administrators can be informed via email when specific flights are being tracked.
* Easily customize the look of your portal using the custom template system.

When setting up the portal you will have to choose between a lite or advanced installation. Advanced features adds flight logging and plotting and should only be chosen on devices running a more sturdy data storage solution.

*It is highly recommended that anyone using a SD card as they storage medium not attempt to use the advanced features.*

### Decoders

* Dump1090 (FlightAware):  https://github.com/flightaware/dump1090
* Dump978 (FlightAware):   https://github.com/flightaware/dump978

### Feeders

* ADS-B Exchange Feeder Client:   https://adsbexchange.com
* Airplanes.live Feeder Client:   https://airplanes.live
* FlightAware's PiAware:          https://flightaware.com
* Flightradar24 Feeder Client:    https://flightradar24.com
* Fly Italy ADS-B Feeder Client:  https://flyitalyadsb.com
* OpenSky Feeder Client:          https://opensky-network.org
* Plane Finder ADS-B Client:      https://planefinder.net

### Extras

* Beast-Splitter:       https://github.com/flightaware/beast-splitter
* DuckDNS.org Support:  https://www.duckdns.org

## Supported Operating Systems

The project currently supports the following Linux distributions.

* Armbian _(Bookworm, Jammy and Noble)_
* Debian _(Bookworm, Bullseye and Trixie)_
* DietPi _(Bookworm aand Bullseye)_
* Rasbperry PI OS _(Bookworm and Bullseye)_
* Ubuntu _(Jammy Jellyfish, Focal Fossa and Noble Numbat)_

_Support is available via this repository through the use of the issue tracker or discussions._

_At this time support for PiAware on distributions based on Debian Trixie and Ubuntu Noble Numbat employ an unofficial fix._
