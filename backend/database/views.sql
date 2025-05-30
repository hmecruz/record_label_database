-- Record Labels View
CREATE OR ALTER VIEW dbo.vw_RecordLabels
AS
SELECT
    RecordLabelID,
    Name,
    Location,
    Website,
    Email,
    PhoneNumber
FROM dbo.RecordLabel;
GO

-- Employees View
CREATE OR ALTER VIEW dbo.vw_Employees
AS
SELECT
    e.EmployeeID,
    e.Person_NIF           AS NIF,
    p.Name,
    p.DateOfBirth          AS DateOfBirth,
    e.JobTitle,
    e.Department,
    e.Salary,
    e.HireDate,
    p.Email,
    p.PhoneNumber,
    e.RecordLabel_RecordLabelID AS RecordLabelID,
    rl.Name                AS RecordLabelName
FROM dbo.Employee e
JOIN dbo.Person    p  ON p.NIF = e.Person_NIF
JOIN dbo.RecordLabel rl ON rl.RecordLabelID = e.RecordLabel_RecordLabelID;
GO

-- Songs View
GO
CREATE OR ALTER VIEW dbo.vw_Songs
AS
SELECT
    s.SongID,
    s.Title,
    s.Duration,
    s.ReleaseDate,
    -- aggregate genres as comma-separated
    COALESCE(g.Genres, '')          AS Genres,
    COALESCE(c.Contributors, '')    AS Contributors,
    col.CollaborationName           AS CollaborationName
FROM dbo.Song s
-- genres
OUTER APPLY (
    SELECT STRING_AGG(Genre, ', ') 
    FROM dbo.Song_Genre 
    WHERE Song_SongID = s.SongID
) AS g(Genres)
-- contributors
OUTER APPLY (
    SELECT STRING_AGG(p.Name, ', ')
    FROM dbo.Contributor_Song cs
    JOIN dbo.Person p ON cs.Contributor_ContributorID = (
        SELECT ContributorID FROM dbo.Contributor WHERE Person_NIF = p.NIF
    ) AND cs.Song_SongID = s.SongID
) AS c(Contributors)
-- collaboration (one-to-one)
LEFT JOIN dbo.Collaboration col ON col.Song_SongID = s.SongID
GO