-- ========== Drop Association Tables First ==========
DROP TABLE IF EXISTS RecordLabel_Collaboration;
DROP TABLE IF EXISTS Collaboration_Contributor;
DROP TABLE IF EXISTS Contributor_Song;
DROP TABLE IF EXISTS Song_Genre;
DROP TABLE IF EXISTS Artist_Genre;

-- ========== Drop Specialization Tables ==========
DROP TABLE IF EXISTS Songwriter;
DROP TABLE IF EXISTS Producer;
DROP TABLE IF EXISTS Artist;

-- ========== Drop Contributor and Employee (IS-A relationships) ==========
DROP TABLE IF EXISTS Contributor;
DROP TABLE IF EXISTS Employee;

-- ========== Drop Base Entities ==========
DROP TABLE IF EXISTS Collaboration;
DROP TABLE IF EXISTS Song;
DROP TABLE IF EXISTS RecordLabel;
DROP TABLE IF EXISTS Person;
