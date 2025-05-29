-- Contributor DML Queries

-- =========================
-- SELECT Queries
-- =========================

-- Get detailed info about a contributor (Name, DateOfBirth, Email, Phone, and roles)
SELECT 
    c.ContributorID,
    p.Name,
    p.DateOfBirth,
    p.Email,
    p.PhoneNumber,
    CASE 
        WHEN a.Contributor_ContributorID IS NOT NULL THEN 'Artist'
        WHEN s.Contributor_ContributorID IS NOT NULL THEN 'Songwriter'
        WHEN pr.Contributor_ContributorID IS NOT NULL THEN 'Producer'
        ELSE 'Unknown'
    END AS Role
FROM Contributor c
JOIN Person p ON c.Person_NIF = p.NIF
LEFT JOIN Artist a ON c.ContributorID = a.Contributor_ContributorID
LEFT JOIN Songwriter s ON c.ContributorID = s.Contributor_ContributorID
LEFT JOIN Producer pr ON c.ContributorID = pr.Contributor_ContributorID;

-- List all songs a contributor helped write, produce, or perform
SELECT 
    c.ContributorID,
    p.Name,
    s.SongID,
    s.Title,
    s.ReleaseDate
FROM Contributor c
JOIN Person p ON c.Person_NIF = p.NIF
JOIN Contributor_Song cs ON c.ContributorID = cs.Contributor_ContributorID
JOIN Song s ON cs.Song_SongID = s.SongID
WHERE c.ContributorID = 1;

-- View genres an artist is known for
SELECT 
    a.Contributor_ContributorID AS ArtistID,
    ar.StageName,
    ag.Genre
FROM Artist ar
JOIN Artist_Genre ag ON ar.Contributor_ContributorID = ag.Artist_ContributorID
WHERE ar.Contributor_ContributorID = 1;


-- =========================
-- UPDATE Queries
-- =========================

-- Update email and phone number for a contributor (via Person)
UPDATE Person
SET Email = 'newemail@example.com',
    PhoneNumber = '123-456-7890'
WHERE NIF = '123456789';


-- =========================
-- DELETE Queries for Contributor
-- =========================

BEGIN TRANSACTION;

DECLARE @ContributorID INT = 1;  -- Replace with the actual ContributorID to delete

-- First, delete from Contributor_Song association (if NOT handled by ON DELETE CASCADE)
DELETE FROM Contributor_Song
WHERE Contributor_ContributorID = @ContributorID;

-- Delete from Collaboration_Contributor association (if NOT handled by ON DELETE CASCADE)
DELETE FROM Collaboration_Contributor
WHERE Contributor_ContributorID = @ContributorID;

-- Delete Artist role (if exists)
DELETE FROM Artist
WHERE Contributor_ContributorID = @ContributorID;

-- Delete Songwriter role (if exists)
DELETE FROM Songwriter
WHERE Contributor_ContributorID = @ContributorID;

-- Delete Producer role (if exists)
DELETE FROM Producer
WHERE Contributor_ContributorID = @ContributorID;

-- Finally, delete the Contributor itself
DELETE FROM Contributor
WHERE ContributorID = @ContributorID;

COMMIT TRANSACTION;
