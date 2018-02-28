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

    ///////////////////////
    // UPGRADE TO V2.1.0
    ///////////////////////

    // ---------------------------------------------------------
    // Adds the column aircraft to the table positions.
    // Updates the version setting to 2.1.0.
    // Removes and current patch version from the patch setting.
    // ---------------------------------------------------------

    $results = upgrade();
    exit(json_encode($results));

    function upgrade() {
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");
        require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");

        $common = new common();
        $settings = new settings();

        try {
            // Add the positions.aircraft column if the portal is using MySQL or SQLite database.
            if ($settings::db_driver == "mysql") {
                // Check to see if the column already exists.
                $dbh = $common->pdoOpen();
                if (count($dbh->query("SHOW COLUMNS FROM `".$settings::db_prefix."positions` LIKE 'aircraft'")->fetchAll()) == 0) {
                    // Add the column if it does not exist.
                    $sql = "ALTER TABLE ".$settings::db_prefix."positions ADD COLUMN aircraft BIGINT";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;
                }
                $dbh = NULL;
            }

            if ($settings::db_driver == "sqlite") {
                // Check to see if the column already exists.
                $dbh = $common->pdoOpen();
                $columns = $dbh->query("pragma table_info(positions)")->fetchArray(SQLITE3_ASSOC);
                $columnExists = FALSE;
                foreach($columns as $column ){
                    if ($column['name'] == 'positions') {
                        $columnExists = TRUE;
                    }
                }
                // Add the column if it does not exist.
                if (!$columnExists) {
                    $sql = "ALTER TABLE ".$settings::db_prefix."positions ADD COLUMN aircraft BIGINT";
                    $sth = $dbh->prepare($sql);
                    $sth->execute();
                    $sth = NULL;
                }
                $dbh = NULL;
            }

            // Update the version and patch settings..
            $common->updateSetting("version", "2.1.0");
            $common->updateSetting("patch", "");

            // The upgrade process completed successfully.
            $results['success'] = TRUE;
            $results['message'] = "Upgrade to v2.1.0 successful.";
            return $results;

        } catch(Exception $e) {
            // Something went wrong during this upgrade process.
            $results['success'] = FALSE;
            $results['message'] = $e->getMessage();
            return $results;
        }
    }
?>

