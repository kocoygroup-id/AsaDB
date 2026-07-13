-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Test RENAME COLUMN
CREATE DATABASE rename_test;
USE rename_test;

CREATE TABLE users (
  user_id INT PRIMARY KEY,
  user_name VARCHAR(100)
);

INSERT INTO users VALUES (1, 'Alice');

-- Test RENAME COLUMN
ALTER TABLE users RENAME COLUMN user_id TO id;
DESCRIBE users;

ALTER TABLE users RENAME COLUMN user_name TO name;
DESCRIBE users;

SELECT id, name FROM users;

DROP TABLE users;
DROP DATABASE rename_test;
