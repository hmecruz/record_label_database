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

-- 3. Find all record labels with no collaborations
SELECT rl.RecordLabelID, rl.Name
FROM RecordLabel rl
LEFT JOIN RecordLabel_Collaboration rlc1 ON rl.RecordLabelID = rlc1.RecordLabel_RecordLabelID1
LEFT JOIN RecordLabel_Collaboration rlc2 ON rl.RecordLabelID = rlc2.RecordLabel_RecordLabelID2
WHERE rlc1.RecordLabel_RecordLabelID1 IS NULL AND rlc2.RecordLabel_RecordLabelID2 IS NULL;


-- ===== UPDATE Queries =====

-- Update label contact info
UPDATE RecordLabel
SET Location = 'New Location',
    Website = 'https://newwebsite.com',
    Email = 'contact@newwebsite.com',
    PhoneNumber = '123-456-7890'
WHERE RecordLabelID = 1;

-- ===== DELETE Queries with Referential Integrity Considerations =====

-- Delete a record label (for test/demo purposes only)

-- Step 1: Delete employees linked to this label (ON DELETE NO ACTION)
DELETE FROM Employee
WHERE RecordLabel_RecordLabelID = 1;

-- Step 2: Delete RecordLabel_Collaboration associations
DELETE FROM RecordLabel_Collaboration
WHERE RecordLabel_RecordLabelID1 = 1
   OR RecordLabel_RecordLabelID2 = 1;

-- Step 3: Delete the record label itself
DELETE FROM RecordLabel
WHERE RecordLabelID = 1;