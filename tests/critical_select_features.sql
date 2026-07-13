-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Critical SELECT features: joins, grouping/aggregates, and basic subqueries
CREATE DATABASE critical_select;
USE critical_select;

CREATE TABLE users (
  id INT PRIMARY KEY,
  age INT
);

CREATE TABLE orders (
  id INT PRIMARY KEY,
  user_id INT,
  total INT
);

INSERT INTO users (id, age) VALUES
  (1, 10),
  (2, 20),
  (3, 30);

INSERT INTO orders (id, user_id, total) VALUES
  (10, 1, 50),
  (11, 1, 70),
  (12, 2, 30),
  (13, 4, 99);

CREATE VIEW user_names AS SELECT id, age FROM users;
CREATE FUNCTION hello(name VARCHAR(100)) RETURNS VARCHAR(200) BEGIN RETURN name END;
CREATE PROCEDURE noop(IN uid INT) BEGIN SELECT uid END;
CREATE TRIGGER user_audit AFTER INSERT ON users FOR EACH ROW BEGIN SELECT 'audit' END;

SELECT u.id, o.total
FROM users u
INNER JOIN orders o ON u.id = o.user_id
ORDER BY u.id, o.total;

SELECT u.id, o.total
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
ORDER BY u.id, o.total;

SELECT u.id, o.total
FROM users u
RIGHT JOIN orders o ON u.id = o.user_id
ORDER BY o.id;

SELECT user_id,
       COUNT(*) AS n,
       SUM(total) AS total_sum,
       AVG(total) AS total_avg,
       MIN(total) AS total_min,
       MAX(total) AS total_max
FROM orders
GROUP BY user_id
ORDER BY user_id;

SELECT id
FROM users
WHERE id IN (SELECT user_id FROM orders)
ORDER BY id;

SELECT (SELECT COUNT(*) FROM orders) AS order_count
FROM users
LIMIT 1;

SELECT id
FROM users
WHERE age > 20
UNION
SELECT user_id
FROM orders
WHERE total = 30;

SELECT id,
       CASE WHEN age >= 20 THEN 'adult' ELSE 'young' END AS bucket,
       CONCAT('u', id) AS label
FROM users
ORDER BY id;

SELECT *
FROM user_names
ORDER BY id;

DROP TRIGGER user_audit;
DROP PROCEDURE noop;
DROP FUNCTION hello;
DROP VIEW user_names;
DROP DATABASE critical_select;
