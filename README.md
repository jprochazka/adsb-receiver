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
    
At this time some manual configuration is required to properly display the max range graph. Please
refer to the project wiki for more infromation on what will need to be changed as well as how to
display bandwidth usage for a wireless connections. https://github.com/jprochazka/adsb-feeder/wiki
    
#### Updating existing installations...

    cd ~/adsb-feeder
    git pull
    ./install.sh

### What Can Be Installed

At this time the following software can be installed using these scripts.

**Mode S Decoders**

* Dump1090 (mutability):   https://github.com/mutability/dump1090

**Site Feeders**

* FlightAware's PiAware:      http://flightaware.com
* Plane Finder ADS-B CLient:  https://planefinder.net
* ADS-B Exchange:             http://adsbexchange.com

**Additional Features**

* Web accessable Dump1090 and system performance graphs.
* Add navigation to the stock Dump1090 map.

### Supported Operating Systems

The scripts and packages have been tested on the following operating systems.

- [X] Raspbian Jessie
- [X] Raspbian Jessie Lite
- [X] Debian 8.0 Jessie
- [X] Ubuntu 15.04 Vivid Vervet
- [X] Ubuntu 14.04 LTS Trusty Tahr
