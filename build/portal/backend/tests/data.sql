INSERT INTO dump1090_aircraft (icao, first_seen, last_seen)
VALUES
  ('icao01', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  ('icao02', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  ('icao03', '2024-07-17 03:30:33', '2024-06-17 03:33:03'),
  ('icao04', '2024-07-17 04:40:44', '2024-06-17 04:44:04'),
  ('icao05', '2024-07-17 05:50:55', '2024-06-17 05:55:05');

INSERT INTO blog_posts (title, date, author, content, visible, tags, category)
VALUES
  ('Title One',   '2024-07-03 13:00:01', 'User One',   'Content for blog post one.',   1, 'update,receiver', 'News'),
  ('Title Two',   '2024-07-04 14:30:02', 'User One',   'Content for blog post two.',   1, 'maintenance,receiver', 'Maintenance'),
  ('Title Three', '2024-07-05 15:00:03', 'User Three', 'Content for blog post three.', 1, 'feature,portal', 'Updates'),
  ('Title Four',  '2024-07-06 16:30:04', 'User Two',   'Content for blog post four.',  1, 'announcement,portal', 'Announcements'),
  ('Title Five',  '2024-07-07 09:00:00', 'User One',   'Content for blog post five.',  1, 'receiver,update,maintenance', 'News'),
  ('Title Six',   '2024-07-08 10:00:00', 'User Two',   'Content for blog post six.',   1, 'receiver,feature,update', 'Updates'),
  ('Title Seven', '2024-07-09 11:00:00', 'User Three', 'Content for blog post seven.', 1, 'receiver,portal,maintenance', 'Maintenance'),
  ('Title Eight', '2024-07-10 12:00:00', 'User One',   'Content for blog post eight.', 1, 'update,portal,announcement', 'Announcements'),
  ('Title Nine',  '2024-07-11 13:00:00', 'User Two',   'Content for blog post nine.',  1, 'receiver,update,feature', 'News'),
  ('Title Ten',   '2024-07-12 14:00:00', 'User Three', 'Content for blog post ten.',   1, 'maintenance,portal,announcement', 'Updates');

INSERT INTO dump1090_flights (aircraft, flight, first_seen, last_seen)
VALUES
  (1, 'FLT0001', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  (2, 'FLT0002', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  (3, 'FLT0003', '2024-07-17 03:30:33', '2024-06-17 03:33:03'),
  (5, 'FLT0005', '2024-07-17 04:40:44', '2024-06-17 04:44:04');

INSERT INTO links (name, address, sort_order)
VALUES
  ('Link One', 'https://adsbportal.com/one', 1),
  ('Link Two', 'https://adsbportal.com/two', 3),
  ('Link Three', 'https://adsbportal.com/three', 2);

INSERT INTO notifications (flight)
VALUES
  ('FLT0011'),
  ('FLT0012'),
  ('FLT0013');

INSERT INTO dump1090_positions (flight, aircraft, time, message, squawk, latitude, longitude, track, altitude, vertical_rate, speed)
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

INSERT INTO settings (name, value)
VALUES
  ('setting_one', 'Value One'),
  ('setting_two', 'Value Two'),
  ('setting_three', 'Value Three');

INSERT INTO users (name, email, password, administrator, role, locked, created_at)
VALUES
  ('Admin User', 'noreply@email-one.com', 'scrypt:32768:8:1$gi1auJ6fnbiH4mJh$ef78969d738ebd2a5f45c6e0684965d2b46fcfe8e33ee0fb454ece76eb90dd84da369780a7c6e8d1355cf1be378b0191a0d5dd127bde2df69958f707829fbec5', 1, 'Admin', 0, '2024-01-03 00:00:00'),
  ('Regular User', 'noreply@email-two.com', 'scrypt:32768:8:1$MOk0YSkhhDmIwAXh$4ef9d8f3a4cff8969cb2bb88b92679c0f9fd7836f2f6719a5caf6a6f1ed835eb7a326842430792717f8c11b49a6f294e31f6c160a06643fb4b68fc8945553bf1', 0, 'User', 0, '2024-01-01 00:00:00'),
  ('Another User', 'noreply@email-three.com', 'scrypt:32768:8:1$NoLaKcpeOtxpLkcw$a6703a315290925928b9edd892c3131b8ac8e2f6588b1faf05fe2496b3126ff0a2e5838d1e35613305bff939d30311318525cb30332ed16fe9d1d76457ea31c5', 0, 'User', 0, '2024-01-02 00:00:00');

INSERT INTO blog_comments (blog_post_id, user_id, parent_comment_id, content, created_at, edited, edited_at, deleted, deleted_at)
VALUES
  (1, 2, NULL, 'First top-level comment.', '2024-07-07 10:00:00', 0, NULL, 0, NULL),
  (1, 3, 1, 'Reply to the first comment.', '2024-07-07 10:05:00', 0, NULL, 0, NULL),
  (1, 1, NULL, 'Second top-level comment.', '2024-07-07 10:10:00', 0, NULL, 0, NULL);

INSERT INTO dump978_aircraft (icao, first_seen, last_seen)
VALUES
  ('uicao01', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  ('uicao02', '2024-07-17 02:20:22', '2024-06-17 02:22:02'),
  ('uicao03', '2024-07-17 03:30:33', NULL);

INSERT INTO dump978_flights (aircraft, flight, first_seen, last_seen)
VALUES
  (1, 'UAT0001', '2024-07-17 01:10:11', '2024-06-17 01:11:01'),
  (2, 'UAT0002', '2024-07-17 02:20:22', '2024-06-17 02:22:02');

INSERT INTO dump978_positions (flight, aircraft, time, message, squawk, latitude, longitude, track, altitude, vertical_rate, speed)
VALUES
  (1, 1, '2024-06-17 01:11:01', 50,   6523, 42.649292, -84.960896, 98, 4000,  0,   120),
  (1, 1, '2024-06-17 01:11:46', 75,   6523, 42.646408, -84.934304, 98, 4100,  64,  121),
  (2, 2, '2024-06-17 02:10:01', 100,  1234, 41.774163, -83.827344, 91, 5000, 100,  130),
  (NULL, 3, '2024-06-17 03:30:33', NULL, 4321, 43.000000, -85.000000, 90, 3000, 0, 110);