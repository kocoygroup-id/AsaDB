-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
CREATE DATABASE test_db;
USE test_db;

-- Create a simple table for testing
CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100));
INSERT INTO users VALUES (1, 'Alice', 'alice@example.com');
INSERT INTO users VALUES (2, 'Bob', 'bob@example.com');

-- Test CREATE VIEW
CREATE VIEW user_emails AS SELECT id, email FROM users;
SELECT * FROM user_emails;

-- Test CREATE FUNCTION
CREATE FUNCTION hello(name VARCHAR(100)) RETURNS VARCHAR(200) BEGIN
    RETURN CONCAT('Hello, ', name);
END;

-- Test CREATE PROCEDURE
CREATE PROCEDURE add_user(IN uid INT, IN uname VARCHAR(100), IN uemail VARCHAR(100)) BEGIN
    INSERT INTO users VALUES (uid, uname, uemail);
END;

-- Test CREATE TRIGGER
CREATE TRIGGER user_audit AFTER INSERT ON users FOR EACH ROW BEGIN
    SELECT 'Audit: user inserted';
END;

-- Show what we created
SHOW TABLES;
