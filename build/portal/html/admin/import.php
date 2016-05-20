<?php


    /////////////////////////////////////////////////////////////////////////////////////
    //                            ADS-B RECEIVER PORTAL                                //
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

    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

    $settings = new settings();
    $common = new common();

    $master = fopen('../import/MASTER.txt', 'r');
    $headings = fgetcsv($master, 675, ',');

    // Remove the special character in front of N-NUMBER.
    foreach ($headings as &$heading) {
        if (strpos($heading, 'N-NUMBER') !== false) {
            $heading = "N-NUMBER";
        }
    }

    $recordsUpdated = 0;
    $recordsInserted = 0;

    $dbh = $common->pdoOpen();

    // Update existing or insert new records from the FAA MASTER DATABASE.
    while($column = fgetcsv($master, 675, ',')) {

        $column = array_combine($headings, $column);

        if (!is_null($column['N-NUMBER'])) {
            // Check if the N-NUMBER already exists in the database.
            $sql = "SELECT count(*) FROM ".$settings::db_prefix."faa_master WHERE nNumber = :nNumber";
            $sth = $dbh->prepare($sql);
            $sth->bindParam(':nNumber', $column['N-NUMBER'], PDO::PARAM_STR, 50);
            $sth->execute();
            $count = $sth->fetchColumn();
            $sth = NULL;

            if ($count > 0) {
                // Update the existing record.
                $sql = "UPDATE ".$settings::db_prefix."faa_master SET serialNumber = :serialNumber, mfrMdlCode = :mfrMdlCode, engMfrMdl = :engMfrMdl, yearMfr = :yearMfr, typeRegistrant = :typeRegistrant, name = :name, street = :street, street2 = :street2, city = :city, state = :state, zipCode = :zipCode, region = :region, county = :county, country = :country, lastActionDate = :lastActionDate, certIssueDate = :certIssueDate, certification = :certification, typeAircraft = :typeAircraft, typeEngine = :typeEngine, statusCode = :statusCode, modeSCode = :modeSCode, fractOwner = :fractOwner, airWorthDate = :airWorthDate, otherNames1 = :otherNames1, otherNames2 = :otherNames2, otherNames3 = :otherNames3, otherNames4 = :otherNames4, otherNames5 = :otherNames5, experiationDate = :experiationDate, uniqueId = :uniqueId, kitMfr = :kitMfr, kitModel = :kitModel, modeSCodeHex = :modeSCodeHex WHERE nNumber = :nNumber";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':nNumber', $column['N-NUMBER'], PDO::PARAM_STR, 5);
                $sth->bindParam(':serialNumber', $column['SERIAL NUMBER'], PDO::PARAM_STR, 30);
                $sth->bindParam(':mfrMdlCode', $column['MFR MDL CODE'], PDO::PARAM_STR, 7);
                $sth->bindParam(':engMfrMdl', $column['ENG MFR MDL'], PDO::PARAM_STR, 5);
                $sth->bindParam(':yearMfr', $column['YEAR MFR'], PDO::PARAM_STR, 4);
                $sth->bindParam(':typeRegistrant', $column['TYPE REGISTRANT'], PDO::PARAM_STR, 50);
                $sth->bindParam(':name', $column['NAME'], PDO::PARAM_STR, 33);
                $sth->bindParam(':street', $column['STREET'], PDO::PARAM_STR, 33);
                $sth->bindParam(':street2', $column['STREET2'], PDO::PARAM_STR, 18);
                $sth->bindParam(':city', $column['CITY'], PDO::PARAM_STR, 2);
                $sth->bindParam(':state', $column['STATE'], PDO::PARAM_STR, 10);
                $sth->bindParam(':zipCode', $column['ZIP CODE'], PDO::PARAM_STR, 1);
                $sth->bindParam(':region', $column['REGION'], PDO::PARAM_STR, 3);
                $sth->bindParam(':county', $column['COUNTY'], PDO::PARAM_STR, 2);
                $sth->bindParam(':country', $column['COUNTRY'], PDO::PARAM_STR, 8);
                $sth->bindParam(':lastActionDate', $column['LAST ACTION DATE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':certIssueDate', $column['CERT ISSUE DATE'], PDO::PARAM_STR, 10);
                $sth->bindParam(':certification', $column['CERTIFICATION'], PDO::PARAM_STR, 1);
                $sth->bindParam(':typeAircraft', $column['TYPE AIRCRAFT'], PDO::PARAM_STR, 2);
                $sth->bindParam(':typeEngine', $column['TYPE ENGINE'], PDO::PARAM_STR, 2);
                $sth->bindParam(':statusCode', $column['STATUS CODE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':modeSCode', $column['MODE S CODE'], PDO::PARAM_STR, 1);
                $sth->bindParam(':fractOwner', $column['FRACT OWNER'], PDO::PARAM_STR, 8);
                $sth->bindParam(':airWorthDate', $column['AIR WORTH DATE'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames1', $column['OTHER NAMES(1)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames2', $column['OTHER NAMES(2)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames3', $column['OTHER NAMES(3)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames4', $column['OTHER NAMES(4)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames5', $column['OTHER NAMES(5)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':experiationDate', $column['EXPIRATION DATE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':uniqueId', $column['UNIQUE ID'], PDO::PARAM_STR, 8);
                $sth->bindParam(':kitMfr', $column['KIT MFR'], PDO::PARAM_STR, 30);
                $sth->bindParam(':kitModel', $column['KIT MODEL'], PDO::PARAM_STR, 20);
                $sth->bindParam(':modeSCodeHex', $column['MODE S CODE HEX'], PDO::PARAM_STR, 10);
                $sth->execute();
                $sth = NULL;

                $recordsUpdated++;

            } else {
                // Insert a new record.
                $sql = "INSERT INTO ".$settings::db_prefix."faa_master (nNumber, serialNumber, mfrMdlCode, engMfrMdl, yearMfr, typeRegistrant, name, street, street2, city, state, zipCode, region, county, country, lastActionDate, certIssueDate, certification, typeAircraft, typeEngine, statusCode, modeSCode, fractOwner, airWorthDate, otherNames1, otherNames2, otherNames3, otherNames4, otherNames5, experiationDate, uniqueId, kitMfr, kitModel, modeSCodeHex) VALUES (:nNumber, :serialNumber, :mfrMdlCode, :engMfrMdl, :yearMfr, :typeRegistrant, :name, :street, :street2, :city, :state, :zipCode, :region, :county, :country, :lastActionDate, :certIssueDate, :certification, :typeAircraft, :typeEngine, :statusCode, :modeSCode, :fractOwner, :airWorthDate, :otherNames1, :otherNames2, :otherNames3, :otherNames4, :otherNames5, :experiationDate, :uniqueId, :kitMfr, :kitModel, :modeSCodeHex)";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':nNumber', $column['N-NUMBER'], PDO::PARAM_STR, 5);
                $sth->bindParam(':serialNumber', $column['SERIAL NUMBER'], PDO::PARAM_STR, 30);
                $sth->bindParam(':mfrMdlCode', $column['MFR MDL CODE'], PDO::PARAM_STR, 7);
                $sth->bindParam(':engMfrMdl', $column['ENG MFR MDL'], PDO::PARAM_STR, 5);
                $sth->bindParam(':yearMfr', $column['YEAR MFR'], PDO::PARAM_STR, 4);
                $sth->bindParam(':typeRegistrant', $column['TYPE REGISTRANT'], PDO::PARAM_STR, 50);
                $sth->bindParam(':name', $column['NAME'], PDO::PARAM_STR, 33);
                $sth->bindParam(':street', $column['STREET'], PDO::PARAM_STR, 33);
                $sth->bindParam(':street2', $column['STREET2'], PDO::PARAM_STR, 18);
                $sth->bindParam(':city', $column['CITY'], PDO::PARAM_STR, 2);
                $sth->bindParam(':state', $column['STATE'], PDO::PARAM_STR, 10);
                $sth->bindParam(':zipCode', $column['ZIP CODE'], PDO::PARAM_STR, 1);
                $sth->bindParam(':region', $column['REGION'], PDO::PARAM_STR, 3);
                $sth->bindParam(':county', $column['COUNTY'], PDO::PARAM_STR, 2);
                $sth->bindParam(':country', $column['COUNTRY'], PDO::PARAM_STR, 8);
                $sth->bindParam(':lastActionDate', $column['LAST ACTION DATE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':certIssueDate', $column['CERT ISSUE DATE'], PDO::PARAM_STR, 10);
                $sth->bindParam(':certification', $column['CERTIFICATION'], PDO::PARAM_STR, 1);
                $sth->bindParam(':typeAircraft', $column['TYPE AIRCRAFT'], PDO::PARAM_STR, 2);
                $sth->bindParam(':typeEngine', $column['TYPE ENGINE'], PDO::PARAM_STR, 2);
                $sth->bindParam(':statusCode', $column['STATUS CODE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':modeSCode', $column['MODE S CODE'], PDO::PARAM_STR, 1);
                $sth->bindParam(':fractOwner', $column['FRACT OWNER'], PDO::PARAM_STR, 8);
                $sth->bindParam(':airWorthDate', $column['AIR WORTH DATE'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames1', $column['OTHER NAMES(1)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames2', $column['OTHER NAMES(2)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames3', $column['OTHER NAMES(3)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames4', $column['OTHER NAMES(4)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':otherNames5', $column['OTHER NAMES(5)'], PDO::PARAM_STR, 50);
                $sth->bindParam(':experiationDate', $column['EXPIRATION DATE'], PDO::PARAM_STR, 8);
                $sth->bindParam(':uniqueId', $column['UNIQUE ID'], PDO::PARAM_STR, 8);
                $sth->bindParam(':kitMfr', $column['KIT MFR'], PDO::PARAM_STR, 30);
                $sth->bindParam(':kitModel', $column['KIT MODEL'], PDO::PARAM_STR, 20);
                $sth->bindParam(':modeSCodeHex', $column['MODE S CODE HEX'], PDO::PARAM_STR, 10);
                $sth->execute();
                $sth = NULL;

                $recordsInserted++;

            }
        }
    }

    $dbh = NULL;

    echo "Record(s) Updated: ".$recordsUpdated;
    echo "Record(s) Inserted: ".$recordsInserted;
?>
