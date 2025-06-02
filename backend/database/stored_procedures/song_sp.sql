-- ================================================================
-- sp_GetSongs: Retrieve songs based on various filters
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetSongs
    @Title         VARCHAR(255) = NULL,
    @MinDuration   INT           = NULL,
    @MaxDuration   INT           = NULL,
    @ReleaseDate   DATE          = NULL,
    @Genre         VARCHAR(50)   = NULL,
    @Contributor   VARCHAR(255)  = NULL,
    @Collaboration VARCHAR(255)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_Songs
    WHERE (@Title         IS NULL OR Title           LIKE '%' + @Title         + '%')
      AND (@MinDuration   IS NULL OR Duration        >= @MinDuration)
      AND (@MaxDuration   IS NULL OR Duration        <= @MaxDuration)
      AND (@ReleaseDate   IS NULL OR ReleaseDate     = @ReleaseDate)
      AND (@Genre         IS NULL OR Genres          LIKE '%' + @Genre         + '%')
      AND (@Contributor   IS NULL OR Contributors    LIKE '%' + @Contributor   + '%')
      AND (@Collaboration IS NULL OR CollaborationName LIKE '%' + @Collaboration + '%');
END
GO


-- ================================================================
-- sp_GetSongByID: Retrieve a specific song by its ID
-- ================================================================
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


-- ================================================================
-- sp_GetSongDependencies:
--   Returns counts of “child” rows that reference this song:
--     • Collaboration rows
--     • Contributor_Song rows
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetSongDependencies
    @SongID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @collabCount      INT;
    DECLARE @contribSongCount INT;

    SELECT @collabCount = COUNT(*)
      FROM dbo.Collaboration
     WHERE Song_SongID = @SongID;

    SELECT @contribSongCount = COUNT(*)
      FROM dbo.Contributor_Song
     WHERE Song_SongID = @SongID;

    SELECT
        @collabCount      AS CollaborationCount,
        @contribSongCount AS ContributorCount;
END
GO


-- ================================================================
-- sp_CreateSong: Insert a new song with genres and contributors
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CreateSong
    @Title        VARCHAR(255),
    @Duration     INT,
    @ReleaseDate  DATE                = NULL,
    @Genres       VARCHAR(MAX)        = NULL,  -- comma-separated list
    @Contributors VARCHAR(MAX)        = NULL,  -- comma-separated list of Person_NIFs
    @NewID        INT                 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Insert into Song
        INSERT INTO dbo.Song (Title, Duration, ReleaseDate)
        VALUES (@Title, @Duration, @ReleaseDate);

        SET @NewID = SCOPE_IDENTITY();

        -- 2) Insert genres (if any)
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
            CLOSE curG; 
            DEALLOCATE curG;
        END

        -- 3) Insert contributors (if any)
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
                FROM dbo.Contributor AS c
                WHERE c.Person_NIF = @nif;
                FETCH NEXT FROM curC INTO @nif;
            END
            CLOSE curC; 
            DEALLOCATE curC;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the caught error
    END CATCH
END
GO


-- ================================================================
-- sp_UpdateSong: Update an existing song, its genres, and contributors
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdateSong
    @ID           INT,
    @Title        VARCHAR(255),
    @Duration     INT,
    @ReleaseDate  DATE                = NULL,
    @Genres       VARCHAR(MAX)        = NULL,  -- comma-separated list
    @Contributors VARCHAR(MAX)        = NULL   -- comma-separated list of Person_NIFs
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Update the Song row
        UPDATE dbo.Song
        SET Title       = @Title,
            Duration    = @Duration,
            ReleaseDate = @ReleaseDate
        WHERE SongID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK;
            RAISERROR('Song not found', 16, 1);
            RETURN;
        END

        -- 2) Refresh genres
        DELETE FROM dbo.Song_Genre
        WHERE Song_SongID = @ID;

        IF @Genres IS NOT NULL
        BEGIN
            DECLARE @g2 VARCHAR(50);
            DECLARE curG2 CURSOR FOR
              SELECT LTRIM(RTRIM(value))
              FROM STRING_SPLIT(@Genres, ',');
            OPEN curG2;
            FETCH NEXT FROM curG2 INTO @g2;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Song_Genre (Song_SongID, Genre)
                VALUES (@ID, @g2);
                FETCH NEXT FROM curG2 INTO @g2;
            END
            CLOSE curG2; 
            DEALLOCATE curG2;
        END

        -- 3) Refresh contributors
        DELETE FROM dbo.Contributor_Song
        WHERE Song_SongID = @ID;

        IF @Contributors IS NOT NULL
        BEGIN
            DECLARE @nif2 VARCHAR(20);
            DECLARE curC2 CURSOR FOR
              SELECT LTRIM(RTRIM(value))
              FROM STRING_SPLIT(@Contributors, ',');
            OPEN curC2;
            FETCH NEXT FROM curC2 INTO @nif2;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                INSERT INTO dbo.Contributor_Song (Contributor_ContributorID, Song_SongID, Date)
                SELECT c.ContributorID, @ID, GETDATE()
                FROM dbo.Contributor AS c
                WHERE c.Person_NIF = @nif2;
                FETCH NEXT FROM curC2 INTO @nif2;
            END
            CLOSE curC2; 
            DEALLOCATE curC2;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO


-- ================================================================
-- sp_DeleteSong: Deletes a song by its ID.
--   First deletes any Collaboration referencing this song,
--   then deletes the Song itself.
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteSong
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- 1) Remove any Collaboration rows pointing to this song
        DELETE FROM dbo.Collaboration
        WHERE Song_SongID = @ID;

        -- 2) Delete the song itself
        DELETE FROM dbo.Song
        WHERE SongID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK;
            RAISERROR('Song not found', 16, 1);
            RETURN;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the original error
    END CATCH
END
GO
