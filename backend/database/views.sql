-- ================================================================
-- Record Labels View
-- ================================================================
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


-- ================================================================
-- vw_RecordLabelDependencies: counts how many Employees & Collaborations reference a given Record Label
-- ================================================================
CREATE OR ALTER VIEW dbo.vw_RecordLabelDependencies
AS
SELECT
    rl.RecordLabelID,
    -- Count how many employees reference this label
    ISNULL(emp.EmployeeCount, 0)           AS EmployeeCount,
    -- Count how many collaboration‐label links exist for this label
    ISNULL(collab.LinkCount, 0)            AS CollaborationCount
FROM dbo.RecordLabel rl
LEFT JOIN (
    SELECT
      e.RecordLabel_RecordLabelID AS LabelID,
      COUNT(*)                   AS EmployeeCount
    FROM dbo.Employee e
    GROUP BY e.RecordLabel_RecordLabelID
) AS emp
  ON emp.LabelID = rl.RecordLabelID
LEFT JOIN (
    SELECT
      rlc.RecordLabel_RecordLabelID2 AS LabelID,
      COUNT(*)                         AS LinkCount
    FROM dbo.RecordLabel_Collaboration rlc
    GROUP BY rlc.RecordLabel_RecordLabelID2
) AS collab
  ON collab.LabelID = rl.RecordLabelID;
GO


-- ================================================================
-- Employees View
-- ================================================================
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

-- ================================================================
-- Songs View
-- ================================================================
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


-- ================================================
-- Contributors View
-- ================================================
CREATE OR ALTER VIEW dbo.vw_Contributors
AS
SELECT
    c.ContributorID,
    p.NIF,
    p.Name,
    p.DateOfBirth,
    p.Email,
    p.PhoneNumber,
    -- if this contributor is also an employee, get their label name
    rl.Name AS RecordLabelName,
    -- aggregate roles
    STUFF(
      COALESCE(a.Roles, '') +
      COALESCE(pr.Roles, '') +
      COALESCE(sw.Roles, ''),
      1, 2, ''
    ) AS Roles
FROM dbo.Contributor c
JOIN dbo.Person p
  ON p.NIF = c.Person_NIF
LEFT JOIN dbo.Employee e
  ON e.Person_NIF = p.NIF
LEFT JOIN dbo.RecordLabel rl
  ON rl.RecordLabelID = e.RecordLabel_RecordLabelID
OUTER APPLY (
    SELECT ', ' + 'Artist'
    WHERE EXISTS(
      SELECT 1 FROM dbo.Artist
      WHERE Contributor_ContributorID = c.ContributorID
    )
) AS a(Roles)
OUTER APPLY (
    SELECT ', ' + 'Producer'
    WHERE EXISTS(
      SELECT 1 FROM dbo.Producer
      WHERE Contributor_ContributorID = c.ContributorID
    )
) AS pr(Roles)
OUTER APPLY (
    SELECT ', ' + 'Songwriter'
    WHERE EXISTS(
      SELECT 1 FROM dbo.Songwriter
      WHERE Contributor_ContributorID = c.ContributorID
    )
) AS sw(Roles);
GO

-- ================================================================
-- Collaborations View
-- ================================================================
GO
CREATE OR ALTER VIEW dbo.vw_Collaborations
AS
SELECT
    c.CollaborationID,
    c.CollaborationName,
    c.StartDate,
    c.EndDate,
    c.Description,
    s.SongID,
    s.Title AS SongTitle,
    -- aggregate record labels
    STUFF((
      SELECT ', ' + rl.Name
      FROM dbo.RecordLabel_Collaboration rlc
      JOIN dbo.RecordLabel rl
        ON rl.RecordLabelID = rlc.RecordLabel_RecordLabelID2
      WHERE rlc.Collaboration_CollaborationID = c.CollaborationID
      FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 2, '') AS RecordLabels,
    -- aggregate contributors
    STUFF((
      SELECT ', ' + p.Name
      FROM dbo.Collaboration_Contributor cc
      JOIN dbo.Contributor co
        ON co.ContributorID = cc.Contributor_ContributorID
      JOIN dbo.Person p
        ON p.NIF = co.Person_NIF
      WHERE cc.Collaboration_CollaborationID = c.CollaborationID
      FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 2, '') AS Contributors
FROM dbo.Collaboration c
LEFT JOIN dbo.Song s
  ON s.SongID = c.Song_SongID;
GO

-- ================================================================
-- Dashboard View
-- ================================================================
CREATE OR ALTER VIEW dbo.vw_DashboardCounts
AS
SELECT
    /* Count of record labels */
    (SELECT COUNT(*) FROM dbo.RecordLabel)         AS RecordLabelCount,
    /* Count of employees */
    (SELECT COUNT(*) FROM dbo.Employee)            AS EmployeeCount,
    /* Count of songs */
    (SELECT COUNT(*) FROM dbo.Song)                AS SongCount,
    /* Count of contributors */
    (SELECT COUNT(*) FROM dbo.Contributor)         AS ContributorCount,
    /* Count of collaborations */
    (SELECT COUNT(*) FROM dbo.Collaboration)       AS CollaborationCount;
GO
