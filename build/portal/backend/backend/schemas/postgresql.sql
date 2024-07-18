DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS aircraft;
DROP TABLE IF EXISTS blog_posts;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS flights;
DROP TABLE IF EXISTS links;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS settings;

CREATE TABLE aircraft (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `icao` varchar(24) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) NOT NULL,
  PRIMARY KEY (id),
);

CREATE TABLE blog_posts (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `title` varchar(100) NOT NULL,
  `date` timestamp(0) NOT NULL,
  `author` varchar(100) NOT NULL,
  `contents` text NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE notifications (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `flight` varchar(10) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE flights (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `aircraft` int NOT NULL,
  `flight` varchar(100) NOT NULL,
  `first_seen` timestamp(0) NOT NULL,
  `last_seen` timestamp(0) NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES aircraft(id)
);

CREATE TABLE links (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(100) NOT NULL,
  `address` varchar(250) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE positions (
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
  `verticle_rate` int NOT NULL,
  `speed` int DEFAULT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (aircraft) REFERENCES aircraft(id),
  FOREIGN KEY (flight) REFERENCES flights(id)
);

CREATE TABLE settings (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(50) NOT NULL,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (id)
);

CREATE TABLE users (
  `id` int NOT NULL GENERATED ALWAYS AS IDENTITY,
  `name` varchar(100) NOT NULL,
  `email` varchar(75) NOT NULL,
  `password` varchar(255) NOT NULL,
  `administrator` bit DEFAULT 0,
  PRIMARY KEY (id)
);