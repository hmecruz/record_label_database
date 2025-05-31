CREATE OR ALTER PROCEDURE dbo.sp_GetCollaborations
    @Name         VARCHAR(255) = NULL,
    @Start        DATE         = NULL,
    @End          DATE         = NULL,
    @Song         VARCHAR(255) = NULL,
    @Label        VARCHAR(255) = NULL,
    @Contributor  VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Collaborations
    WHERE (@Name        IS NULL OR CollaborationName LIKE '%' + @Name        + '%')
      AND (@Start       IS NULL OR StartDate         = @Start)
      AND (@End         IS NULL OR EndDate           = @End)
      AND (@Song        IS NULL OR SongTitle         LIKE '%' + @Song        + '%')
      AND (@Label       IS NULL OR RecordLabels      LIKE '%' + @Label       + '%')
      AND (@Contributor IS NULL OR Contributors     LIKE '%' + @Contributor + '%');
END
GO

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

-- CreateCollaboration: inserts into Collaboration and association tables
CREATE OR ALTER PROCEDURE dbo.sp_CreateCollaboration
    @CollaborationName VARCHAR(255),
    @StartDate         DATE,
    @EndDate           DATE         = NULL,
    @Description       TEXT         = NULL,
    @SongTitle         VARCHAR(255) = NULL,  -- we'll look up SongID
    @RecordLabels      VARCHAR(MAX) = NULL,  -- comma-separated names
    @Contributors      VARCHAR(MAX) = NULL,  -- comma-separated IDs or names
    @NewID             INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @songID INT = NULL;
        IF @SongTitle IS NOT NULL
            SELECT TOP 1 @songID = SongID FROM dbo.Song WHERE Title = @SongTitle;

        INSERT INTO dbo.Collaboration
          (CollaborationName, StartDate, EndDate, Description, Song_SongID)
        VALUES
          (@CollaborationName, @StartDate, @EndDate, @Description, @songID);

        SET @NewID = SCOPE_IDENTITY();

        -- handle RecordLabels
        IF @RecordLabels IS NOT NULL
        BEGIN
            DECLARE @lbl NVARCHAR(255);
            DECLARE lbl_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@RecordLabels, ',');
            OPEN lbl_cur;
            FETCH NEXT FROM lbl_cur INTO @lbl;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.RecordLabel_Collaboration
                  (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID)
                SELECT @NewID, RecordLabelID, @NewID
                FROM dbo.RecordLabel
                WHERE Name = @lbl;
                FETCH NEXT FROM lbl_cur INTO @lbl;
            END
            CLOSE lbl_cur; DEALLOCATE lbl_cur;
        END

        -- handle Contributors
        IF @Contributors IS NOT NULL
        BEGIN
            DECLARE @con NVARCHAR(255);
            DECLARE con_cur CURSOR FOR
              SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Contributors, ',');
            OPEN con_cur;
            FETCH NEXT FROM con_cur INTO @con;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Collaboration_Contributor
                  (Collaboration_CollaborationID, Contributor_ContributorID)
                SELECT @NewID, ContributorID
                FROM dbo.Contributor co
                JOIN dbo.Person p ON p.NIF = co.Person_NIF
                WHERE p.Name = @con;
                FETCH NEXT FROM con_cur INTO @con;
            END
            CLOSE con_cur; DEALLOCATE con_cur;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_UpdateCollaboration
    @ID                INT,
    @CollaborationName VARCHAR(255),
    @StartDate         DATE,
    @EndDate           DATE         = NULL,
    @Description       TEXT         = NULL,
    @SongTitle         VARCHAR(255) = NULL,
    @RecordLabels      VARCHAR(MAX) = NULL,
    @Contributors      VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @songID INT = NULL;
        IF @SongTitle IS NOT NULL
            SELECT TOP 1 @songID = SongID FROM dbo.Song WHERE Title = @SongTitle;

        UPDATE dbo.Collaboration
        SET
          CollaborationName = @CollaborationName,
          StartDate         = @StartDate,
          EndDate           = @EndDate,
          Description       = @Description,
          Song_SongID       = @songID
        WHERE CollaborationID = @ID;

        IF @@ROWCOUNT = 0
            THROW 50030, 'Collaboration not found', 1;

        -- refresh the two association tables
        DELETE FROM dbo.RecordLabel_Collaboration
         WHERE Collaboration_CollaborationID = @ID;
        DELETE FROM dbo.Collaboration_Contributor
         WHERE Collaboration_CollaborationID = @ID;

        -- re-insert labels & contributors as above
        -- [same logic as CREATE, or refactor into shared table function]

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_DeleteCollaboration
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Collaboration WHERE CollaborationID = @ID;
    IF @@ROWCOUNT = 0
        THROW 50031, 'Collaboration not found', 1;
END
GO
