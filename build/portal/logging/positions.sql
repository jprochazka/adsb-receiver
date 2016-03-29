CREATE TABLE adsb_positions( 
  id INT(11) AUTO_INCREMENT PRIMARY KEY,
  flight BIGINT NOT NULL,
  time VARCHAR(100) NOT NULL,
  message INT NOT NULL,
  squawk INT(4) NULL,
  latitude DOUBLE NOT NULL,
  longitude DOUBLE NOT NULL,
  track INT(11) NOT NULL,
  altitude INT(5) NOT NULL,
  verticleRate INT(4) NOT NULL,
  speed INT(4) NULL);
