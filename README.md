# The ADS-B Receiver Project :airplane:

This repository contains a set of scripts and files which can be used to setup an ADS-B
receiver on a clean installation of a Debian derived operating system. The scripts are executed
in order by the main install script depending on the installation options choosen by the user.

The ADS-B Receiver Project website is located at https://www.adsbreceiver.net.

### Obtaining And Using This Software

Download the latest ADS-B Receiver Raspbian Jessie Lite image for Raspberry Pi devices.
https://github.com/jprochazka/adsb-feeder/releases/latest

#### Manual installations...

    sudo apt-get update
    sudo apt-get install git
    git clone https://github.com/jprochazka/adsb-receiver.git ~/adsb-receiver
    cd ~/adsb-receiver
    chmod +x install.sh
    ./install.sh
    
#### Updating existing installations...

    cd ~/adsb-receiver
    git fetch --all
    git reset --hard origin/master
    ./install.sh

### What Can Be Installed

At this time the following software can be installed using these scripts.

**Decoders**

* Dump1090 (mutability):  https://github.com/mutability/dump1090
* Dump978:                https://github.com/mutability/dump978

**Site Feeders**

* FlightAware's PiAware:      http://flightaware.com
* Plane Finder ADS-B Client:  https://planefinder.net
* ADS-B Exchange:             http://adsbexchange.com

**ADS-B Receiver Web Portal Features**

* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessable dump1090 and system performance graphs.
* A web accessable live dump1090 map.
* A web accessable live dump978 map.
* A blog which can be used to share your plane tracking experiences with others.
* Informs visitors when specific flights are being tracked by dump1090.
* Easily customize the look of your portal using the template system.

### Supported Operating Systems

The scripts and packages have been tested on most Debian Jessie based operating systems.
