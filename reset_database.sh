#!/bin/bash

# Name of the shell script: reset_database.sh

# Drop existing tables
curl -X POST http://localhost:5000/api/db/drop_tables

# Initialize the database schema
curl -X POST http://localhost:5000/api/db/init

# Populate the database with initial data
curl -X POST http://localhost:5000/api/db/populate

echo "Database reset complete."