-- GetSongs: Retrieve songs based on various filters
CREATE OR ALTER PROCEDURE dbo.sp_GetSongs
    @Title            VARCHAR(255) = NULL,
    @MinDuration      INT           = NULL,
    @MaxDuration      INT           = NULL,
    @ReleaseDate      DATE          = NULL,
    @Genre            VARCHAR(50)   = NULL,
    @Contributor      VARCHAR(255)  = NULL,
    @Collaboration    VARCHAR(255)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Songs
    WHERE (@Title         IS NULL OR Title         LIKE '%' + @Title       + '%')
      AND (@MinDuration   IS NULL OR Duration      >= @MinDuration)
      AND (@MaxDuration   IS NULL OR Duration      <= @MaxDuration)
      AND (@ReleaseDate   IS NULL OR ReleaseDate   = @ReleaseDate)
      AND (@Genre         IS NULL OR Genres        LIKE '%' + @Genre       + '%')
      AND (@Contributor   IS NULL OR Contributors  LIKE '%' + @Contributor + '%')
      AND (@Collaboration IS NULL OR CollaborationName LIKE '%' + @Collaboration + '%');
END
GO

-- GetSongByID: Retrieve a specific song by its ID
CREATE OR ALTER PROCEDURE dbo.sp_GetSongByID
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Songs
    WHERE SongID = @ID;
END
GO

-- CreateSong: Insert a new song with genres, contributors, and collaboration
CREATE OR ALTER PROCEDURE dbo.sp_CreateSong
    @Title             VARCHAR(255),
    @Duration          INT,
    @ReleaseDate       DATE,
    @Genres            VARCHAR(MAX)   = NULL,  -- comma-separated
    @Contributors      VARCHAR(MAX)   = NULL,  -- comma-separated NIFs
    @CollaborationName VARCHAR(255)   = NULL,
    @NewID             INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Insert Song
        INSERT INTO dbo.Song (Title, Duration, ReleaseDate)
        VALUES (@Title, @Duration, @ReleaseDate);
        SET @NewID = SCOPE_IDENTITY();

        -- 2) Insert Genres
        IF @Genres IS NOT NULL
        BEGIN
            DECLARE @g VARCHAR(50);
            DECLARE curG CURSOR FOR 
                SELECT LTRIM(RTRIM(value)) 
                FROM STRING_SPLIT(@Genres, ',');
            OPEN curG;
            FETCH NEXT FROM curG INTO @g;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Song_Genre (Song_SongID, Genre)
                VALUES (@NewID, @g);
                FETCH NEXT FROM curG INTO @g;
            END
            CLOSE curG; DEALLOCATE curG;
        END

        -- 3) Link Contributors
        IF @Contributors IS NOT NULL
        BEGIN
            DECLARE @nif VARCHAR(20);
            DECLARE curC CURSOR FOR 
                SELECT LTRIM(RTRIM(value)) 
                FROM STRING_SPLIT(@Contributors, ',');
            OPEN curC;
            FETCH NEXT FROM curC INTO @nif;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Contributor_Song (Contributor_ContributorID, Song_SongID, Date)
                SELECT c.ContributorID, @NewID, GETDATE()
                FROM dbo.Contributor c
                WHERE c.Person_NIF = @nif;
                FETCH NEXT FROM curC INTO @nif;
            END
            CLOSE curC; DEALLOCATE curC;
        END

        -- 4) Create Collaboration record linking to this song
        IF @CollaborationName IS NOT NULL
        BEGIN
            INSERT INTO dbo.Collaboration (CollaborationName, StartDate, Description, Song_SongID)
            VALUES (@CollaborationName, GETDATE(), NULL, @NewID);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        RAISERROR('Error creating song: %s', 16, 1, ERROR_MESSAGE());
    END CATCH
END
GO

-- UpdateSong: Update an existing song, its genres, contributors, and collaboration
CREATE OR ALTER PROCEDURE dbo.sp_UpdateSong
    @ID                INT,
    @Title             VARCHAR(255),
    @Duration          INT,
    @ReleaseDate       DATE,
    @Genres            VARCHAR(MAX)   = NULL,
    @Contributors      VARCHAR(MAX)   = NULL,
    @CollaborationName VARCHAR(255)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Update base Song
        UPDATE dbo.Song
        SET Title = @Title, Duration = @Duration, ReleaseDate = @ReleaseDate
        WHERE SongID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK; RAISERROR('Song not found',16,1); RETURN;
        END

        -- Refresh genres
        DELETE FROM dbo.Song_Genre WHERE Song_SongID = @ID;
        IF @Genres IS NOT NULL
            INSERT INTO dbo.Song_Genre (Song_SongID, Genre)
            SELECT @ID, LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Genres, ',');

        -- Refresh contributor links
        DELETE FROM dbo.Contributor_Song WHERE Song_SongID = @ID;
        IF @Contributors IS NOT NULL
            INSERT INTO dbo.Contributor_Song (Contributor_ContributorID, Song_SongID, Date)
            SELECT c.ContributorID, @ID, GETDATE()
            FROM STRING_SPLIT(@Contributors, ',') AS s
            JOIN dbo.Contributor c ON c.Person_NIF = LTRIM(RTRIM(s.value));

        -- Update / create collaboration
        IF EXISTS (SELECT 1 FROM dbo.Collaboration WHERE Song_SongID = @ID)
            UPDATE dbo.Collaboration
            SET CollaborationName = @CollaborationName
            WHERE Song_SongID = @ID;
        ELSE IF @CollaborationName IS NOT NULL
            INSERT INTO dbo.Collaboration (CollaborationName, StartDate, Song_SongID)
            VALUES (@CollaborationName, GETDATE(), @ID);

        COMMIT;
    END TRY
    BEGIN CATCH
        ROLLBACK;
        RAISERROR('Error updating song: %s',16,1,ERROR_MESSAGE());
    END CATCH
END
GO

-- DeleteSong: Deletes a song by its ID
CREATE OR ALTER PROCEDURE dbo.sp_DeleteSong
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.Song WHERE SongID = @ID;
    IF @@ROWCOUNT = 0
        RAISERROR('Song not found',16,1);
END
GO
