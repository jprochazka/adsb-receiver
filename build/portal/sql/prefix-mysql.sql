-- Specify the database name
SET @database   = "";

-- Later the ability to specify a table prefix will be added once more
-- Specify the prefix you wish to assign current ADS-B Portal tables
SET @prefix = "";


-- ADD PREFIXES TO ADS-B PORTAL TABLES

SET @s:='';
concat(
    "RENAME TABLE administrators TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE aircraft TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE blog_posts TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE flights TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE links TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE notifications TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE positions TO ", @new_prefix, TABLE_NAME, ';'
    "RENAME TABLE settings TO ", @new_prefix, TABLE_NAME, ';'
)
PREPARE stmt FROM @s;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

END;