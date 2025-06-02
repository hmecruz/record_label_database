-- File: database/stored_procedures/collaboration_sp.sql

-- ================================================
-- sp_GetCollaborations: Fetch collaborations with optional filters
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetCollaborations
    @Name        VARCHAR(255) = NULL,
    @Start       DATE         = NULL,
    @End         DATE         = NULL,
    @Song        VARCHAR(255) = NULL,    -- still matches against vw_Collaborations.SongTitle
    @Label       VARCHAR(255) = NULL,
    @Contributor VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Collaborations
    WHERE (@Name        IS NULL OR CollaborationName LIKE '%' + @Name + '%')
      AND (@Start       IS NULL OR StartDate         = @Start)
      AND (@End         IS NULL OR EndDate           = @End)
      AND (@Song        IS NULL OR SongTitle         LIKE '%' + @Song + '%')
      AND (@Label       IS NULL OR RecordLabels      LIKE '%' + @Label + '%')
      AND (@Contributor IS NULL OR Contributors     LIKE '%' + @Contributor + '%');
END
GO

-- ================================================
-- sp_GetCollaborationByID: Fetch a single collaboration
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetCollaborationByID
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Collaborations
    WHERE CollaborationID = @ID;
END
GO

-- ================================================
-- sp_CreateCollaboration:
--   Inserts into Collaboration and its association tables.
--   Now takes @SongID directly (INT), rather than @SongTitle.
--   @RecordLabels = comma-separated list of RecordLabel names.
--   @Contributors  = comma-separated list of Person_NIFs.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_CreateCollaboration
    @CollaborationName VARCHAR(255),
    @StartDate         DATE,
    @EndDate           DATE         = NULL,
    @Description       TEXT         = NULL,
    @SongID            INT          = NULL,   -- direct FK to Song.SongID
    @RecordLabels      VARCHAR(MAX) = NULL,   -- comma-separated list of RecordLabel names
    @Contributors      VARCHAR(MAX) = NULL,   -- comma-separated list of Person_NIFs
    @NewID             INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Insert the Collaboration row, using @SongID directly
        INSERT INTO dbo.Collaboration
            (CollaborationName, StartDate, EndDate, Description, Song_SongID)
        VALUES
            (@CollaborationName, @StartDate, @EndDate, @Description, @SongID);

        SET @NewID = SCOPE_IDENTITY();

        -- 2) Handle RecordLabels (if any)
        IF @RecordLabels IS NOT NULL
        BEGIN
            DECLARE @lbl NVARCHAR(255);
            DECLARE lbl_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) 
              FROM STRING_SPLIT(@RecordLabels, ',');
            OPEN lbl_cur;
            FETCH NEXT FROM lbl_cur INTO @lbl;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- We need two different FKs in RecordLabel_Collaboration.
                -- Convention: use the newly‐created @NewID for both sides if you want a single link;
                -- otherwise, adapt to your specific logic. Here we assume both sides equal @NewID for a simple link:
                INSERT INTO dbo.RecordLabel_Collaboration
                    (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID)
                SELECT rl.RecordLabelID, rl.RecordLabelID, @NewID
                FROM dbo.RecordLabel rl
                WHERE rl.Name = @lbl;

                FETCH NEXT FROM lbl_cur INTO @lbl;
            END
            CLOSE lbl_cur;  
            DEALLOCATE lbl_cur;
        END

        -- 3) Handle Contributors (if any)
        IF @Contributors IS NOT NULL
        BEGIN
            DECLARE @con NVARCHAR(255);
            DECLARE con_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value))
              FROM STRING_SPLIT(@Contributors, ',');
            OPEN con_cur;
            FETCH NEXT FROM con_cur INTO @con;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                -- Lookup the ContributorID by Person_NIF = @con
                INSERT INTO dbo.Collaboration_Contributor
                    (Collaboration_CollaborationID, Contributor_ContributorID)
                SELECT @NewID, co.ContributorID
                FROM dbo.Contributor co
                JOIN dbo.Person p ON p.NIF = co.Person_NIF
                WHERE p.NIF = @con;

                FETCH NEXT FROM con_cur INTO @con;
            END
            CLOSE con_cur;  
            DEALLOCATE con_cur;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the original error
    END CATCH
END
GO

-- ================================================
-- sp_UpdateCollaboration:
--   Updates an existing collaboration (and re‐writes its associations).
--   Now takes @SongID (INT) instead of @SongTitle.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateCollaboration
    @ID                INT,
    @CollaborationName VARCHAR(255),
    @StartDate         DATE,
    @EndDate           DATE         = NULL,
    @Description       TEXT         = NULL,
    @SongID            INT          = NULL,   -- direct FK to Song.SongID
    @RecordLabels      VARCHAR(MAX) = NULL,   -- comma-separated list of RecordLabel names
    @Contributors      VARCHAR(MAX) = NULL    -- comma-separated list of Person_NIFs
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Update the Collaboration row itself
        UPDATE dbo.Collaboration
        SET
          CollaborationName = @CollaborationName,
          StartDate         = @StartDate,
          EndDate           = @EndDate,
          Description       = @Description,
          Song_SongID       = @SongID
        WHERE CollaborationID = @ID;

        IF @@ROWCOUNT = 0
            THROW 50030, 'Collaboration not found', 1;

        -- 2) Delete existing RecordLabel links
        DELETE FROM dbo.RecordLabel_Collaboration
         WHERE Collaboration_CollaborationID = @ID;

        -- 3) Delete existing Contributor links
        DELETE FROM dbo.Collaboration_Contributor
         WHERE Collaboration_CollaborationID = @ID;

        -- 4) Re‐insert RecordLabels (same logic as CREATE)
        IF @RecordLabels IS NOT NULL
        BEGIN
            DECLARE @lbl2 NVARCHAR(255);
            DECLARE lbl2_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) 
              FROM STRING_SPLIT(@RecordLabels, ',');
            OPEN lbl2_cur;
            FETCH NEXT FROM lbl2_cur INTO @lbl2;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.RecordLabel_Collaboration
                    (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID)
                SELECT rl.RecordLabelID, rl.RecordLabelID, @ID
                FROM dbo.RecordLabel rl
                WHERE rl.Name = @lbl2;

                FETCH NEXT FROM lbl2_cur INTO @lbl2;
            END
            CLOSE lbl2_cur;  
            DEALLOCATE lbl2_cur;
        END

        -- 5) Re‐insert Contributors (same logic as CREATE)
        IF @Contributors IS NOT NULL
        BEGIN
            DECLARE @con2 NVARCHAR(255);
            DECLARE con2_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) 
              FROM STRING_SPLIT(@Contributors, ',');
            OPEN con2_cur;
            FETCH NEXT FROM con2_cur INTO @con2;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Collaboration_Contributor
                   (Collaboration_CollaborationID, Contributor_ContributorID)
                SELECT @ID, co.ContributorID
                FROM dbo.Contributor co
                JOIN dbo.Person p ON p.NIF = co.Person_NIF
                WHERE p.NIF = @con2;

                FETCH NEXT FROM con2_cur INTO @con2;
            END
            CLOSE con2_cur;  
            DEALLOCATE con2_cur;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ================================================
-- sp_DeleteCollaboration: delete one collaboration
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteCollaboration
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Collaboration
    WHERE CollaborationID = @ID;

    IF @@ROWCOUNT = 0
        THROW 50031, 'Collaboration not found', 1;
END
GO
