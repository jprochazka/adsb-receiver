# The ADS-B Feeder Project :airplane:

This repository contains a set of bash scripts and files which can be used to setup an ADS-B
feeder on a clean installation of a Debian derived operating system. The scripts are executed
in order by the main install script depending on the installation options choosen by the user.

### Obtaining And Using This Software

    sudo apt-get install git
    git clone https://github.com/jprochazka/adsb-feeder.git
    cd adsb-feeder
    chmod 755 install.sh
    ./install.sh

### What Can Be Installed

At this time the following software can be installed using these scripts.

**Mode S Decoders**

* Dump1090 (mutability):   https://github.com/mutability/dump1090
* Dump1090 (MalcolmRobb):  https://github.com/MalcolmRobb/dump1090

**Site Feeders**

* FlightAware's PiAware:      http://flightaware.com
* Plane Finder ADS-B CLient:  https://planefinder.net
* ADS-B Exchange:             http://adsbexchange.com *

**Additional Features**

* Web accessable Dump1090 and system performance graphs. **

### Supported Operating Systems

This project is in it's early stages and still needs to be thuroughly tested in live environments.
The following is a list of operating systems which are currently going through testing as well as
the status of the testing done so far on each. Those checked off have been tested successfully.

- [X] **Raspbian Jessie**
- [ ] **Raspbian Wheezy**
- [ ] **Debian 8.0 Jessie**
- [ ] **Debian 7.0 Wheezy**
- [X] **Ubuntu 15.04 Vivid Vervet**
- [ ] **Ubuntu 14.04 LTS Trusty Tahr**
- [ ] **Ubuntu 12.04 LTS Precise Pangolin**

---

\* *The ADS-B Exchange feed is sent via FlightAware's PiAware software.*  
** *In order to utilize the performance graphs dump1090-mutability must be chosen as your mode s decoder.*
