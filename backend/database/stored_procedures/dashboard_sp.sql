-- ====================================================
-- GetDashboardCounts: Returns counts for various entities in the dashboard
-- ====================================================
CREATE OR ALTER PROCEDURE dbo.sp_GetDashboardCounts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        RecordLabelCount,
        EmployeeCount,
        SongCount,
        ContributorCount,
        CollaborationCount
    FROM dbo.vw_DashboardCounts;
END;
GO