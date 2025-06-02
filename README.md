# Record Labels Database

## Overview

The Record Labels Database project is a full-stack web application designed to manage and visualize music-related data. The backend is powered by Flask and a PostgreSQL database, while the frontend is developed using HTML, CSS, and JavaScript. The project also includes Docker for containerization and easy deployment.

## Features

-   **Frontend Pages**: Dashboard, Record Labels, Employees, Songs, Contributors, and Collaborations
-   **CRUD Operations**: Insert, Update, and Delete functionalities for each data category
-   **Conflict Resolution**: Forms are presented in case of data conflicts during operations
-   **Stored Procedures**: Modular SQL stored procedures for maintainability
-   **Database Reset**: A single shell script to drop, initialize, and populate the database

## Technologies Used

-   **Backend**: Python, Flask
-   **Database**: SQL, SQL Server Management Studio 19 (SSMS 19)
-   **Frontend**: HTML, CSS, JavaScript
-   **Containerization**: Docker, Docker Compose

## File Structure

```bash
|.
├── backend
│   ├── database
│   │   ├── ddl.sql
│   │   ├── drop_all_tables.sql
│   │   ├── insert_data.sql
│   │   ├── stored_procedures
│   │   │   ├── collaboration_sp.sql
│   │   │   ├── contributor_sp.sql
│   │   │   ├── dashboard_sp.sql
│   │   │   ├── employee_sp.sql
│   │   │   ├── person_sp.sql
│   │   │   ├── record_label_sp.sql
│   │   │   └── song_sp.sql
│   │   ├── triggers.sql
│   │   └── views.sql
│   ├── endpoints
│   │   ├── collaborations.py
│   │   ├── contributors.py
│   │   ├── dashboard.py
│   │   ├── db_admin_routes.py
│   │   ├── employee.py
│   │   ├── frontend_routes.py
│   │   ├── init.py
│   │   ├── persons.py
│   │   ├── record_label.py
│   │   └── songs.py
│   ├── init.py
│   └── main.py
├── config
│   ├── config.py
│   ├── database_config.py
│   ├── env_loader.py
│   ├── init.py
│   └── logger.py
├── database_images
│   ├── BD_Project_DER.drawio.pdf
│   ├── BD_Project_MR.drawio.pdf
│   └── RecordLabel_Diagram.png
├── docker-compose.yml
├── Dockerfile
├── frontend
│   ├── static
│   │   ├── css
│   │   │   ├── contributor.css
│   │   │   ├── record_label.css
│   │   │   └── style.css
│   │   └── js
│   │       ├── collaboration.js
│   │       ├── contributor.js
│   │       ├── dashboard.js
│   │       ├── employee.js
│   │       ├── endpoints
│   │       │   ├── collaboration_api.js
│   │       │   ├── contributor_api.js
│   │       │   ├── dashboard_api.js
│   │       │   ├── employee_api.js
│   │       │   ├── record_label_api.js
│   │       │   └── song_api.js
│   │       ├── main.js
│   │       ├── record_label.js
│   │       └── song.js
│   └── templates
│       ├── index.html
│       └── pages
│           ├── collaboration.html
│           ├── contributor.html
│           ├── dashboard.html
│           ├── employee.html
│           ├── record_label.html
│           └── song.html
├── README.md
├── requirements.txt
└── reset_database.sh
```

## Getting Started

### Prerequisites

-   Python 3.8+
-   Docker and Docker Compose

### Setup Instructions

```bash
# 1. Clone the repository
git clone https://github.com/hmecruz/record_label_database.git
cd record-labels-database

# 2. Create and activate a virtual environment
python -m venv venv
source venv/bin/activate  
#venv\Scripts\activate # On Windoes use

# 3. Install Python dependencies
pip install -r requirements.txt

# 4. Install Docker and Docker Compose if not already installed

# 5. Fill in the .env file based on .env-sample
cp .env-sample .env
# Edit .env and fill in the required values

# 6. Build and run the containers
docker-compose up --build

# 7. Open your browser and visit
http://localhost:5000  # Or your configured port
```

### .env-sample

```bash
# Flask application configuration
HOST=YOUR-HOST
PORT=YOUR-PORT

# Database configuration
DB_USER=YOUR-DB-USER
DB_PASSWORD=YOUR-DB-PASSWORD
DB_NAME=YOUR-DB-NAME
DB_CONN_STRING=YOUR-DB-CONN-STRING
```

## Database Management

### Resetting the Database

To drop, reinitialize, and repopulate the database, run:

    ./reset_database.sh

This script calls endpoints defined in `db_admin_routes.py`. Note that:

-   The script uses a hardcoded port (5000); change it if using a different one.
-   You may need to adjust `db_admin_routes.py` if you add new SQL files outside the `stored_procedures` directory.

### SQL Components

-   **DDL**: `ddl.sql`
-   **Initial Data**: `insert_data.sql`
-   **Stored Procedures**: Located in `stored_procedures/`
-   **Views**: `views.sql`
-   **Triggers**: `triggers.sql`
-   **Drop All Tables**: `drop_all_tables.sql`

## Additional Notes

-   The `database_images/` folder includes visual diagrams: DER, MR, and a database diagram generated with SSMS 19
-   Some tables originally in the diagrams (like Albums and Bands) were intentionally excluded from implementation
- The Collaboration page is not complete, it only allows the DELETE function

## License

This project is for academic purposes. Feel free to fork and extend it.

## Acknowledgements

- Developed using Flask, Docker, SQL, and SSMS 19
- Frontend crafted with vanilla HTML/CSS/JS