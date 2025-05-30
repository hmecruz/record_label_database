# record_label_database

curl -X POST http://localhost:5000/api/db/drop_tables
curl -X POST http://localhost:5000/api/db/init
curl -X POST http://localhost:5000/api/db/populate

IMPORTANT WHEN USING THE FILTERS THE API CALLS SOMETIMES ARE SLOW
RECOMMENDATION WRITE AND DELETE LETTERS FROM THE FILTER SLOWLY