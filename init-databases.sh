#!/bin/bash
set -e

# Create the core_banking database if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE core_banking'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'core_banking')\gexec
EOSQL
