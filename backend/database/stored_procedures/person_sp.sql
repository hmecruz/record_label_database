-- ================================================
-- sp_GetPersonByNIF: Helper to fetch Person (& any ContributorID) by NIF
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetPersonByNIF
    @NIF VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.NIF,
        p.Name,
        p.DateOfBirth,
        p.Email,
        p.PhoneNumber,
        c.ContributorID
    FROM dbo.Person p
    LEFT JOIN dbo.Contributor c
      ON c.Person_NIF = p.NIF
    WHERE p.NIF = @NIF;
END
GO

-- ================================================
-- sp_UpdatePerson: Update a Person’s basic fields by NIF
-- Note: we use THROW 51010 if no row was updated.
-- ================================================
CREATE OR ALTER PROCEDURE dbo.sp_UpdatePerson
    @NIF         VARCHAR(20),
    @Name        VARCHAR(255),
    @DateOfBirth DATE           = NULL,
    @Email       VARCHAR(255)   = NULL,
    @PhoneNumber VARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.Person
    SET
      Name        = @Name,
      DateOfBirth = @DateOfBirth,
      Email       = @Email,
      PhoneNumber = @PhoneNumber
    WHERE NIF = @NIF;

    IF @@ROWCOUNT = 0
        THROW 51010, 'Person not found', 1;
END
GO
