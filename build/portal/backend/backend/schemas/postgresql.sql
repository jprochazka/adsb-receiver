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

CREATE TABLE dump1090_aircraft (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `icao` varchar(24) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) DEFAULT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE dump978_aircraft (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `icao` varchar(24) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) DEFAULT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE blog_posts (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `title` varchar(100) NOT NULL,
  `date` timestamp(0) NOT NULL,
  `author` varchar(100) NOT NULL,
  `content` text NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE notifications (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `flight` varchar(10) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE dump1090_flights (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `aircraft` int NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) DEFAULT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id)
);

CREATE TABLE dump978_flights (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `aircraft` int NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) DEFAULT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES dump978_aircraft(id)
);

CREATE TABLE links (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(100) NOT NULL,
  `address` varchar(250) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE dump1090_positions (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `flight` bigint NOT NULL,
  `aircraft` bigint NOT NULL,
  `time` timestamp(0) NOT NULL,
  `message` int NOT NULL,
  `squawk` int DEFAULT NULL,
  `latitude` double precision NOT NULL,
  `longitude` double precision NOT NULL,
  `track` int NOT NULL,
  `altitude` int NOT NULL,
  `vertical_rate` int NOT NULL,
  `speed` int DEFAULT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES dump1090_aircraft(id),
  FOREIGN KEY (flight) REFERENCES dump1090_flights(id)
);

CREATE TABLE dump978_positions (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `flight` bigint DEFAULT NULL,
  `aircraft` bigint NOT NULL,
  `time` timestamp(0) NOT NULL,
  `message` int DEFAULT NULL,
  `squawk` int DEFAULT NULL,
  `latitude` double precision NOT NULL,
  `longitude` double precision NOT NULL,
  `track` int NOT NULL,
  `altitude` int NOT NULL,
  `vertical_rate` int NOT NULL,
  `speed` int DEFAULT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES dump978_aircraft(id),
  FOREIGN KEY (flight) REFERENCES dump978_flights(id)
);

CREATE TABLE settings (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(50) NOT NULL UNIQUE,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE users (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(100) NOT NULL,
  `email` varchar(75) NOT NULL UNIQUE,
  `password` varchar(255) DEFAULT NULL,
  `administrator` bit DEFAULT 0,
  `role` varchar(20) DEFAULT 'User',
  PRIMARY KEY (id)
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
('graphs_network_interface', 'eth0'),
('graphs_dump1090_enabled', 'true'),
('graphs_dump978_enabled', 'false');

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