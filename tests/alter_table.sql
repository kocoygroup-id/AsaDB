-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Test ALTER TABLE functionality
CREATE DATABASE alter_test;
USE alter_test;

-- Create initial table
CREATE TABLE users (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  email VARCHAR(100)
);

-- Insert test data
INSERT INTO users VALUES (1, 'Alice', 'alice@example.com');
INSERT INTO users VALUES (2, 'Bob', 'bob@example.com');

-- Test 1: ADD COLUMN
ALTER TABLE users ADD COLUMN age INT;
DESCRIBE users;

-- Test 2: ADD COLUMN with DEFAULT
ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';
DESCRIBE users;

-- Test 3: DROP COLUMN
ALTER TABLE users DROP COLUMN status;
DESCRIBE users;

-- Test 4: MODIFY COLUMN (change type)
ALTER TABLE users MODIFY COLUMN age VARCHAR(50);
DESCRIBE users;

-- Test 5: SELECT after modifications
SELECT * FROM users;

-- Clean up
DROP TABLE users;
DROP DATABASE alter_test;
