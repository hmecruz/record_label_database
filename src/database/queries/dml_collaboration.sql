-- =========================
-- Manage Collaborations - DML Queries
-- =========================

-- ===== SELECT Queries =====

-- List all collaborations and their contributors (members)
SELECT c.CollaborationID, c.CollaborationName, c.StartDate, c.EndDate, c.Description,
       contrib.ContributorID, p.Name AS ContributorName
FROM Collaboration c
LEFT JOIN Collaboration_Contributor cc ON c.CollaborationID = cc.Collaboration_CollaborationID
LEFT JOIN Contributor contrib ON cc.Contributor_ContributorID = contrib.ContributorID
LEFT JOIN Person p ON contrib.Person_NIF = p.NIF
ORDER BY c.CollaborationID;

-- View collaborations linked to a specific SongID
SELECT *
FROM Collaboration
WHERE Song_SongID = 123;  -- Replace 123 with desired SongID

-- View collaborations linked to a specific RecordLabelID
SELECT DISTINCT c.*
FROM Collaboration c
JOIN RecordLabel_Collaboration rlc ON c.CollaborationID = rlc.Collaboration_CollaborationID
WHERE rlc.RecordLabel_RecordLabelID1 = 10  -- Replace 10 with RecordLabelID
   OR rlc.RecordLabel_RecordLabelID2 = 10;

-- ===== INSERT Queries =====

-- 1. Add a new collaboration
INSERT INTO Collaboration (CollaborationName, StartDate, EndDate, Description, Song_SongID)
VALUES ('New Collaboration', '2025-01-01', NULL, 'Description here', 123);
-- Ensure SongID 123 exists; if Song_SongID is optional, can be NULL

-- 2. Add contributors to the collaboration
-- Use actual CollaborationID obtained after insert if not using SCOPE_IDENTITY()
INSERT INTO Collaboration_Contributor (Collaboration_CollaborationID, Contributor_ContributorID)
VALUES (SCOPE_IDENTITY(), 5);  
-- Replace 5 with ContributorID(s)

-- 3. Link collaboration with record labels (optional)
INSERT INTO RecordLabel_Collaboration (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID)
VALUES (1, 2, SCOPE_IDENTITY());
-- Ensure RecordLabel_RecordLabelID1 <> RecordLabel_RecordLabelID2 and both IDs exist

-- ===== UPDATE Queries =====

-- Extend collaboration by updating EndDate
UPDATE Collaboration
SET EndDate = '2025-12-31'  -- New end date
WHERE CollaborationID = 1;   -- Collaboration to update

-- Remove a contributor from a collaboration
DELETE FROM Collaboration_Contributor
WHERE Collaboration_CollaborationID = 1
  AND Contributor_ContributorID = 2;

-- =========================
-- DELETE Queries with Referential Integrity Considerations
-- =========================

-- Since Collaboration_Contributor and RecordLabel_Collaboration have ON DELETE CASCADE on CollaborationID,
-- deleting from Collaboration will automatically delete related rows in those tables.

-- So you only need to delete the Collaboration row itself:

DELETE FROM Collaboration
WHERE CollaborationID = 1;

-- Optional: If you want to be explicit or DBMS does not support cascading deletes, delete associated rows first:

-- Delete contributors associated with the collaboration
DELETE FROM Collaboration_Contributor
WHERE Collaboration_CollaborationID = 1;

-- Delete record label collaborations associated with the collaboration
DELETE FROM RecordLabel_Collaboration
WHERE Collaboration_CollaborationID = 1;

-- Then delete the collaboration
DELETE FROM Collaboration
WHERE CollaborationID = 1;
