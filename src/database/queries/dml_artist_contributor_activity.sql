-- =========================
-- Track Artist & Contributor Activities - DML Queries
-- =========================

-- ===== SELECT Queries =====

-- 1. View which artists are working on which songs
SELECT a.Contributor_ContributorID AS ArtistID,
       p.Name AS ArtistName,
       s.SongID,
       s.Title AS SongTitle
FROM Artist a
JOIN Contributor c ON a.Contributor_ContributorID = c.ContributorID
JOIN Contributor_Song cs ON c.ContributorID = cs.Contributor_ContributorID
JOIN Song s ON cs.Song_SongID = s.SongID
JOIN Person p ON c.Person_NIF = p.NIF
ORDER BY a.Contributor_ContributorID, s.SongID;
