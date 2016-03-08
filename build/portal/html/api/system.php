<?php

    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015-2016 Joseph A. Prochazka                                     //
    //                                                                                 //
    // Permission is hereby granted, free of charge, to any person obtaining a copy    //
    // of this software and associated documentation files (the "Software"), to deal   //
    // in the Software without restriction, including without limitation the rights    //
    // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell       //
    // copies of the Software, and to permit persons to whom the Software is           //
    // furnished to do so, subject to the following conditions:                        //
    //                                                                                 //
    // The above copyright notice and this permission notice shall be included in all  //
    // copies or substantial portions of the Software.                                 //
    //                                                                                 //
    // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR      //
    // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,        //
    // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE     //
    // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER          //
    // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,   //
    // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE   //
    // SOFTWARE.                                                                       //
    /////////////////////////////////////////////////////////////////////////////////////

    $possibleActions = array("getOsInformation", "getCpuInformation", "getMemoryInformation", "getHddInformation", "getNetworkInformation", "getUptimeInformation");

    if (isset($_GET['action']) && in_array($_GET["action"], $possibleActions)) {
        switch ($_GET["action"]) {
            case "getOsInformation":
                $informationArray = getOsInformation();
                break;
            case "getCpuInformation":
                $informationArray = getCpuInformation();
                break;
            case "getMemoryInformation":
                $informationArray = getMemoryInformation();
                break;
            case "getHddInformation":
                $informationArray = getHddInformation();
                break;
            case "getNetworkInformation":
                $informationArray = getNetworkInformation();
                break;
            case "getUptimeInformation":
                $informationArray = getUptimeInformation();
                break;
        }
        exit(json_encode($informationArray));
    } else {
        http_response_code(404);
    }

    function getOsInformation() {
        $osInformation['phpUname'] = php_uname();
        $osInformation['kernelName'] = php_uname('s');
        $osInformation['nodeName'] = php_uname('n');
        $osInformation['kernelRelease'] = php_uname('r');
        $osInformation['kernelVersion'] = php_uname('v');
        $osInformation['machine'] = php_uname('m');
        $osInformation['processor'] = php_uname('p');
        $osInformation['hardwarePlatform'] = php_uname('i');
        $osInformation['operatingSystem'] = php_uname('o');

        // cat /etc/os-release

        return $osInformation;
    }

    function getCpuInformation() {
        $firstRead = file('/proc/stat');
        sleep(1);
        $secondRead = file('/proc/stat');
        $firstInfo = explode(" ", preg_replace("!cpu +!", "", $firstRead[0]));
        $secondInfo = explode(" ", preg_replace("!cpu +!", "", $secondRead[0]));
        $difference = array();
        $difference['user'] = $secondInfo[0] - $firstInfo[0];
        $difference['nice'] = $secondInfo[1] - $firstInfo[1];
        $difference['sys'] = $secondInfo[2] - $firstInfo[2];
        $difference['idle'] = $secondInfo[3] - $firstInfo[3];
        $total = array_sum($difference);
        $cpuInformation = array();
        foreach($difference as $x=>$y){
            $cpuInformation[$x] = round($y / $total * 100, 1);
        }

        $cpuInfo = shell_exec("cat /proc/cpuinfo | grep model\ name");
        $cpuModel = strstr($cpuInfo, "\n", true);
        $cpuInformation['model'] = str_replace("model name\t: ", "", $cpuModel);

        return $cpuInformation;
    }

    function getMemoryInformation() {
        $memoryInformation['percent'] = round(shell_exec("free | grep Mem | awk '{print $3/$2 * 100.0}'"), 2);
        $memInfo = shell_exec("cat /proc/meminfo | grep MemTotal");
        $memoryInformation['total'] = round(preg_replace("#[^0-9]+(?:\.[0-9]*)?#", "", $memInfo) / 1024 / 1024, 3);
        $memInfo = shell_exec("cat /proc/meminfo | grep MemFree");
        $memoryInformation['free'] = round(preg_replace("#[^0-9]+(?:\.[0-9]*)?#", "", $memInfo) / 1024 / 1024, 3);
        $memoryInformation['used'] = $memoryInformation['total'] - $memoryInformation['free'];
        return $memoryInformation;
    }

    function getHddInformation() {
        $hddInformation['free'] = round(disk_free_space("/") / 1024 / 1024 / 1024, 2);
        $hddInformation['total'] = round(disk_total_space("/") / 1024 / 1024/ 1024, 2);
        $hddInformation['used'] = $hddInformation['total'] - $hddInformation['free'];
        $hddInformation['percent'] = round(sprintf('%.2f',($hddInformation['used'] / $hddInformation['total']) * 100), 2);
        return $hddInformation;
    }

    function getNetworkInformation() {
        $firstLookRx = trim(file_get_contents("/sys/class/net/eth0/statistics/rx_bytes"));
        $firstLookTx = trim(file_get_contents("/sys/class/net/eth0/statistics/tx_bytes"));
        sleep(5);
        $secondLookRx = trim(file_get_contents("/sys/class/net/eth0/statistics/rx_bytes"));
        $secondLookTx = trim(file_get_contents("/sys/class/net/eth0/statistics/tx_bytes"));
        $networkInformation['rxBytes'] = $secondLookRx - $firstLookRx;
        $networkInformation['txBytes'] = $secondLookTx - $firstLookTx;
        $networkInformation['rxMbps'] = round(($secondLookRx - $firstLookRx) / 1024 / 1024, 0);
        $networkInformation['txMbps'] = round(($secondLookTx - $firstLookTx) / 1024 / 1024, 0);
        return $networkInformation;
    }

    function getUptimeInformation() {
        $uptimeArray = split(' ', exec("cat /proc/uptime"));
        $uptime['inSeconds'] = trim($uptimeArray[0]);
        $uptime['hours'] = floor($uptime['inSeconds'] / 3600);
        $uptime['minutes'] = floor(($uptime['inSeconds'] - ($uptime['hours'] * 3600)) / 60);
        $uptime['seconds'] = floor($uptime['inSeconds'] % 60);
        return $uptime;

        //$idle['inSeconds'] = trim($uptimeArray[1]);
        //$idle['hours'] = floor($idle['inSeconds'] / 3600);
        //$idle['minutes'] = floor(($idle['inSeconds'] - ($idle['hours'] * 3600)) / 60);
        //$idle['seconds'] = floor($idle['inSeconds'] % 60);
    }
?>
