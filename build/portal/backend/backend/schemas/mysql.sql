DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS aircraft;
DROP TABLE IF EXISTS logPosts;
DROP TABLE IF EXISTS flightNotifications;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS links;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS settings;

CREATE TABLE `aircraft` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `icao` varchar(24) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime NOT NULL,
  PRIMARY KEY (`id`),
);

CREATE TABLE `blog_posts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(100) NOT NULL,
  `date` datetime NOT NULL,
  `author` varchar(100) NOT NULL,
  `contents` text NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `flight` varchar(10) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `flights` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `aircraft` int(11) NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` datetime NOT NULL,
  `last_seen` datetime NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES aircraft(id)
);

CREATE TABLE `links` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `address` varchar(250) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `positions` (
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
  `verticle_rate` int(4) NOT NULL,
  `speed` int(4) DEFAULT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (aircraft) REFERENCES aircraft(id),
  FOREIGN KEY (flight) REFERENCES flights(id)
);

CREATE TABLE `settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (`id`)
);

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `email` varchar(75) NOT NULL,
  `login` varchar(25) NOT NULL,
  `password` varchar(255) NOT NULL,
  `administrator` bit DEFAULT 0,
  PRIMARY KEY (`id`)
);