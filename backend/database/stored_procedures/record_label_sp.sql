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
    @PhoneNumber VARCHAR(50)    = NULL,
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
