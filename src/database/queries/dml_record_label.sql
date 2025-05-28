-- =========================
-- Record Label Operations - DML Queries
-- =========================

-- ===== SELECT Queries =====

-- 1. List employees per label
SELECT rl.RecordLabelID, rl.Name AS LabelName,
       e.EmployeeID, p.Name AS EmployeeName, e.JobTitle, e.Department, e.HireDate
FROM RecordLabel rl
JOIN Employee e ON rl.RecordLabelID = e.RecordLabel_RecordLabelID
JOIN Person p ON e.Person_NIF = p.NIF
ORDER BY rl.RecordLabelID, e.EmployeeID;

-- 2. List collaborations associated with a label
SELECT rl.RecordLabelID, rl.Name AS LabelName,
       c.CollaborationID, c.CollaborationName, c.StartDate, c.EndDate
FROM RecordLabel rl
JOIN RecordLabel_Collaboration rlc ON rl.RecordLabelID = rlc.RecordLabel_RecordLabelID1
JOIN Collaboration c ON rlc.Collaboration_CollaborationID = c.CollaborationID
UNION
SELECT rl.RecordLabelID, rl.Name AS LabelName,
       c.CollaborationID, c.CollaborationName, c.StartDate, c.EndDate
FROM RecordLabel rl
JOIN RecordLabel_Collaboration rlc ON rl.RecordLabelID = rlc.RecordLabel_RecordLabelID2
JOIN Collaboration c ON rlc.Collaboration_CollaborationID = c.CollaborationID
ORDER BY RecordLabelID, CollaborationID;

-- ===== INSERT Queries =====

-- Insert a new Record Label
INSERT INTO RecordLabel (Name, Location, Website, Email, PhoneNumber)
VALUES ('New Label Name', 'New Location', 'https://newlabelwebsite.com', 'contact@newlabel.com', '123-456-7890');

-- ===== UPDATE Queries =====

-- 3. Update label contact info
UPDATE RecordLabel
SET Location = 'New Location',
    Website = 'https://newwebsite.com',
    Email = 'contact@newwebsite.com',
    PhoneNumber = '123-456-7890'
WHERE RecordLabelID = 1;

-- ===== DELETE Queries with Referential Integrity Considerations =====

-- 4. Delete a record label (useful for test/demo data)
-- Related Employee rows have ON DELETE NO ACTION -> must delete employees first or update to handle cascade
-- Related RecordLabel_Collaboration rows have ON DELETE CASCADE on RecordLabel_RecordLabelID1 only,
-- so deletion may fail if related to RecordLabel_RecordLabelID2. Must delete related rows manually.

-- Delete employees related to the label first (because ON DELETE NO ACTION)
DELETE FROM Employee
WHERE RecordLabel_RecordLabelID = 1;

-- Delete RecordLabel_Collaboration associations where the label is either RecordLabel_RecordLabelID1 or RecordLabel_RecordLabelID2
DELETE FROM RecordLabel_Collaboration
WHERE RecordLabel_RecordLabelID1 = 1
   OR RecordLabel_RecordLabelID2 = 1;

-- Finally delete the record label itself
DELETE FROM RecordLabel
WHERE RecordLabelID = 1;
