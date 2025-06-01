-------------------------------------------------------------------------------
-- triggers.sql
--
-- (1) Whenever someone inserts or deletes a row from Collaboration_Contributor,
--     check each affected CollaborationID.  If it now has fewer than 2 contributors,
--     delete that Collaboration (which cascades to its child rows).
--
-- (2) Whenever someone deletes a row from Contributor_Song,
--     check the affected SongID.  If it now has zero contributors,
--     delete that Song (which cascades to its child rows).
-------------------------------------------------------------------------------

-- ================================================
-- (1) Maintain Collaboration → delete if fewer than 2 contributors remain
-- ================================================
CREATE OR ALTER TRIGGER dbo.trg_CollabContributor_Maintenance
ON dbo.Collaboration_Contributor
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @collabIDs TABLE (CollaborationID INT);

    -- 1a) Gather every CollaborationID that was either inserted or deleted
    INSERT INTO @collabIDs
    SELECT DISTINCT Collaboration_CollaborationID
    FROM (
        SELECT Collaboration_CollaborationID FROM deleted
        UNION ALL
        SELECT Collaboration_CollaborationID FROM inserted
    ) AS touch_list
    WHERE Collaboration_CollaborationID IS NOT NULL;

    -- 1b) For each affected collaboration, count its remaining contributors.
    DECLARE @cid INT;
    DECLARE cur CURSOR FOR
        SELECT CollaborationID FROM @collabIDs;
    OPEN cur;
    FETCH NEXT FROM cur INTO @cid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @cnt INT;
        SELECT @cnt = COUNT(*)
        FROM dbo.Collaboration_Contributor
        WHERE Collaboration_CollaborationID = @cid;

        IF @cnt < 2
        BEGIN
            -- Delete the “under‐staffed” collaboration.
            DELETE FROM dbo.Collaboration
            WHERE CollaborationID = @cid;
            -- ON DELETE CASCADE will clean up its Collaboration_Contributor / RecordLabel_Collaboration, etc.
        END

        FETCH NEXT FROM cur INTO @cid;
    END
    CLOSE cur;
    DEALLOCATE cur;
END
GO

-- ================================================
-- (2) Maintain Song → delete if zero contributors remain
-- ================================================
CREATE OR ALTER TRIGGER dbo.trg_ContributorSong_Maintenance
ON dbo.Contributor_Song
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @songIDs TABLE (SongID INT);

    -- 2a) Gather any SongID that just lost a Contributor_Song row
    INSERT INTO @songIDs
    SELECT DISTINCT Song_SongID
    FROM deleted
    WHERE Song_SongID IS NOT NULL;

    -- 2b) For each affected song, count remaining contributors.
    DECLARE @sid INT;
    DECLARE cur2 CURSOR FOR
        SELECT SongID FROM @songIDs;
    OPEN cur2;
    FETCH NEXT FROM cur2 INTO @sid;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @cnt2 INT;
        SELECT @cnt2 = COUNT(*)
        FROM dbo.Contributor_Song
        WHERE Song_SongID = @sid;

        IF @cnt2 = 0
        BEGIN
            -- Delete the “orphan” song.
            DELETE FROM dbo.Song
            WHERE SongID = @sid;
            -- ON DELETE CASCADE will clean up Song_Genre, and any Collaboration referencing this Song.
        END

        FETCH NEXT FROM cur2 INTO @sid;
    END
    CLOSE cur2;
    DEALLOCATE cur2;
END
GO
