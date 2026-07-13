-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Test CHANGE COLUMN (works instead of RENAME COLUMN)
CREATE DATABASE alter_change_test;
USE alter_change_test;

CREATE TABLE users (
  user_id INT PRIMARY KEY,
  user_name VARCHAR(100)
);

INSERT INTO users VALUES (1, 'Alice');

-- Use CHANGE COLUMN instead of RENAME COLUMN
ALTER TABLE users CHANGE COLUMN user_id id INT;
DESCRIBE users;

ALTER TABLE users CHANGE COLUMN user_name name VARCHAR(100);
DESCRIBE users;

SELECT id, name FROM users;

DROP TABLE users;
DROP DATABASE alter_change_test;
