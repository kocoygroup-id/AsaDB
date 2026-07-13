-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Comprehensive ALTER TABLE tests
CREATE DATABASE alter_test;
USE alter_test;

-- Test table creation
CREATE TABLE products (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  price DECIMAL
);

INSERT INTO products VALUES (1, 'Widget', 9.99);
INSERT INTO products VALUES (2, 'Gadget', 19.99);

-- Test 1: ADD COLUMN with NOT NULL
ALTER TABLE products ADD COLUMN stock INT NOT NULL;
SHOW COLUMNS FROM products;

-- Test 2: ADD COLUMN with DEFAULT
ALTER TABLE products ADD COLUMN category VARCHAR(50) DEFAULT 'uncategorized';
SHOW COLUMNS FROM products;

-- Test 3: Verify data integrity - new rows can be selected
SELECT id, name, category FROM products;

-- Test 4: DROP multiple columns
ALTER TABLE products DROP COLUMN category;
ALTER TABLE products DROP COLUMN stock;
DESCRIBE products;

-- Test 5: MODIFY COLUMN type
ALTER TABLE products MODIFY COLUMN price VARCHAR(20);
DESCRIBE products;

-- Modify back to numeric
ALTER TABLE products MODIFY COLUMN price DECIMAL;
DESCRIBE products;

-- Test 6: Create another table for RENAME tests
CREATE TABLE users (
  user_id INT PRIMARY KEY,
  user_name VARCHAR(100)
);

INSERT INTO users VALUES (1, 'Alice');

-- Test 7: RENAME COLUMN using CHANGE COLUMN (RENAME COLUMN syntax not yet supported)
ALTER TABLE users CHANGE COLUMN user_id id INT PRIMARY KEY;
DESCRIBE users;

-- Test 7b: RENAME COLUMN using CHANGE COLUMN
ALTER TABLE users CHANGE COLUMN user_name name VARCHAR(100);
DESCRIBE users;

-- Verify renamed columns work in queries
SELECT id, name FROM users;

-- Test 8: Multiple operations in one ALTER
CREATE TABLE test_multi (
  col1 INT,
  col2 VARCHAR(50),
  col3 TEXT
);

ALTER TABLE test_multi
  ADD COLUMN col4 VARCHAR(100),
  DROP COLUMN col3;

DESCRIBE test_multi;

-- Clean up
DROP TABLE products;
DROP TABLE users;
DROP TABLE test_multi;
DROP DATABASE alter_test;
