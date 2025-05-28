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
-- DELETE Query
-- =========================

-- Delete a song by SongID
DELETE FROM Song
WHERE SongID = 1;
