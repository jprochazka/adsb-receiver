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
    `date` NUMERIC NOT NULL,
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
    `vertical_rate` INTEGER NOT NULL,
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
    `email` TEXT NOT NULL UNIQUE,
    `password` TEXT,
    `administrator` INTEGER DEFAULT 0,
    `role` TEXT DEFAULT 'User'
);

-- Sample users for testing role-based authentication
INSERT INTO users (`name`, `email`, `password`, `administrator`, `role`) VALUES 
('Admin User', 'admin@example.com', 'admin123', 1, 'Admin'),
('Regular User', 'user@example.com', 'user123', 0, 'User'),
('Test Admin', 'testadmin@example.com', 'test123', 1, 'Admin');

-- Default performance graph settings
INSERT INTO settings (`name`, `value`) VALUES
('graphs_measurement_range', 'imperialNautical'),
('graphs_measurement_temperature', 'imperial'),
('graphs_network_interface', 'eth0');

-- Default flights visibility settings
INSERT INTO settings (`name`, `value`) VALUES
('flights_nav_enabled', 'true'),
('blog_nav_enabled', 'true'),
('links_nav_enabled', 'true');

-- Default information visibility settings
INSERT INTO settings (`name`, `value`) VALUES
('info_nav_enabled', 'true'),
('info_system_enabled', 'true'),
('info_graphs_enabled', 'true');

-- Default map visibility settings
INSERT INTO settings (`name`, `value`) VALUES
('map_nav_enabled', 'true'),
('map_dump1090_enabled', 'true'),
('map_dump978_enabled', 'true'),
('map_adsbx_enabled', 'true'),
('map_pfclient_enabled', 'false');