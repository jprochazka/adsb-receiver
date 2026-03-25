DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS dump1090_positions;
DROP TABLE IF EXISTS dump1090_flights;
DROP TABLE IF EXISTS dump1090_aircraft;
DROP TABLE IF EXISTS dump978_positions;
DROP TABLE IF EXISTS dump978_flights;
DROP TABLE IF EXISTS dump978_aircraft;
DROP TABLE IF EXISTS blog_posts;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS links;
DROP TABLE IF EXISTS settings;

CREATE TABLE `dump1090_aircraft` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `icao` varchar(24) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `dump978_aircraft` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `icao` varchar(24) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `blog_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) NOT NULL,
  `date` datetime NOT NULL,
  `author` varchar(100) NOT NULL,
  `content` text NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight` varchar(10) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `dump1090_flights` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `aircraft` int(11) NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id)
);

CREATE TABLE `dump978_flights` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `aircraft` int(11) NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES dump978_aircraft(id)
);

CREATE TABLE `links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `address` varchar(250) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `dump1090_positions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight` bigint(20) NOT NULL,
  `aircraft` bigint(20) NOT NULL,
  `time` datetime NOT NULL,
  `message` int(11) NOT NULL,
  `squawk` int(4) DEFAULT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `track` int(11) NOT NULL,
  `altitude` int(5) NOT NULL,
  `vertical_rate` int(4) NOT NULL,
  `speed` int(4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id),
  FOREIGN KEY (flight) REFERENCES dump1090_flights(id)
);

CREATE TABLE `dump978_positions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight` bigint(20) DEFAULT NULL,
  `aircraft` bigint(20) NOT NULL,
  `time` datetime NOT NULL,
  `message` int(11) DEFAULT NULL,
  `squawk` int(4) DEFAULT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `track` int(11) NOT NULL,
  `altitude` int(5) NOT NULL,
  `vertical_rate` int(4) NOT NULL,
  `speed` int(4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES dump978_aircraft(id),
  FOREIGN KEY (flight) REFERENCES dump978_flights(id)
);

CREATE TABLE `settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL UNIQUE,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `email` varchar(75) NOT NULL UNIQUE,
  `password` varchar(255) DEFAULT NULL,
  `administrator` bit DEFAULT 0,
  `role` varchar(20) DEFAULT 'User',
  PRIMARY KEY (`id`)
);

-- Sample users for testing role-based authentication
INSERT INTO `users` (`name`, `email`, `password`, `administrator`, `role`) VALUES 
('Admin User', 'admin@example.com', 'admin123', 1, 'Admin'),
('Regular User', 'user@example.com', 'user123', 0, 'User'),
('Test Admin', 'testadmin@example.com', 'test123', 1, 'Admin');

-- Default performance graph settings
INSERT INTO `settings` (`name`, `value`) VALUES
('graphs_measurement_range', 'imperialNautical'),
('graphs_measurement_temperature', 'imperial'),
('graphs_network_interface', 'eth0'),
('graphs_dump1090_enabled', 'true'),
('graphs_dump978_enabled', 'false');

-- Default flights visibility settings
INSERT INTO `settings` (`name`, `value`) VALUES
('flights_nav_enabled', 'true'),
('blog_nav_enabled', 'true'),
('links_nav_enabled', 'true');

-- Default information visibility settings
INSERT INTO `settings` (`name`, `value`) VALUES
('info_nav_enabled', 'true'),
('info_system_enabled', 'true'),
('info_graphs_enabled', 'true');

-- Default map visibility settings
INSERT INTO `settings` (`name`, `value`) VALUES
('map_nav_enabled', 'true'),
('map_dump1090_enabled', 'true'),
('map_dump978_enabled', 'true'),
('map_adsbx_enabled', 'true'),
('map_pfclient_enabled', 'false');