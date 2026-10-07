-- Runs once, when Postgres initializes an empty data directory
CREATE TABLE notes (id serial PRIMARY KEY, text text NOT NULL);
INSERT INTO notes (text) VALUES ('created by init/01-notes.sql'), ('bind-mounted from your WSL home');
