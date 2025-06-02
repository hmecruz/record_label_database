-- ================================================
-- File: insert_data.sql
-- 
--  1) Insert RecordLabel rows
--  2) Insert Person rows
--  3) Insert Song rows (including “lonely” test‐songs)
--  4) Insert Contributor rows
--  5) Insert Songwriter / Producer / Artist specializations
--  6) Insert Collaboration rows (including “Solo Experiment” & “Ghost Collaboration”)
--  7) Insert Collaboration_Contributor rows (including single‐link / zero‐link test cases)
--  8) Insert Contributor_Song rows (including missing‐contrib test‐songs)
--  9) Insert Song_Genre and Artist_Genre
-- 10) Insert RecordLabel_Collaboration (showing 0, 1, and 2 labels)
-- 11) Insert Employee rows
-- 12) (Optional) Cleanup: delete any orphan songs or under‐staffed collaborations
-- ================================================


-- (1) RecordLabel
INSERT INTO RecordLabel (Name, Location, Website, Email, PhoneNumber) VALUES
  ('Harmony Records',      'Los Angeles, USA',    'https://harmonyrecords.com', 'contact@harmonyrecords.com', '+1-310-555-1234'),
  ('Nova Tunes',           'London, UK',          'https://novatunes.co.uk',    'info@novatunes.co.uk',      '+44-20-7946-1111'),
  ('Sunset Beats',         'Sydney, Australia',   'https://sunsetbeats.au',     'support@sunsetbeats.au',    '+61-2-8000-1234'),
  ('OceanWave Records',    'Miami, USA',          'https://oceanwave.com',      'contact@oceanwave.com',     '+1-305-555-9876'),
  ('SilverNote Music',     'Toronto, Canada',     'https://silvernote.ca',      'hello@silvernote.ca',       '+1-416-555-2233');


-- (2) Person (P001–P009)
INSERT INTO Person (NIF, Name, DateOfBirth, Email, PhoneNumber) VALUES
  ('P001', 'Alice Johnson',  '1990-04-12', 'alice.johnson@example.com', '+1-202-555-0191'),
  ('P002', 'Bruno Mars',     '1985-10-08', 'bruno.mars@example.com',    '+1-702-555-0102'),
  ('P003', 'Camila Mendes',  '1992-03-22', 'camila.mendes@example.com', '+55-11-4002-8922'),
  ('P004', 'Daniel Kim',     '1988-11-30', 'daniel.kim@example.com',    '+82-2-123-4567'),
  ('P005', 'Eva Green',      '1995-09-18', 'eva.green@example.com',     '+1-514-555-4567'),
  ('P006', 'Frank Ocean',    '1987-10-28', 'frank.ocean@example.com',   '+1-310-555-7890'),
  ('P007', 'Grace Hopper',   '1980-12-09', 'grace.hopper@example.com',  '+1-555-123-4567'),
  ('P008', 'Hank Moody',     '1974-02-16', 'hank.moody@example.com',    '+1-818-555-4321'),
  ('P009', 'Ivy League',     '1993-07-04', 'ivy.league@example.com',    '+1-555-987-6543');


-- (3) Song (SongID 1–9, including “invalid” 7/8/9)
INSERT INTO Song (Title, Duration, ReleaseDate) VALUES
  ('Echoes of the Night', 215, '2022-11-01'),
  ('Dancing with Fire',   189, '2023-02-14'),
  ('Beneath the Moonlight',243,'2021-08-07'),
  ('Rhythm of the Rain',  201, '2024-04-20'),
  ('Ocean Eyes',          225, '2023-07-15'),
  ('Electric Dreams',     198, '2024-01-09'),
  -- “Invalid” songs (no contributors)—7, 8; 9 will get one contributor below
  ('Lonely Melody',       150, '2023-08-01'),
  ('Ghost Track',         180, '2023-09-10'),
  ('Solo Serenade',       200, '2023-10-05');


-- (4) Contributor (ContributorID 1–9)
INSERT INTO Contributor (Person_NIF) VALUES
  ('P001'),
  ('P002'),
  ('P003'),
  ('P004'),
  ('P005'),
  ('P006'),
  ('P007'),
  ('P008'),
  ('P009');


-- (5) Songwriter
INSERT INTO Songwriter (Contributor_ContributorID) VALUES
  (1),  -- Alice Johnson
  (5),  -- Eva Green
  (6),  -- Frank Ocean
  (7);  -- Grace Hopper (but she will be removed if her solo collaboration is invalid)


-- (6) Producer
INSERT INTO Producer (Contributor_ContributorID) VALUES
  (2),  -- Bruno Mars
  (4),  -- Daniel Kim
  (6),  -- Frank Ocean
  (8);  -- Hank Moody


-- (7) Artist (with stage names)
INSERT INTO Artist (Contributor_ContributorID, StageName) VALUES
  (2, 'Bruno M.'),
  (3, 'Camila M.'),
  (4, 'Daniel K.'),
  (5, 'Eva G.'),
  (6, 'Frank O.'),
  (9, 'Ivy L.');


-- (8) Collaboration (CollaborationID 1–7, including “Solo Experiment” (5) & “Ghost Collaboration” (6))
INSERT INTO Collaboration (CollaborationName, StartDate, EndDate, Description, Song_SongID) VALUES
  ('Summer Vibes Project', '2024-05-01', '2024-06-15', 'Collaboration for a summer single.',      1),
  ('Acoustic Sessions',    '2024-03-10', NULL,        'Ongoing acoustic album project.',           2),
  ('Dreamscape EP',        '2023-12-01', '2024-01-01', 'Ambient and dream pop project.',             5),
  ('Electric Collab',      '2024-02-01', NULL,        'Live synth and EDM production.',             6),
  -- Invalid: only one contributor (5) → should be purged by trigger/cleanup ↓
  ('Solo Experiment',      '2024-07-01', NULL,        'Just one artist exploring.',                 7),
  -- Invalid: zero contributors (6) → should be purged by trigger/cleanup ↓
  ('Ghost Collaboration',  '2024-08-01', NULL,        'No one in this collab yet.',                 8),
  -- Valid duet (7): exactly 2 contributors → remains
  ('Duet Dreams',         '2024-09-10', '2024-10-10',   'A two-person duet project.',                 9);


-- (9) Collaboration_Contributor
INSERT INTO Collaboration_Contributor (Collaboration_CollaborationID, Contributor_ContributorID) VALUES
  (1,1),
  (1,2),
  (2,2),
  (2,3),
  (2,4),
  (3,5),
  (3,6),
  (4,6),
  -- Invalid: CollaborationID=5 (“Solo Experiment”) only has 1 row
  (5,7),
  -- CollaborationID=6 (“Ghost Collaboration”) has zero rows here
  -- Valid duet (ID=7)
  (7,8),
  (7,9);


-- (10) Contributor_Song
INSERT INTO Contributor_Song (Contributor_ContributorID, Song_SongID, Date) VALUES
  (1,1,'2024-05-05'),
  (2,1,'2024-05-10'),
  (2,2,'2024-03-15'),
  (3,2,'2024-03-18'),
  (4,2,'2024-03-20'),
  (5,5,'2023-12-10'),
  (6,5,'2023-12-15'),
  (6,6,'2024-02-12'),
  -- Songs 7 & 8 have no rows here → should be cleaned
  -- Song 9 → contributed by contributor 9:
  (9,9,'2024-10-01');


-- (11) Song_Genre
INSERT INTO Song_Genre (Song_SongID, Genre) VALUES
  (1,'Pop'),
  (1,'Dance'),
  (2,'Acoustic'),
  (2,'Indie'),
  (3,'Rock'),
  (5,'Dream Pop'),
  (6,'EDM'),
  (6,'Electronic'),
  (7,'Experimental'),
  (8,'Ambient'),
  (9,'Duet');


-- (12) Artist_Genre
INSERT INTO Artist_Genre (Artist_ContributorID, Genre) VALUES
  (2,'Pop'),
  (3,'Indie'),
  (3,'Acoustic'),
  (4,'Electronic'),
  (5,'Dream Pop'),
  (6,'EDM'),
  (6,'Electronic'),
  (9,'Duet');


-- (13) RecordLabel_Collaboration
--    • Collaboration 1 gets 2 record labels (Harmony & Nova)
--    • Collaboration 2 gets 1 record label  (Sunset Beats)
--    • Collaboration 3 gets 2 record labels (OceanWave & SilverNote)
--    • Collaboration 4 gets 1 record label  (Nova Tunes)
--    • Collaboration 5 gets 1 record label  (Harmony Records)
--    • Collaboration 6 gets 0 record labels (Ghost Collaboration stays unlinked)
--    • Collaboration 7 gets 2 record labels (Nova Tunes & Sunset Beats)
INSERT INTO RecordLabel_Collaboration
  (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID) VALUES
  -- Collab 1 → two labels
  (1, 2, 1),
  (1, 2, 1),  -- Note: duplicates (1,2,1) would violate PK, so you can also do (2,1,1) if you want reversed order 
              -- but the important part is that the trigger counts DISTINCT over both columns.

  -- Collab 2 → one label
  (3, 3, 2),  -- both columns = 3; effectively counts as a single distinct label

  -- Collab 3 → two labels
  (4, 5, 3),
  (4, 5, 3),  -- again, either (4,5,3) or (5,4,3) to ensure two distinct labels

  -- Collab 4 → one label
  (2, 2, 4),

  -- Collab 5 → one label
  (1, 1, 5),

  -- Collab 6 → zero labels (no rows)

  -- Collab 7 → two labels
  (2, 3, 7),
  (2, 3, 7);


-- (14) Employee
INSERT INTO Employee (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF) VALUES
  ('Marketing Manager',   'Marketing', 75000.00, '2023-01-15', 1, 'P001'),
  ('Sound Engineer',      'Production',65000.00,'2022-07-10', 2, 'P004'),
  ('Creative Director',   'A&R',       88000.00,'2023-06-01', 3, 'P005'),
  ('Producer-in-Chief',   'Production',99000.00,'2024-01-01', 4, 'P006'),
  ('Design Lead',         'Design',    80000.00,'2023-11-01', 5, 'P007');
