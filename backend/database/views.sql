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
