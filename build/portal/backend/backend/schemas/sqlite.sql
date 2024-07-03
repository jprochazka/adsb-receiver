DROP TABLE IF EXISTS administrators;
DROP TABLE IF EXISTS aircraft;
DROP TABLE IF EXISTS blogPosts;
DROP TABLE IF EXISTS flightNotifications;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS links;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS settings;

CREATE TABLE administrators (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` TEXT NOT NULL,
    `email` TEXT NOT NULL,
    `password` TEXT,
    `token` TEXT
);

CREATE TABLE aircraft (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `icao` TEXT NOT NULL,
    `firstSeen` TEXT NOT NULL,
    `lastSeen` TEXT
);

CREATE TABLE blogPosts (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `title` TEXT Not Null,
    `date` TEXT NOT NULL,
    `author` TEXT NOT NULL,
    `content` TEXT NOT NULL
);

CREATE TABLE flightNotifications (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `flight` TEXT NOT NULL
);

CREATE TABLE flights (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `aircraft` INTEGER NOT NULL,
    `flight` TEXT NOT NULL,
    `firstSeen` TEXT NOT NULL,
    `lastSeen` TEXT,
    FOREIGN KEY(aircraft) REFERENCES aircraft(id)
);

CREATE TABLE links (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` TEXT NOT NULL,
    `address` TEXT NOT NULL
);

CREATE TABLE positions (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `flight` INTEGER NOT NULL,
    `aircraft` INTEGER NOT NULL,
    `time` TEXT NOT NULL,
    `message` INTEGER NOT NULL,
    `squawk` INTEGER,
    `latitude` REAL NOT NULL,
    `longitude` REAL NOT NULL,
    `track` INTEGER NOT NULL,
    `altitude` INTEGER NOT NULL,
    `verticleRate` INTEGER NOT NULL,
    `speed` INTEGER,
    FOREIGN KEY (aircraft) REFERENCES aircraft(id),
    FOREIGN KEY (flight) REFERENCES flights(id)
);

CREATE TABLE settings (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` TEXT NOT NULL,
    `value` TEXT NOT NULL
);