-- Inserting data into RecordLabel table (IDs 1–5)
INSERT INTO RecordLabel (Name, Location, Website, Email, PhoneNumber) VALUES
  ('Harmony Records',      'Los Angeles, USA',    'https://harmonyrecords.com', 'contact@harmonyrecords.com', '+1-310-555-1234'),
  ('Nova Tunes',           'London, UK',          'https://novatunes.co.uk',    'info@novatunes.co.uk',      '+44-20-7946-1111'),
  ('Sunset Beats',         'Sydney, Australia',   'https://sunsetbeats.au',     'support@sunsetbeats.au',    '+61-2-8000-1234'),
  ('OceanWave Records',    'Miami, USA',          'https://oceanwave.com',      'contact@oceanwave.com',     '+1-305-555-9876'),
  ('SilverNote Music',     'Toronto, Canada',     'https://silvernote.ca',      'hello@silvernote.ca',       '+1-416-555-2233');

-- Inserting data into Person table (NIFs P001–P006)
INSERT INTO Person (NIF, Name, DateOfBirth, Email, PhoneNumber) VALUES
  ('P001', 'Alice Johnson', '1990-04-12', 'alice.johnson@example.com', '+1-202-555-0191'),
  ('P002', 'Bruno Mars',    '1985-10-08', 'bruno.mars@example.com',    '+1-702-555-0102'),
  ('P003', 'Camila Mendes', '1992-03-22', 'camila.mendes@example.com', '+55-11-4002-8922'),
  ('P004', 'Daniel Kim',    '1988-11-30', 'daniel.kim@example.com',    '+82-2-123-4567'),
  ('P005', 'Eva Green',     '1995-09-18', 'eva.green@example.com',     '+1-514-555-4567'),
  ('P006', 'Frank Ocean',   '1987-10-28', 'frank.ocean@example.com',   '+1-310-555-7890');

-- Inserting data into Song table (SongID 1–6)
INSERT INTO Song (Title, Duration, ReleaseDate) VALUES
  ('Echoes of the Night', 215, '2022-11-01'),
  ('Dancing with Fire',   189, '2023-02-14'),
  ('Beneath the Moonlight',243, '2021-08-07'),
  ('Rhythm of the Rain',  201, '2024-04-20'),
  ('Ocean Eyes',          225, '2023-07-15'),
  ('Electric Dreams',     198, '2024-01-09');

-- Inserting data into Contributor table (ContributorID 1–6)
INSERT INTO Contributor (Person_NIF) VALUES
  ('P001'),
  ('P002'),
  ('P003'),
  ('P004'),
  ('P005'),
  ('P006');

-- Inserting data into Songwriter table
INSERT INTO Songwriter (Contributor_ContributorID) VALUES
  (1),  -- Alice Johnson
  (5),  -- Eva Green
  (6);  -- Frank Ocean

-- Inserting data into Producer table
INSERT INTO Producer (Contributor_ContributorID) VALUES
  (2),  -- Bruno Mars
  (4),  -- Daniel Kim
  (6);  -- Frank Ocean

-- Inserting data into Artist table, including Daniel Kim (4)
INSERT INTO Artist (Contributor_ContributorID, StageName) VALUES
  (2, 'Bruno M.'),
  (3, 'Camila M.'),
  (4, 'Daniel K.'),
  (5, 'Eva G.'),
  (6, 'Frank O.');

-- Inserting data into Collaboration table (CollaborationID 1–4)
INSERT INTO Collaboration (CollaborationName, StartDate, EndDate, Description, Song_SongID) VALUES
  ('Summer Vibes Project', '2024-05-01', '2024-06-15', 'Collaboration for a summer single.', 1),
  ('Acoustic Sessions',    '2024-03-10', NULL,        'Ongoing acoustic album project.', 2),
  ('Dreamscape EP',        '2023-12-01', '2024-01-01', 'Ambient and dream pop project.', 5),
  ('Electric Collab',      '2024-02-01', NULL,        'Live synth and EDM production.', 6);

-- Inserting data into Collaboration_Contributor
INSERT INTO Collaboration_Contributor (Collaboration_CollaborationID, Contributor_ContributorID) VALUES
  (1,1),
  (1,2),
  (2,2),
  (2,3),
  (2,4),
  (3,5),
  (3,6),
  (4,6);

-- Inserting data into Contributor_Song
INSERT INTO Contributor_Song (Contributor_ContributorID, Song_SongID, Date) VALUES
  (1,1,'2024-05-05'),
  (2,1,'2024-05-10'),
  (2,2,'2024-03-15'),
  (3,2,'2024-03-18'),
  (4,2,'2024-03-20'),
  (5,5,'2023-12-10'),
  (6,5,'2023-12-15'),
  (6,6,'2024-02-12');

-- Inserting data into Song_Genre
INSERT INTO Song_Genre (Song_SongID, Genre) VALUES
  (1,'Pop'),
  (1,'Dance'),
  (2,'Acoustic'),
  (2,'Indie'),
  (5,'Dream Pop'),
  (6,'EDM'),
  (6,'Electronic');

-- Inserting data into Artist_Genre
INSERT INTO Artist_Genre (Artist_ContributorID, Genre) VALUES
  (2,'Pop'),
  (3,'Indie'),
  (3,'Acoustic'),
  (4,'Electronic'),
  (5,'Dream Pop'),
  (6,'EDM'),
  (6,'Electronic');

-- Inserting data into RecordLabel_Collaboration
INSERT INTO RecordLabel_Collaboration (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID) VALUES
  (1,2,1),
  (3,4,3),
  (2,5,4);

-- Inserting data into Employee table
INSERT INTO Employee (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF) VALUES
  ('Marketing Manager',   'Marketing', 75000.00, '2023-01-15', 1, 'P001'),
  ('Sound Engineer',      'Production',65000.00,'2022-07-10', 2, 'P004'),
  ('Creative Director',   'A&R',       88000.00,'2023-06-01', 3, 'P005'),
  ('Producer-in-Chief',   'Production',99000.00,'2024-01-01', 4, 'P006');