-- Create triggers
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
