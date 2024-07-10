-- VARIABLES

-- Specify the database name
SET @database   = "adsb_portal";

-- At this time table prefixes are not used so they will be removed
-- Set the following variable to the current table prefix
SET @current_prefix = "adsb_";


-- REMOVE TABLE PREFIX

SET @s:='';
SELECT
    @s:=concat("RENAME TABLE ", TABLE_NAME, " TO ", replace(TABLE_NAME, @old_prefix, ""), ';')
FROM information_schema.TABLES WHERE TABLE_SCHEMA = @database
;
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- REMOVE INDEXES

ALTER TABLE `aircraft` DROP INDEX `idxIcao`;
ALTER TABLE `positions` DROP INDEX `idxFlight`;

-- RENAME TABLES

RENAME TABLE `administrators` TO `users`;
RENAME TABLE `flightNotifications ` TO `notifications`;
RENAME TABLE `blogPosts` TO `blog_posts`;

-- RENAME COLUMNS

ALTER TABLE `aircraft` RENAME COLUMN `firstSeen` TO `first_seen`;
ALTER TABLE `aircraft` RENAME COLUMN `lastSeen` TO `last_seen`;
ALTER TABLE `flights` RENAME COLUMN `firstSeen` TO `first_seen`;
ALTER TABLE `flights` RENAME COLUMN `lastSeen` TO `last_seen`;
ALTER TABLE `positions` RENAME COLUMN `verticleRate` TO `verticle_rate`;

-- DROP COLUMNS

ALTER TABLE `users` DROP COLUMN `token`,

-- ADD COLUMNS

ALTER TABLE `users` ADD COLUMN `administrator` bit DEFAULT 0;
UPDATE `users` SET `administrator` = 1;
ALTER TABLE `users` ADD COLUMN `administrator` bit NOT NULL DEFAULT 0;

-- ADD FOREIGN KEYS

ALTER TABLE `flights` ADD FOREIGN KEY (`aircraft`) REFERENCES `aircraft`(`id`);
ALTER TABLE `positions` ADD FOREIGN KEY (`aircraft`) REFERENCES `aircraft`(`id`);
ALTER TABLE `positions` ADD FOREIGN KEY (`flight`) REFERENCES `flights`(`id`);