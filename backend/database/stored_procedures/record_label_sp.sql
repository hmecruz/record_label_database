-- ================================================
-- sp_GetRecordLabels
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetRecordLabels
    @Name        VARCHAR(255) = NULL,
    @Location    VARCHAR(255) = NULL,
    @Website     VARCHAR(255) = NULL,
    @Email       VARCHAR(255) = NULL,
    @Phone       VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM dbo.vw_RecordLabels
    WHERE (@Name     IS NULL OR Name        LIKE '%' + @Name     + '%')
      AND (@Location IS NULL OR Location    LIKE '%' + @Location + '%')
      AND (@Website  IS NULL OR Website     LIKE '%' + @Website  + '%')
      AND (@Email    IS NULL OR Email       LIKE '%' + @Email    + '%')
      AND (@Phone    IS NULL OR PhoneNumber LIKE '%' + @Phone    + '%');
END
GO


-- ================================================
-- sp_GetRecordLabelByID
-- ================================================
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


-- ================================================
-- sp_CreateRecordLabel
-- ================================================
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


-- ================================================
-- sp_UpdateRecordLabel
-- ================================================
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


-- ================================================
-- sp_DeleteRecordLabel (simple)
-- ================================================
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


-- ================================================
-- sp_CheckRecordLabelDependencies
--   Checks how many employees and collaboration‐links
--   exist for this label. Throws if the label does not exist.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_CheckRecordLabelDependencies
    @ID                    INT,
    @EmployeeCount         INT OUTPUT,
    @CollaborationCount    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Ensure the RecordLabel exists
    IF NOT EXISTS (SELECT 1 FROM dbo.RecordLabel WHERE RecordLabelID = @ID)
    BEGIN
        THROW 50050, 'RecordLabel not found', 1;
    END
    -- counts employees & collaborations per label:
    --    vw_RecordLabelDependencies
    -- Columns: RecordLabelID, EmployeeCount, CollaborationCount
    SELECT
        @EmployeeCount      = rd.EmployeeCount,
        @CollaborationCount = rd.CollaborationCount
    FROM dbo.vw_RecordLabelDependencies rd
    WHERE rd.RecordLabelID = @ID;
END
GO


-- ================================================
-- sp_DeleteRecordLabel_Cascade
--   1) Delete Employee rows (and their Person if orphaned)
--   2) Delete Collaboration rows that reference this label
--   3) Delete any leftover RecordLabel_Collaboration links
--   4) Delete the RecordLabel itself
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_DeleteRecordLabel_Cascade
    @ID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------------
        -- 1) Delete all Employees tied to this label, cleanup Persons
        -------------------------------------------------------------
        DECLARE @toDeleteNIF TABLE (NIF VARCHAR(20));

        -- Collect NIFs of Persons whose employee record we will delete
        INSERT INTO @toDeleteNIF (NIF)
        SELECT e.Person_NIF
        FROM dbo.Employee e
        WHERE e.RecordLabel_RecordLabelID = @ID;

        -- Delete those Employee rows
        DELETE FROM dbo.Employee
        WHERE RecordLabel_RecordLabelID = @ID;

        -- Delete Person rows if no longer used in Employee or Contributor
        DELETE p
        FROM dbo.Person p
        WHERE p.NIF IN (SELECT NIF FROM @toDeleteNIF)
          AND NOT EXISTS (SELECT 1 FROM dbo.Employee    WHERE Person_NIF = p.NIF)
          AND NOT EXISTS (SELECT 1 FROM dbo.Contributor WHERE Person_NIF = p.NIF);

        -------------------------------------------------------------
        -- 2) Delete all Collaboration rows that reference this label
        -------------------------------------------------------------
        DELETE coll
        FROM dbo.Collaboration coll
        JOIN dbo.RecordLabel_Collaboration rlc
          ON coll.CollaborationID = rlc.Collaboration_CollaborationID
        WHERE rlc.RecordLabel_RecordLabelID1 = @ID
           OR rlc.RecordLabel_RecordLabelID2 = @ID;
        -- Deleting Collaboration automatically cascades to Collaboration_Contributor
        -- (because FK Collaboration_Contributor → Collaboration is ON DELETE CASCADE).
        -- It also cascades the rlc rows (because FK rlc→Collaboration is ON DELETE CASCADE).

        -------------------------------------------------------------
        -- 3) Remove any leftover RecordLabel_Collaboration links involving @ID
        -------------------------------------------------------------
        DELETE FROM dbo.RecordLabel_Collaboration
        WHERE RecordLabel_RecordLabelID1 = @ID
           OR RecordLabel_RecordLabelID2 = @ID;
        -- (At this point, any rows that pointed to the deleted collaboration are already gone,
        --  but if a collaboration had two labels, and only one matched @ID, the remaining RLC rows
        --  that pointed to the other label still exist—so we explicitly remove any row where either
        --  side = @ID.)

        -------------------------------------------------------------
        -- 4) Finally, delete the RecordLabel itself
        -------------------------------------------------------------
        DELETE FROM dbo.RecordLabel
        WHERE RecordLabelID = @ID;

        IF @@ROWCOUNT = 0
        BEGIN
            -- If nobody got deleted, either the label didn't exist or was removed concurrently
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