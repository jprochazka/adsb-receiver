INSERT INTO aircraft (`icao`, `first_seen`, `last_seen`)
VALUES
  ('icao01', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  ('icao02', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  ('icao03', '2024-07-17 03:30:33', '2024-06-17 03:33:03'),
  ('icao04', '2024-07-17 04:40:44', '2024-06-17 04:44:04'),
  ('icao05', '2024-07-17 05:50:55', '2024-06-17 05:55:05');

INSERT INTO positions (`flight`, `aircraft`, `time`, `message`, `squawk`, `latitude`, `longitude`, `track`, `altitude`, `verticle_rate`, `speed`)
VALUES
  (, 1, '2024-06-17 01:11:01', , , , , 5, , , )
  (, 1, '2024-06-17 01:11:46', , , , , 4, , , )
  (, 1, '2024-06-17 01:11:31', , , , , 3, , , )
  (, 1, '2024-06-17 01:11:16', , , , , 2, , , )
  (, 1, '2024-06-17 01:10:01', , , , , 1, , , )

  (, 1, '2024-07-17 01:11:11', , , , , 5, , , )
  (, 1, '2024-07-17 01:10:56', , , , , 4, , , )
  (, 1, '2024-07-17 01:10:41', , , , , 3, , , )
  (, 1, '2024-07-17 01:10:26', , , , , 2, , , )
  (, 1, '2024-07-17 01:10:11', , , , , 1, , , )

  (, 5, '2024-06-17 05:55:05', , , , , 4, , , )
  (, 5, '2024-07-17 05:50:20', , , , , 3, , , )
  (, 5, '2024-07-17 05:50:35', , , , , 2, , , )
  (, 5, '2024-07-17 05:50:55', , , , , 1, , , )

INSERT INTO users (`name`, `email`, `login`, `password`, `administrator`)
VALUES
  ('User One', 'noreply@adsbportal.com', 'login_one', '$2y$0htWdxS7PxTvIwJNo2COJ7Rywgif4En0TmJbDvrjLRfWZOBX526yJUKW', 1),
  ('User Two', 'noreply@adsbreceiver.net', 'login_two', '$2y$ui7QK047JldTekx828J2rfSVQ7N5yo6ETQIYGoBqpfFRbNr3EvWzQzt6', 0);