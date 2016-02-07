<?php
    
    /////////////////////////////////////////////////////////////////////////////////////
    //                             ADS-B FEEDER PORTAL                                 //
    // =============================================================================== //
    // Copyright and Licensing Information:                                            //
    //                                                                                 //
    // The MIT License (MIT)                                                           //
    //                                                                                 //
    // Copyright (c) 2015 Joseph A. Prochazka                                          //
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

    $possibleActions = array("getOsInformation", "getCpuInformation", "getMemoryInformation", "getHddInformation", "getNetworkInformation");

    if (isset$_GET['action'] && in_array($_GET["action"], $possibleActions)) {
        switch ($_GET["action"]) {
            case "getOsInformation"
                $informationArray = getOsInformation();
                break;
            case "getCpuInformation"
                e$informationArray = getCpuInformation();
                break;
            case "getMemoryInformation"
                $informationArray = getMemoryInformation();
                break;
            case "getHddInformation"
                $informationArray = getHddInformation();
                break;
            case "getNetworkInformation"
                $informationArray = getNetworkInformation();
                break;
        }
        exit(json_encode($informationArray));
    } else {
        http_response_code(418);
    }

    function getOsInformation() {
        $osInformation['phpUname'] = php_uname();
        $osInformation['name'] = php_uname('s');
        $osInformation['hostName'] = php_uname('n');
        $osInformation['releaseName'] = php_uname('r');
        $osInformation['version'] = php_uname('v');
        $osInformation['machineType'] = php_uname('m');
        return $osInformation;
    }

    function getCpuInformation() {
        $firstRead = shell_exec("cat /proc/stat");
        $firstArray = explode(' ',trim($firstRead));
        $firstTotal = $firstArray[2] + $firstArray[3] + $firstArray[4] + $firstArray[5];
        $firstIdle = $firstArray[5];
        usleep(0.15 * 1000000);
        $secondRead = shell_exec("cat /proc/stat");
        $secondArray = explode(' ', trim($secondRead));
        $secondTotal = $secondArray[2] + $secondArray[3] + $secondArray[4] + $secondArray[5];
        $secondIdle = $secondArray[5];
        $intervalTotal = intval($secondTotal - $firstTotal);
        $cpuInformation['cpu'] =  intval(100 * (($intervalTotal - ($secondIdle - $firstIdle)) / $intervalTotal));
        $cpuInfo = shell_exec("cat /proc/cpuinfo | grep model\ name");
        $cpuInformation['cpuModel'] = strstr($cpuInfo, "\n", true);
        $cpuInformation['cpuModel'] = str_replace("model name    : ", "", $stat['cpuModel']);
        return $cpuInformation;
    }

    function getMemoryInformation() {
        $memoryInformation['percent'] = round(shell_exec("free | grep Mem | awk '{print $3/$2 * 100.0}'"), 2);
        $memInfo = shell_exec("cat /proc/meminfo | grep MemTotal");
        $memoryInformation['total'] = round(preg_replace("#[^0-9]+(?:\.[0-9]*)?#", "", $memInfo) / 1024 / 1024, 3);
        $memInfo = shell_exec("cat /proc/meminfo | grep MemFree");
        $memoryInformation['free'] = round(preg_replace("#[^0-9]+(?:\.[0-9]*)?#", "", $memInfo) / 1024 / 1024, 3);
        $memoryInformation['used'] = $stat['total'] - $stat['free'];
        return $memoryInformation;
    }

    function getHddInformation() {
        $hddInformation['free'] = round(disk_free_space("/") / 1024 / 1024 / 1024, 2);
        $hddInformation['total'] = round(disk_total_space("/") / 1024 / 1024/ 1024, 2);
        $hddInformation['used'] = $hddInformation['total'] - $stat['hdd_free'];
        $hddInformation['percent'] = round(sprintf('%.2f',($hddInformation['used'] / $hddInformation['total']) * 100), 2);
        return $hddInformation;
    }

    function getNetworkInformation() {
        $networkInformation['rx'] = round(trim(file_get_contents("/sys/class/net/eth0/statistics/rx_bytes")) / 1024/ 1024/ 1024, 2);
        $networkInformation['tx'] = round(trim(file_get_contents("/sys/class/net/eth0/statistics/tx_bytes")) / 1024/ 1024/ 1024, 2);
        return $networkInformation;
    }
?>
