-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Test basic ALTER without RENAME
CREATE DATABASE simple_alter_test;
USE simple_alter_test;

CREATE TABLE users (
  user_id INT PRIMARY KEY,
  user_name VARCHAR(100)
);

INSERT INTO users VALUES (1, 'Alice');

-- Test basic ADD
ALTER TABLE users ADD COLUMN age INT;
DESCRIBE users;

DROP TABLE users;
DROP DATABASE simple_alter_test;
