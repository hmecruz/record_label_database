-- Create triggers

-- =============================================================================
-- When a Contributor is deleted, also delete its linked Song if it has no contributors.
-- =============================================================================
CREATE TRIGGER trg_DeleteSongWithNoContributors
ON Contributor_Song
AFTER DELETE, INSERT
AS
BEGIN
    DELETE FROM Song
    WHERE SongID IN (
        SELECT s.SongID
        FROM Song s
        LEFT JOIN Contributor_Song cs ON s.SongID = cs.Song_SongID
        GROUP BY s.SongID
        HAVING COUNT(cs.Contributor_ContributorID) = 0
    );
END;
GO

-- =============================================================================
-- When a Collaboration_Contributor is deleted or inserted, delete the Collaboration
-- if it has fewer than 2 contributors.
-- =============================================================================
CREATE TRIGGER trg_DeleteCollaborationWithFewContributors
ON Collaboration_Contributor
AFTER DELETE, INSERT
AS
BEGIN
    -- Delete collaborations with fewer than 2 contributors
    DELETE FROM Collaboration
    WHERE CollaborationID IN (
        SELECT c.CollaborationID
        FROM Collaboration c
        LEFT JOIN Collaboration_Contributor cc ON c.CollaborationID = cc.Collaboration_CollaborationID
        GROUP BY c.CollaborationID
        HAVING COUNT(cc.Contributor_ContributorID) < 2
    );
END;
GO

-- =============================================================================
-- Delete Collaboration if it has fewer than 2 distinct Record Labels
-- =============================================================================
CREATE OR ALTER TRIGGER trg_DeleteCollaborationWithFewLabels
ON RecordLabel_Collaboration
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Count DISTINCT labels by unpivoting both columns
    DELETE FROM Collaboration
    WHERE CollaborationID IN (
        SELECT rc.Collaboration_CollaborationID
        FROM (
            SELECT Collaboration_CollaborationID, RecordLabel_RecordLabelID1 AS LabelID
            FROM RecordLabel_Collaboration
            UNION
            SELECT Collaboration_CollaborationID, RecordLabel_RecordLabelID2 AS LabelID
            FROM RecordLabel_Collaboration
        ) AS rc
        GROUP BY rc.Collaboration_CollaborationID
        HAVING COUNT(DISTINCT rc.LabelID) < 2
    );
END;
GO
