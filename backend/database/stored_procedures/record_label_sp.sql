-- GetRecordLabels: Retrieves record labels based on optional search criteria.
CREATE OR ALTER PROCEDURE dbo.sp_GetRecordLabels
    @Name      VARCHAR(255) = NULL,
    @Location  VARCHAR(255) = NULL,
    @Website   VARCHAR(255) = NULL,
    @Email     VARCHAR(255) = NULL,
    @Phone     VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_RecordLabels
    WHERE (@Name     IS NULL OR Name     LIKE '%' + @Name     + '%')
      AND (@Location IS NULL OR Location LIKE '%' + @Location + '%')
      AND (@Website  IS NULL OR Website  LIKE '%' + @Website  + '%')
      AND (@Email    IS NULL OR Email    LIKE '%' + @Email    + '%')
      AND (@Phone    IS NULL OR PhoneNumber LIKE '%' + @Phone + '%');
END
GO


-- GetRecordLabelByID: Retrieves a specific record label by its ID.
CREATE OR ALTER PROCEDURE dbo.sp_GetRecordLabelByID
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_RecordLabels
    WHERE RecordLabelID = @ID;
END
GO


-- CreateRecordLabel: Inserts a new record label and returns its ID.
CREATE OR ALTER PROCEDURE dbo.sp_CreateRecordLabel
    @Name        VARCHAR(255),
    @Location    VARCHAR(255)   = NULL,
    @Website     VARCHAR(255)   = NULL,
    @Email       VARCHAR(255),
    @PhoneNumber VARCHAR(50),
    @NewID       INT            OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.RecordLabel (Name, Location, Website, Email, PhoneNumber)
    VALUES (@Name, @Location, @Website, @Email, @PhoneNumber);

    SET @NewID = SCOPE_IDENTITY();
END
GO


-- UpdateRecordLabel: Updates an existing record label by its ID.
CREATE OR ALTER PROCEDURE dbo.sp_UpdateRecordLabel
    @ID          INT,
    @Name        VARCHAR(255),
    @Location    VARCHAR(255) = NULL,
    @Website     VARCHAR(255) = NULL,
    @Email       VARCHAR(255),
    @PhoneNumber VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.RecordLabel
    SET
      Name        = @Name,
      Location    = @Location,
      Website     = @Website,
      Email       = @Email,
      PhoneNumber = @PhoneNumber
    WHERE RecordLabelID = @ID;

    IF @@ROWCOUNT = 0
        THROW 50000, 'RecordLabel not found', 1;
END
GO


-- DeleteRecordLabel: Deletes a record label by its ID.
CREATE OR ALTER PROCEDURE dbo.sp_DeleteRecordLabel
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM dbo.RecordLabel
    WHERE RecordLabelID = @ID;

    IF @@ROWCOUNT = 0
        THROW 50001, 'RecordLabel not found', 1;
END
GO

-- ================================================================
-- sp_CheckRecordLabelDependencies:
--   Given a RecordLabelID, returns:
--     @EmployeeCount       = number of employees referencing this label,
--     @CollaborationCount  = number of collaboration‐label links for this label.
--   Throws if the label ID does not exist.
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_CheckRecordLabelDependencies
    @ID                    INT,
    @EmployeeCount         INT OUTPUT,
    @CollaborationCount    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- First, ensure the RecordLabel exists
    IF NOT EXISTS (SELECT 1 FROM dbo.RecordLabel WHERE RecordLabelID = @ID)
    BEGIN
        THROW 50050, 'RecordLabel not found', 1;
    END

    -- Now query the view
    SELECT
        @EmployeeCount      = rd.EmployeeCount,
        @CollaborationCount = rd.CollaborationCount
    FROM dbo.vw_RecordLabelDependencies rd
    WHERE rd.RecordLabelID = @ID;
END
GO


-- ================================================================
-- sp_DeleteRecordLabel_Cascade:
--   1) Deletes all Employees whose RecordLabel_RecordLabelID = @ID.
--   2) Deletes all RecordLabel_Collaboration rows where either side = @ID.
--   3) Deletes the RecordLabel itself.
-- ================================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteRecordLabel_Cascade
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) Remove employees for this label
        -------------------------------------------------------------
        -- a) First, collect the NIFs of persons who will be deleted:
        DECLARE @toDeleteNIF TABLE (NIF VARCHAR(20));
        INSERT INTO @toDeleteNIF (NIF)
        SELECT e.Person_NIF
        FROM dbo.Employee e
        WHERE e.RecordLabel_RecordLabelID = @ID;

        -- b) Delete Employee rows
        DELETE FROM dbo.Employee
        WHERE RecordLabel_RecordLabelID = @ID;

        -- c) Delete Person rows if they are not in Employee or Contributor (or any other table that needs them)    
        DELETE p
        FROM dbo.Person p
        WHERE p.NIF IN (
            SELECT NIF
            FROM @toDeleteNIF
        )
        AND NOT EXISTS (SELECT 1 FROM dbo.Employee    WHERE Person_NIF = p.NIF)
        AND NOT EXISTS (SELECT 1 FROM dbo.Contributor WHERE Person_NIF = p.NIF);
        
        -------------------------------------------------------------

        -- 2) Remove any collaboration‐label links involving @ID
        DELETE FROM dbo.RecordLabel_Collaboration
        WHERE RecordLabel_RecordLabelID1 = @ID
           OR RecordLabel_RecordLabelID2 = @ID;

        -- 3) Finally, delete the label itself
        DELETE FROM dbo.RecordLabel
        WHERE RecordLabelID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            -- If no rows deleted, either the label didn't exist or someone else removed it concurrently
            THROW 50001, 'RecordLabel not found (or already deleted)', 1;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;  -- rethrow the original error
    END CATCH
END
GO