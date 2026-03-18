# The ADS-B Receiver Project :airplane:

## Easily install ADS-B/UAT/ACARS/VDLM2 related applications!

This project continues to realize that for some, Docker and premade images are not the most optimal solution.

It would seem as of late the move towards premade as well as Docker and other PaaS images with preinstalled software has become popular within the community. Docker images require additional software and, in some cases, result in additional overhead as well as making trivial configuration changes more complicated than they should be. Most of these solutions also come with preinstalled software one may never use as part of the image as well. This project offers the ability to choose and install only what you want or need natively across a wide range of devices with minimal command line experience.

## Obtaining And Using This Software

### New installations...

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
* Saves all ACARS and VDLM2 messages received and offers the ability to view them.
* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessible dump1090 and system performance graphs.
* Easy access to live dump1090 and dump978 maps.
* A blog which can be used to share your aircraft tracking experiences with others.
* Visitors can be informed when specific flights are being tracked.
* Administrators can be informed via email when specific flights are being tracked.
* Easily customize the look of your portal using the custom template system.

When setting up the portal you will have to choose between a lite or advanced installation. Advanced features add flight logging and plotting and should only be chosen on devices running a sturdy data storage solution.

*It is highly recommended that anyone using a SD card as thier storage medium not attempt to use the advanced features.*

### Decoders

* ACARSDEC:                https://github.com/TLeconte/acarsdec
* Dump1090 (FlightAware):  https://github.com/flightaware/dump1090
* Dump978 (FlightAware):   https://github.com/flightaware/dump978
* Dumpvdl2:                https://github.com/szpajder/dumpvdl2
* Readsb:                  https://github.com/wiedehopf/readsb
* VDLM2DEC:                https://github.com/TLeconte/vdlm2dec

### Feeders

* ADS-B Exchange Feeder Client:   https://adsbexchange.com
* AirNav Radar Client:            https://airnavradar.com
* Airplanes.live Feeder Client:   https://airplanes.live
* FlightAware's PiAware:          https://flightaware.com
* Flightradar24 Feeder Client:    https://flightradar24.com
* Fly Italy ADS-B Feeder Client:  https://flyitalyadsb.com
* OpenSky Feeder Client:          https://opensky-network.org
* Plane Finder ADS-B Client:      https://planefinder.net

### Extras

* Beast-Splitter:       https://github.com/flightaware/beast-splitter
* DuckDNS.org Support:  https://www.duckdns.org
* Graphs1090:           https://github.com/wiedehopf/graphs1090
* tar1090:              https://github.com/wiedehopf/tar1090

## Supported Operating Systems

The project currently supports the following Linux distributions.

* Armbian _(Bookworm and Noble)_
* Debian _(Bookworm and Bullseye)_
* DietPi _(Bookworm and Bullseye)_
* Raspberry PI OS _(Bookworm and Bullseye)_
* Ubuntu _(Jammy Jellyfish and Noble Numbat*)_

Support is available via this repository through the use of the issue tracker or discussions.

_* Please Note that Ubuntu Noble Numbat support employs an unofficial fix for PiAware._
