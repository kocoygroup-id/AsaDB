-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- AsaDB v1.0.2 feature tour
DROP DATABASE IF EXISTS asa_demo_v100;
CREATE DATABASE asa_demo_v100;
USE asa_demo_v100;

CREATE TABLE users (
  id INT PRIMARY KEY,
  name VARCHAR(100),
  age INT
);

CREATE TABLE orders (
  id INT PRIMARY KEY,
  user_id INT,
  total INT
);

INSERT INTO users (id, name, age) VALUES
  (1, 'Aires', 17),
  (2, 'Asa', 20),
  (3, 'Nia', 30);

INSERT INTO orders (id, user_id, total) VALUES
  (10, 1, 50),
  (11, 1, 70),
  (12, 2, 30),
  (13, 4, 99);

ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';
UPDATE users SET status = 'vip' WHERE id = 2;

CREATE INDEX idx_orders_user ON orders (user_id);
CREATE VIEW adult_users AS SELECT id, name, age, status FROM users WHERE age >= 18;
CREATE FUNCTION hello(name VARCHAR(100)) RETURNS VARCHAR(200) BEGIN RETURN name END;
CREATE PROCEDURE noop(IN uid INT) BEGIN SELECT uid END;
CREATE TRIGGER user_audit AFTER INSERT ON users FOR EACH ROW BEGIN SELECT 'audit' END;

SELECT * FROM users ORDER BY id;

SELECT u.id, u.name, o.total
FROM users u
INNER JOIN orders o ON u.id = o.user_id
ORDER BY u.id, o.total;

SELECT u.id, u.name, o.total
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
ORDER BY u.id, o.total;

SELECT u.id, o.total
FROM users u
RIGHT JOIN orders o ON u.id = o.user_id
ORDER BY o.id;

SELECT user_id,
       COUNT(*) AS order_count,
       SUM(total) AS total_sum,
       AVG(total) AS total_avg,
       MIN(total) AS min_order,
       MAX(total) AS max_order
FROM orders
GROUP BY user_id
ORDER BY user_id;

SELECT name
FROM users
WHERE id IN (SELECT user_id FROM orders WHERE total >= 70)
ORDER BY name;

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
       CASE WHEN age >= 18 THEN 'adult' ELSE 'young' END AS bucket,
       CONCAT('user-', name) AS label
FROM users
ORDER BY id;

SELECT * FROM adult_users ORDER BY id;
SHOW TABLES;
SHOW INDEX FROM orders;
DESCRIBE users;
