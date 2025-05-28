-- Inserting data into RecordLabel table
INSERT INTO RecordLabel (Name, Location, Website, Email, PhoneNumber) VALUES
('Harmony Records', 'Los Angeles, USA', 'https://harmonyrecords.com', 'contact@harmonyrecords.com', '+1-310-555-1234'),
('Nova Tunes', 'London, UK', 'https://novatunes.co.uk', 'info@novatunes.co.uk', '+44-20-7946-1111'),
('Sunset Beats', 'Sydney, Australia', 'https://sunsetbeats.au', 'support@sunsetbeats.au', '+61-2-8000-1234');


-- Inserting data into Person table
INSERT INTO Person (NIF, Name, DateOfBirth, Email, PhoneNumber) VALUES
('P001', 'Alice Johnson', '1990-04-12', 'alice.johnson@example.com', '+1-202-555-0191'),
('P002', 'Bruno Mars', '1985-10-08', 'bruno.mars@example.com', '+1-702-555-0102'),
('P003', 'Camila Mendes', '1992-03-22', 'camila.mendes@example.com', '+55-11-4002-8922'),
('P004', 'Daniel Kim', '1988-11-30', 'daniel.kim@example.com', '+82-2-123-4567');


-- Inserting data into Song table
INSERT INTO Song (Title, Duration, ReleaseDate) VALUES
('Echoes of the Night', 215, '2022-11-01'),
('Dancing with Fire', 189, '2023-02-14'),
('Beneath the Moonlight', 243, '2021-08-07'),
('Rhythm of the Rain', 201, '2024-04-20');


-- Inserting data into Contributor table
INSERT INTO Contributor (Person_NIF) VALUES
('P001'), -- Alice Johnson
('P002'), -- Bruno Mars
('P003'), -- Camila Mendes
('P004'); -- Daniel Kim


-- Inserting data into Songwriter table
INSERT INTO Songwriter (Contributor_ContributorID) VALUES
(1); -- Alice Johnson


-- Inserting data into Producer table
INSERT INTO Producer (Contributor_ContributorID) VALUES
(2), -- Bruno Mars
(4); -- Daniel Kim


-- Inserting data into Artist table
INSERT INTO Artist (Contributor_ContributorID, StageName) VALUES
(2, 'Bruno M.'),
(3, 'Camila M.');


-- Inserting data into Collaboration table
INSERT INTO Collaboration (CollaborationName, StartDate, EndDate, Description, Song_SongID) VALUES
('Summer Vibes Project', '2024-05-01', '2024-06-15', 'Collaboration for a summer single.', 1),
('Acoustic Sessions', '2024-03-10', NULL, 'Ongoing acoustic album project.', 2);


-- Inserting data into Collaboration_Contributor table
INSERT INTO Collaboration_Contributor (Collaboration_CollaborationID, Contributor_ContributorID) VALUES
(1, 1), -- Alice Johnson in Summer Vibes
(1, 2), -- Bruno Mars in Summer Vibes
(2, 2), -- Bruno Mars in Acoustic Sessions
(2, 3), -- Camila Mendes in Acoustic Sessions
(2, 4); -- Daniel Kim in Acoustic Sessions


-- Inserting data into Contributor_Song table
INSERT INTO Contributor_Song (Contributor_ContributorID, Song_SongID, Date) VALUES
(1, 1, '2024-05-05'), -- Alice wrote Summer Time Love
(2, 1, '2024-05-10'), -- Bruno performed/produced Summer Time Love
(2, 2, '2024-03-15'), -- Bruno performed in Acoustic Breeze
(3, 2, '2024-03-18'), -- Camila performed in Acoustic Breeze
(4, 2, '2024-03-20'); -- Daniel produced Acoustic Breeze


-- Inserting data into Song_Genre table
INSERT INTO Song_Genre (Song_SongID, Genre) VALUES
(1, 'Pop'),
(1, 'Dance'),
(2, 'Acoustic'),
(2, 'Indie');


-- Inserting data into Artist_Genre table
INSERT INTO Artist_Genre (Artist_ContributorID, Genre) VALUES
(2, 'Pop'),       -- Bruno Mars
(3, 'Indie'),     -- Camila Mendes
(3, 'Acoustic'),  -- Camila Mendes
(4, 'Electronic');-- Daniel Kim


-- Inserting data into RecordLabel_Collaboration table
INSERT INTO RecordLabel_Collaboration (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID) VALUES
(1, 2, 1);  -- Sunset Records and Moonlight Music on Summer Vibes


-- Inserting data into Employee table
INSERT INTO Employee (JobTitle, Department, Salary, HireDate, RecordLabel_RecordLabelID, Person_NIF) VALUES
('Marketing Manager', 'Marketing', 75000.00, '2023-01-15', 1, 'P001'),  -- Alice Johnson at Harmony Records
('Sound Engineer', 'Production', 65000.00, '2022-07-10', 2, 'P004');     -- Daniel Kim at Nova Tunes



