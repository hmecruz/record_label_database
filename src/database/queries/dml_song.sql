-- Song DML Queries

-- =========================
-- SELECT Queries
-- =========================

-- Retrieving all songs from the Song table
SELECT * FROM Song;

-- Filter songs by genre
SELECT s.*
FROM Song s
JOIN Song_Genre sg ON s.SongID = sg.Song_SongID
WHERE sg.Genre = 'Pop';

-- Filter songs by date (range)
SELECT *
FROM Song
WHERE ReleaseDate BETWEEN '2023-01-01' AND '2023-12-31';

-- Filter songs by duration (in seconds)
SELECT *
FROM Song
WHERE Duration BETWEEN 180 AND 240;

-- Filter songs by title containing a specific keyword
SELECT *
FROM Song
WHERE Title LIKE '%Night%';

-- Filter by Artist stage name
SELECT s.*
FROM Song s
JOIN Contributor_Song cs ON s.SongID = cs.Song_SongID
JOIN Contributor c ON cs.Contributor_ContributorID = c.ContributorID
JOIN Artist a ON c.ContributorID = a.Contributor_ContributorID
WHERE a.StageName = 'Bruno M.';

-- Filter by ContributorID
SELECT s.*
FROM Song s
JOIN Contributor_Song cs ON s.SongID = cs.Song_SongID
WHERE cs.Contributor_ContributorID = 2;


-- =========================
-- INSERT Query
-- =========================

-- Insert a new song into the Song table
INSERT INTO Song (Title, Duration, ReleaseDate)
VALUES ('New Song Title', 210, '2025-01-01');


-- =========================
-- UPDATE Query
-- =========================

-- Update a song's title, duration, and/or release date by SongID
UPDATE Song
SET Title = 'Updated Song Title',
    Duration = 220,
    ReleaseDate = '2025-02-01'
WHERE SongID = 1;


-- =========================
-- DELETE Queries for SONG
-- =========================

BEGIN TRANSACTION;

DECLARE @SongID INT = 1;  -- ← replace with the SongID you want to delete

-- 1) Find all collaborations that reference this song
DECLARE @CollabIDs TABLE (CollaborationID INT);
INSERT INTO @CollabIDs (CollaborationID)
SELECT CollaborationID
FROM Collaboration
WHERE Song_SongID = @SongID;

-- 2) Delete any RecordLabel_Collaboration rows for those collaborations
DELETE rl
FROM RecordLabel_Collaboration rl
JOIN @CollabIDs c ON rl.Collaboration_CollaborationID = c.CollaborationID;

-- 3) Delete any Collaboration_Contributor rows for those collaborations
DELETE cc
FROM Collaboration_Contributor cc
JOIN @CollabIDs c ON cc.Collaboration_CollaborationID = c.CollaborationID;

-- 4) Delete the collaborations themselves
DELETE col
FROM Collaboration col
JOIN @CollabIDs c ON col.CollaborationID = c.CollaborationID;

-- 5) Delete the song (this will CASCADE to Contributor_Song and Song_Genre)
DELETE FROM Song
WHERE SongID = @SongID;

COMMIT TRANSACTION;
