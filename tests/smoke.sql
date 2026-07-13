-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
CREATE DATABASE smoke;
USE smoke;
CREATE TABLE notes (id INT NOT NULL, title VARCHAR(120), body TEXT DEFAULT 'empty');
INSERT INTO notes (id, title) VALUES (1, 'hello'), (2, 'world');
SELECT * FROM notes;
UPDATE notes SET body = 'updated' WHERE id = 2;
SELECT id, body FROM notes WHERE id = 2;
DELETE FROM notes WHERE id = 1;
SELECT * FROM notes;
SHOW TABLES;
DESCRIBE notes;
