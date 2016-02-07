# The ADS-B Feeder Project :airplane:

This repository contains a set of bash scripts and files which can be used to setup an ADS-B
feeder on a clean installation of a Debian derived operating system. The scripts are executed
in order by the main install script depending on the installation options choosen by the user.

### Obtaining And Using This Software

#### For new installations...

    sudo apt-get install git
    cd ~/
    git clone https://github.com/jprochazka/adsb-feeder.git
    cd ~/adsb-feeder
    chmod +x install.sh
    ./install.sh
    
Please refer to the project wiki for more ways to customize your installation.  
https://github.com/jprochazka/adsb-feeder/wiki
    
#### Updating existing installations...

**If updating an installation created before January 28th, 2016...**  
Due to the fact the portal was entirly overhauled after the above date you should first backup then delete all files contained in the /var/www/html directory before fetching and running the latest version. Fresh installations and installations created using these files after the above date can disregard the above notice.

    cd ~/adsb-feeder
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

**Web Portal Features**

* Control what is displayed online via a web based administration area.
* A more uniform website site layout that can be easily navigated.
* Web accessable dump1090 and system performance graphs.
* A web accessable live dump1090 map.
* A web accessable live dump978 map.
* A blog which can be used to share your plane tracking experiences with others.

### Supported Operating Systems

The scripts and packages have been tested on the following operating systems.

- [X] Raspbian Jessie
- [X] Raspbian Jessie Lite
- [X] Debian 8.0 Jessie
- [X] Ubuntu 15.04 Vivid Vervet
- [X] Ubuntu 14.04 LTS Trusty Tahr

### Dump978 Notes

In order to utilize dump978 a second RTL-SDR device is required.

It is important to review the dump978 wiki page before installation.  
https://github.com/jprochazka/adsb-feeder/wiki/Configuring-Dump978
