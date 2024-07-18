INSERT INTO aircraft (`icao`, `first_seen`, `last_seen`)
VALUES
  ('icao01', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  ('icao02', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  ('icao03', '2024-07-17 03:30:33', '2024-06-17 03:33:03'),
  ('icao04', '2024-07-17 04:40:44', '2024-06-17 04:44:04'),
  ('icao05', '2024-07-17 05:50:55', '2024-06-17 05:55:05');

INSERT INTO blog_posts (`title`, `date`, `author`, `content`)
VALUES
  ('Title One', '2024-07-03 13:00:01', 'User One', 'Content for blog post one.'),
  ('Title Two', '2024-07-04 14:30:02', 'User One', 'Content for blog post two.'),
  ('Title Three', '2024-07-05 15:00:03', 'User Three', 'Content for blog post three.'),
  ('Title Four', '2024-07-06 16:30:04', 'User Two', 'Content for blog post four.');

INSERT INTO flights (`aircraft`, `flight`, `first_seen`, `last_seen`)
VALUES
  (1, 'FLT0001', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  (2, 'FLT0002', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  (3, 'FLT0003', '2024-07-17 03:30:33', '2024-06-17 03:33:03'),
  (5, 'FLT0005', '2024-07-17 04:40:44', '2024-06-17 04:44:04');

INSERT INTO links (`name`, `address`)
VALUES
  ('Link One', 'https://adsbportal.com/one'),
  ('Link Two', 'https://adsbportal.com/two'),
  ('Link Three', 'https://adsbportal.com/four');

INSERT INTO notifications (`flight`)
VALUES
  ('FLT0011'),
  ('FLT0012'),
  ('FLT0013');

INSERT INTO positions (`flight`, `aircraft`, `time`, `message`, `squawk`, `latitude`, `longitude`, `track`, `altitude`, `verticle_rate`, `speed`)
VALUES
  (1, 1, '2024-06-17 01:11:01', 204, 6523, 42.649292, -84.960896, 98, 46975, 0, 477),
  (1, 1, '2024-06-17 01:11:46', 289, 6523, 42.646408, -84.934304, 98, 46975, 0, 477),
  (1, 1, '2024-06-17 01:11:31', 309, 6523, 42.637567, -84.8538, 98, 47000, 64, 476),
  (1, 1, '2024-06-17 01:11:16', 455, 6523, 42.631622, -84.799971, 99, 47000, 0, 475),
  (1, 1, '2024-06-17 01:10:01', 532, 6523, 42.625946, -84.748785, 99, 47000, 64, 474),
  (1, 1, '2024-07-17 01:11:11', 11696, 1621, 41.384474, -83.586981, 276, 41725, 0, 380),
  (1, 1, '2024-07-17 01:10:56', 11718, 1621, 41.38916, -83.650839, 276, 41725, 64, 380),
  (1, 1, '2024-07-17 01:10:41', 11771, 1621, 41.392993, -83.701065, 275, 41700, -192, 378),
  (1, 1, '2024-07-17 01:10:26', 11787, 1621, 41.394017, -83.71582, 275, 41725, -192, 378),
  (1, 1, '2024-07-17 01:10:11', 11790, 1621, 41.394017, -83.71582, 275, 41725, -192, 378),
  (4, 5, '2024-06-17 05:55:05', 323, 1317, 41.774163, -83.827344, 91, 36475, 832, 486),
  (4, 5, '2024-07-17 05:50:20', 340, 1317, 41.773837, -83.788828, 91, 36625, 960, 487),
  (4, 5, '2024-07-17 05:50:35', 417, 1317, 41.773464, -83.749737, 91, 36825, 768, 487),
  (4, 5, '2024-07-17 05:50:55', 504, 1317, 41.772903, -83.690727, 91, 37225, 1216, 484);

INSERT INTO settings (`name`, `value`)
VALUES
  ('SettingOne', 'ValueOne'),
  ('SettingTwo', 'ValueTwo'),
  ('SettingThree', 'ValueThree');

INSERT INTO users (`name`, `email`, `password`, `administrator`)
VALUES
  ('Name One', 'noreply@email-one.com', '$2y$0htWdxS7PxTvIwJNo2COJ7Rywgif4En0TmJbDvrjLRfWZOBX526yJUKW', 1),
  ('Name Two', 'noreply@email-two.com', '$2y$ui7QK047JldTekx828J2rfSVQ7N5yo6ETQIYGoBqpfFRbNr3EvWzQzt6', 0),
  ('Name Three', 'noreply@email-three.com', '$2y$7jiYNNoUa1zNu6dCLxv2mIurCG8nuDgOeUCeCPO9pkjiQ1zr8jfTzdEe', 0);