DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS aircraft;
DROP TABLE IF EXISTS blog_posts;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS links;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS settings;

CREATE TABLE aircraft (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `icao` TEXT NOT NULL,
    `first_seen` TEXT NOT NULL,
    `last_seen` TEXT
);

CREATE TABLE blog_posts (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `title` TEXT Not Null,
    `date` TEXT NOT NULL,
    `author` TEXT NOT NULL,
    `content` TEXT NOT NULL
);

CREATE TABLE notifications (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `flight` TEXT NOT NULL
);

CREATE TABLE flights (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `aircraft` INTEGER NOT NULL,
    `flight` TEXT NOT NULL,
    `first_seen` TEXT NOT NULL,
    `last_seen` TEXT,
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
    `verticle_rate` INTEGER NOT NULL,
    `speed` INTEGER,
    FOREIGN KEY (aircraft) REFERENCES aircraft(id),
    FOREIGN KEY (flight) REFERENCES flights(id)
);

CREATE TABLE settings (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` TEXT NOT NULL,
    `value` TEXT NOT NULL
);

CREATE TABLE users (
    `id` INTEGER PRIMARY KEY AUTOINCREMENT,
    `name` TEXT NOT NULL,
    `email` TEXT NOT NULL,
    `login` TEXT NOT NULL,
    `password` TEXT,
    `administrator` INTEGER DEFAULT 0
);