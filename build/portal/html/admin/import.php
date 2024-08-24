<?php
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."settings.class.php");
    require_once($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."classes".DIRECTORY_SEPARATOR."common.class.php");

    $settings = new settings();
    $common = new common();

    ///////////////////
    // AJAX REQUESTS
    $possibleFiles = array("MASTERtxt", "ACFTREFtxt", "ENGINEtxt");

    if (isset($_GET['import'])) {
        if (in_array($_GET["import"], $possibleFiles) && $_SESSION["importRunning"] != TRUE) {
            switch ($_GET["import"]) {
                case "MASTERtxt":
                    $results = importMaster();
                    break;
                case "ACFTREFtxt":
                    $results = importAircraftReference();
                    break;
                case "ENGINEtxt":
                    $results = importEngineReference();
                    break;
            }
            exit(json_encode($results));
        } else {
            if ($_SESSION["importRunning"] == TRUE) {
                http_response_code(403);
            } else {
                http_response_code(404);
            }
        }
    }

    if (isset($_GET['check'])) {
        if ($_GET["check"] == "status") {
            $result = array();
            $result["running"] = $session["importRunning"];
            $result["updated"] = $session["importRecordsInserted"];
            $result["inserted"] = $session["importRecordsUpdated"];
            exit(json_encode($results));
        } else {
            http_response_code(404);
        }
    }

    /////////////////////
    // NORMAL REQUESTS

    // Check which files are present.
    $masterTxt = FALSE;
    if (file_exists($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."import".DIRECTORY_SEPARATOR."MASTER.txt"))
        $masterTxt = TRUE;

    $acftrefTxt = FALSE;
    if (file_exists($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."import".DIRECTORY_SEPARATOR."ACFTREF.txt"))
        $acftrefTxt = TRUE;

    $engineTxt = FALSE;
    if (file_exists($_SERVER['DOCUMENT_ROOT'].DIRECTORY_SEPARATOR."import".DIRECTORY_SEPARATOR."ENGINE.txt"))
        $engineTxt = TRUE;

    //////////
    // HTML

    require_once('includes/header.inc.php');
?>
        <h1>Database Importer</h1>
        <p>
            Below is a list of files which are currently available for import in the import directory. All third party databases must be uploaded to the directory
            <?php echo $_SERVER['DOCUMENT_ROOT'] ?>/import/. Clicking the button containing the selected files name will import that file into your database.
        </p>
        <hr />
        <h2>FAA Releasable Aircraft Database</h2>
        <p>
            The most current FAA Releasable Aircraft Database can be downloaded from <a href="http://www.faa.gov/licenses_certificates/aircraft_certification/aircraft_registry/releasable_aircraft_download/" target="_blank">here</a>.
        </p>
        <ul class="list-group">
            <li class="list-group-item<?php ($masterTxt ? print ' list-group-item-success' : print ' list-group-item-danger'); ?>"><button id="masterTxt" type="button" class="btn btn-default btn-xs"<?php ($masterTxt ? '' : print ' disabled="disabled"'); ?>>MASTER.txt </button> <em>The FAA Aircraft Registration Master File.</em></li>
            <li class="list-group-item<?php ($acftrefTxt ? print ' list-group-item-success' : print ' list-group-item-danger'); ?>"><button id="acftrefTxt" type="button" class="btn btn-default btn-xs"<?php ($acftrefTxt ? '' : print ' disabled="disabled"'); ?>>ACFTREF.txt</button> <em>The FAA Aircraft Reference File.</em></li>
            <li class="list-group-item<?php ($engineTxt ? print ' list-group-item-success' : print ' list-group-item-danger'); ?>"><button id="engineTxt" type="button" class="btn btn-default btn-xs"<?php ($engineTxt ? '' : print ' disabled="disabled"'); ?>>ENGINE.txt </button> <em>The FAA Engine Reference File.</em></li>
        </ul>

        <p>
            The importer is currently <span id="running">not running</span>.<br />
            A total of <span id="updated">0</span> records have been updated.<br />
            A total of <span id="inserted">0</span> records have been inserted.
        </p>

        <script>
            importRunning = false;

            $('#masterTxt').click(function() {
                $.get( "import.php", { import: "MASTERtxt" } );
                importRunning = true;
                while (importRunning == true) {
                     setInterval(updateStatus(), 1000 * 5);
                }
            });

            $('#acftrefTxt').click(function() {
                $.get( "import.php", { import: "ACFTREFtxt" } );
                importRunning = true;
                while (importRunning == true) {
                     setInterval(updateStatus(), 1000 * 1);
                }
            });

            $('#engineTxt').click(function() {
                $.get( "import.php", { import: "ENGINEtxt" } );
                importRunning = true;
                while (importRunning == true) {
                     setInterval(updateStatus(), 1000 * 1);
                }
            });

            function updateStatus() {
                $.ajax({
                    url: 'import.php',
                    type: 'GET',
                    cache: false,
                    data: {
                        check: 'status'
                    },
                    success: function(json) {
                        var data = $.parseJSON(json);
                        importRunning = data['running'];
                        if (importRunning) {
                            $('#running').text("running");
                        } else {
                            $('#running').text("not running");
                        }
                        $('#updated').text(data['updated']);
                        $('#inserted').text(data['inserted']);
                    },
                    error: function(response) {
                        console.log(response);
                    }
                });
            }
        </script>
<?php
    require_once('includes/footer.inc.php');

    //////////////////////
    // IMPORT FUNCTIONS

    function importMaster() {

        $_SESSION["importRunning"] = TRUE;

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
                $sth->bindParam(':nNumber', $column['N-NUMBER'], PDO::PARAM_STR, 5);
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
                    $_SESSION["importRecordsUpdated"] = $recordsUpdated;

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
                    $_SESSION["importRecordsInserted"] = $recordsInserted;
                }
            }
        }

        $dbh = NULL;

        $_SESSION["importRunning"] = FALSE;

        // Return the results of this import.
        $results = array();
        $results["updated"] = $recordsUpdated;
        $results["inserted"] = $recordsInserted;
        return $results;
    }


    function importAircraftReference() {

        $_SESSION["importRunning"] = TRUE;

        $acftref = fopen('../import/ACFTREF.txt', 'r');
        $headings = fgetcsv($acftref, 90, ',');

        // Remove the special character in front of CODE.
        //foreach ($headings as &$heading) {
        //    if (strpos($heading, 'CODE') !== false) {
        //        $heading = "CODE";
        //    }
        //}

        $recordsUpdated = 0;
        $recordsInserted = 0;

        $dbh = $common->pdoOpen();

        // Update existing or insert new records from the FAA ACFTREF DATABASE.
        while($column = fgetcsv($acftref, 90, ',')) {

            $column = array_combine($headings, $column);

            if (!is_null($column['CODE'])) {
                // Check if the CODE already exists in the database.
                $sql = "SELECT count(*) FROM ".$settings::db_prefix."faa_acftref WHERE code = :code";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 7);
                $sth->execute();
                $count = $sth->fetchColumn();
                $sth = NULL;

                if ($count > 0) {
                    $sql = "UPDATE ".$settings::db_prefix."faa_acftref SET mfr = : mfr, model = :model, typeAcft = :typeAcft, typeEng = :typeEng, acCat = :acCat, buildCertInd = :buildCertInd, noEng = :noEng, noSeats = :noSeats, acWeight = :acWeight, speed = :speed WHERE code = :code";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 7);
                    $sth->bindParam(':mfr', $column['MFR'], PDO::PARAM_STR, 30);
                    $sth->bindParam(':model', $column['MODEL'], PDO::PARAM_STR, 20);
                    $sth->bindParam(':typeAcft', $column['TYPE-ACFT'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':typeEng', $column['TYPE-ENG'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':acCat', $column['AC-CAT'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':buildCertInd', $column['BUILD-CERT-IND'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':noEng', $column['NO-ENG'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':noSeats', $column['NO-SEATS'], PDO::PARAM_STR, 3);
                    $sth->bindParam(':acWeight', $column['AC-WEIGHT'], PDO::PARAM_STR, 7);
                    $sth->bindParam(':speed', $column['SPEED'], PDO::PARAM_STR, 4);
                    $sth->execute();
                    $sth = NULL;

                    $recordsUpdated++;
                    $_SESSION["importRecordsUpdated"] = $recordsUpdated;

                 } else {

                    $sql = "INSERT INTO ".$settings::db_prefix."faa_acftref (code, mfr, model, typeAcft, typeEng, acCat, buildCertInd, noEng, noSeats, acWeight, speed) VALUES (:code, :mfr, :model, :typeAcft, :typeEng, :acCat, :buildCertInd, :noEng, :noSeats, :acWeight, :speed)";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 7);
                    $sth->bindParam(':mfr', $column['MFR'], PDO::PARAM_STR, 30);
                    $sth->bindParam(':model', $column['MODEL'], PDO::PARAM_STR, 20);
                    $sth->bindParam(':typeAcft', $column['TYPE-ACFT'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':typeEng', $column['TYPE-ENG'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':acCat', $column['AC-CAT'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':buildCertInd', $column['BUILD-CERT-IND'], PDO::PARAM_STR, 1);
                    $sth->bindParam(':noEng', $column['NO-ENG'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':noSeats', $column['NO-SEATS'], PDO::PARAM_STR, 3);
                    $sth->bindParam(':acWeight', $column['AC-WEIGHT'], PDO::PARAM_STR, 7);
                    $sth->bindParam(':speed', $column['SPEED'], PDO::PARAM_STR, 4);
                    $sth->execute();
                    $sth = NULL;

                    $recordsInserted++;
                    $_SESSION["importRecordsInserted"] = $recordsInserted;
                }
            }
        }

        $dbh = NULL;

        $_SESSION["importRunning"] = FALSE;

        // Return the results of this import.
        $results = array();
        $results["updated"] = $recordsUpdated;
        $results["inserted"] = $recordsInserted;
        return $results;
    }

    function importEngineReference() {

        $_SESSION["importRunning"] = TRUE;

        $engine = fopen('../import/ENGINE.txt', 'r');
        $headings = fgetcsv($engine, 50, ',');

        // Remove the special character in front of CODE.
        //foreach ($headings as &$heading) {
        //    if (strpos($heading, 'CODE') !== false) {
        //        $heading = "CODE";
        //    }
        //}

        $recordsUpdated = 0;
        $recordsInserted = 0;

        $dbh = $common->pdoOpen();

        // Update existing or insert new records from the FAA ENGINE DATABASE.
        while($column = fgetcsv($engine, 50, ',')) {

            $column = array_combine($headings, $column);

            if (!is_null($column['CODE'])) {
                // Check if the CODE already exists in the database.
                $sql = "SELECT count(*) FROM ".$settings::db_prefix."faa_engine WHERE code = :code";
                $sth = $dbh->prepare($sql);
                $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 5);
                $sth->execute();
                $count = $sth->fetchColumn();
                $sth = NULL;

                if ($count > 0) {
                    $sql = "UPDATE ".$settings::db_prefix."faa_engine SET code = :code, mfr = :mfr, model = :model, type = :type, horsePower = :horsePower, thrust = :thrust WHERE code = :code";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 5);
                    $sth->bindParam(':mfr', $column['MFR'], PDO::PARAM_STR, 10);
                    $sth->bindParam(':model', $column['MODEL'], PDO::PARAM_STR, 13);
                    $sth->bindParam(':type', $column['TYPE'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':horsePower', $column['HORSEPOWER'], PDO::PARAM_STR, 5);
                    $sth->bindParam(':thrust', $column['THRUST'], PDO::PARAM_STR, 6);
                    $sth->execute();
                    $sth = NULL;

                    $recordsUpdated++;
                    $_SESSION["importRecordsUpdated"] = $recordsUpdated;

                } else {

                    $sql = "INSERT INTO ".$settings::db_prefix."faa_engine (code, mfr, model, type, horsePower, thrust) VALUES (:code, :mfr, :model, :type, :horsePower, :thrust)";
                    $sth = $dbh->prepare($sql);
                    $sth->bindParam(':code', $column['CODE'], PDO::PARAM_STR, 5);
                    $sth->bindParam(':mfr', $column['MFR'], PDO::PARAM_STR, 10);
                    $sth->bindParam(':model', $column['MODEL'], PDO::PARAM_STR, 13);
                    $sth->bindParam(':type', $column['TYPE'], PDO::PARAM_STR, 2);
                    $sth->bindParam(':horsePower', $column['HORSEPOWER'], PDO::PARAM_STR, 5);
                    $sth->bindParam(':thrust', $column['THRUST'], PDO::PARAM_STR, 6);
                    $sth->execute();
                    $sth = NULL;

                    $recordsInserted++;
                    $_SESSION["importRecordsInserted"] = $recordsInserted;
                }
            }
        }

        $dbh = NULL;

        $_SESSION["importRunning"] = FALSE;

        // Return the results of this import.
        $results = array();
        $results["updated"] = $recordsUpdated;
        $results["inserted"] = $recordsInserted;
        return $results;
    }
?>
