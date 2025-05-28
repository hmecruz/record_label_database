-- ========= Tabelas Principais (Entidades Independentes ou de Base) =========

CREATE TABLE RecordLabel (
    RecordLabelID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(255) NOT NULL UNIQUE,
    Location VARCHAR(255),
    Website VARCHAR(255) UNIQUE,
    Email VARCHAR(255) UNIQUE,
    PhoneNumber VARCHAR(50) UNIQUE
);

CREATE TABLE Song (
    SongID INT IDENTITY(1,1) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    Duration INT NOT NULL,
    ReleaseDate DATE
);

CREATE TABLE Collaboration (
    CollaborationID INT IDENTITY(1,1) PRIMARY KEY,
    CollaborationName VARCHAR(255) NOT NULL,
    StartDate DATE NOT NULL,
    EndDate DATE,
    Description TEXT,
    Song_SongID INT,
    FOREIGN KEY (Song_SongID) REFERENCES Song(SongID),
    CHECK (
        (StartDate IS NOT NULL OR EndDate IS NULL) AND
        (StartDate IS NULL OR EndDate IS NULL OR EndDate >= StartDate)
    )
);

CREATE TABLE Album (
    AlbumID INT IDENTITY(1,1) PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    ReleaseDate DATE
);

CREATE TABLE Band (
    BandGroupID INT IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE Person (
    NIF VARCHAR(20) PRIMARY KEY, 
    Name VARCHAR(255) NOT NULL,
    DateOfBirth DATE,
    Email VARCHAR(255) UNIQUE,
    PhoneNumber VARCHAR(50) UNIQUE
);

-- ========= Especializações (IS-A) =========

CREATE TABLE Contributor (
    ContributorID INT IDENTITY(1,1) PRIMARY KEY,
    Person_NIF VARCHAR(20) NOT NULL UNIQUE,
    FOREIGN KEY (Person_NIF) REFERENCES Person(NIF) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Employee (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    JobTitle VARCHAR(100) NOT NULL,
    Department VARCHAR(100),
    Salary DECIMAL(10, 2) CHECK (Salary >= 0),
    HireDate DATE NOT NULL,
    RecordLabel_RecordLabelID INT NOT NULL,
    Person_NIF VARCHAR(20) NOT NULL UNIQUE,
    FOREIGN KEY (RecordLabel_RecordLabelID) REFERENCES RecordLabel(RecordLabelID) ON DELETE NO ACTION ON UPDATE CASCADE,
    FOREIGN KEY (Person_NIF) REFERENCES Person(NIF) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Songwriter (
    Contributor_ContributorID INT PRIMARY KEY,
    FOREIGN KEY (Contributor_ContributorID) REFERENCES Contributor(ContributorID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Producer (
    Contributor_ContributorID INT PRIMARY KEY,
    FOREIGN KEY (Contributor_ContributorID) REFERENCES Contributor(ContributorID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Artist (
    Contributor_ContributorID INT PRIMARY KEY,
    StageName VARCHAR(255) UNIQUE,
    FOREIGN KEY (Contributor_ContributorID) REFERENCES Contributor(ContributorID) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ========= Tabelas de Associação e Atributos Multi-valor =========

CREATE TABLE RecordLabel_Collaboration (
    RecordLabel_RecordLabelID1 INT NOT NULL,
    RecordLabel_RecordLabelID2 INT NOT NULL,
    Collaboration_CollaborationID INT NOT NULL,
    PRIMARY KEY (RecordLabel_RecordLabelID1, RecordLabel_RecordLabelID2, Collaboration_CollaborationID),
    FOREIGN KEY (RecordLabel_RecordLabelID1) REFERENCES RecordLabel(RecordLabelID) ON DELETE CASCADE ON UPDATE NO ACTION,
    FOREIGN KEY (RecordLabel_RecordLabelID2) REFERENCES RecordLabel(RecordLabelID) ON DELETE NO ACTION ON UPDATE NO ACTION,
    FOREIGN KEY (Collaboration_CollaborationID) REFERENCES Collaboration(CollaborationID) ON DELETE CASCADE ON UPDATE NO ACTION,
    CHECK (RecordLabel_RecordLabelID1 <> RecordLabel_RecordLabelID2)
);

CREATE TABLE Collaboration_Contributor (
    Collaboration_CollaborationID INT NOT NULL,
    Contributor_ContributorID INT NOT NULL,
    PRIMARY KEY (Collaboration_CollaborationID, Contributor_ContributorID),
    FOREIGN KEY (Collaboration_CollaborationID) REFERENCES Collaboration(CollaborationID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Contributor_ContributorID) REFERENCES Contributor(ContributorID) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Contributor_Song (
    Contributor_ContributorID INT NOT NULL,
    Song_SongID INT NOT NULL,
    Date DATE,
    PRIMARY KEY (Contributor_ContributorID, Song_SongID),
    FOREIGN KEY (Contributor_ContributorID) REFERENCES Contributor(ContributorID) ON DELETE NO ACTION ON UPDATE CASCADE,
    FOREIGN KEY (Song_SongID) REFERENCES Song(SongID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Album_Song (
    Album_AlbumID INT NOT NULL,
    Song_SongID INT NOT NULL,
    PRIMARY KEY (Album_AlbumID, Song_SongID),
    FOREIGN KEY (Album_AlbumID) REFERENCES Album(AlbumID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Song_SongID) REFERENCES Song(SongID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Song_Genre (
    Song_SongID INT NOT NULL,
    Genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (Song_SongID, Genre),
    FOREIGN KEY (Song_SongID) REFERENCES Song(SongID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Artist_Genre (
    Artist_ContributorID INT NOT NULL,
    Genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (Artist_ContributorID, Genre),
    FOREIGN KEY (Artist_ContributorID) REFERENCES Artist(Contributor_ContributorID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Band_Artist (
    Band_BandGroupID INT NOT NULL,
    Artist_ContributorID INT NOT NULL,
    PRIMARY KEY (Band_BandGroupID, Artist_ContributorID),
    FOREIGN KEY (Band_BandGroupID) REFERENCES Band(BandGroupID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Artist_ContributorID) REFERENCES Artist(Contributor_ContributorID) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Band_Genre (
    Band_BandGroupID INT NOT NULL,
    Genre VARCHAR(50) NOT NULL,
    PRIMARY KEY (Band_BandGroupID, Genre),
    FOREIGN KEY (Band_BandGroupID) REFERENCES Band(BandGroupID) ON DELETE CASCADE ON UPDATE CASCADE
);
