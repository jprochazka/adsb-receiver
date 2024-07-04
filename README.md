# The ADS-B Receiver Project :airplane:

## Run ADS-B/UAT related applications without the overhead!

This project continues to realize that for some, Docker and premade images are not always the solution.

It would seem as of late the move towards Docker and other PaaS images with preinstalled software are the rage within the community. The problem is Docker images require additional software and overhead in order to run. Solutions in the form of a Docker or premade native image also include software you may never wish to use as part of the image. What this project offers is the possibility for less overhead and better performance, depending on your installation choices of course, on a wide range of devices by installing only the applications you want natively.

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

### The ADS-B Receiver Web Portal

Included is the option to install the ADS-B Portal which offers the following features.

* Saves all flights seen as well as displays a plot for the flight. (advanced)
* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessible dump1090 and system performance graphs.
* A web accessible live dump1090 map.
* A web accessible live dump978 map.
* A blog which can be used to share your plane tracking experiences with others.
* Informs visitors when specific flights are being tracked by dump1090.
* Easily customize the look of your portal using the template system.

When setting up the portal you will have to choose between a lite or advanced installation. Advanced features adds flight logging and plotting and should only be chosen on devices running a more sturdy data storage solution.

*It is recommended that anyone using a SD card as they storage medium not attempt to use the advanced features.*

### Decoders

* Dump1090 (FlightAware): https://github.com/flightaware/dump1090
* Dump978 (FlightAware):  https://github.com/mutability/dump978

### Feeders

* ADS-B Exchange:              https://adsbexchange.com
* FlightAware's PiAware:       https://flightaware.com
* Flightradar24 Feeder Client: https://flightradar24.com
* OpenSky Feeder:              https://opensky-network.org
* Plane Finder ADS-B Client:   https://planefinder.net

### Extras

* Beast-Splitter:                https://github.com/flightaware/beast-splitter
* DuckDNS.org Support:           https://www.duckdns.org/

## Supported Operating Systems

The project currently supports the following Linux distributions.

* Debian Bookworm
* Debian Bullseye
* DietPi (Bookworm)
* DietPi (Bullseye)
* Rasbperry PI OS (Bookworm)
* Rasbperry PI OS Legacy (Bullseye)
* Ubuntu Jammy Jellyfish
* Ubuntu Focal Fossa

## Useful Links

- GitHub Repository - https://github.com/jprochazka/adsb-receiver
- GitHub Wiki - https://github.com/jprochazka/adsb-receiver/wiki
- Changelog - https://github.com/jprochazka/adsb-receiver/blob/master/CHANGELOG.md
