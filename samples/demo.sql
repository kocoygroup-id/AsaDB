CREATE DATABASE asa;
USE asa;

CREATE TABLE users (
  id INT NOT NULL,
  name VARCHAR(100),
  age INT,
  status VARCHAR(20) DEFAULT 'active'
);

INSERT INTO users (id, name, age) VALUES
  (1, 'Aires', 19),
  (2, 'Asa', 18),
  (3, 'Yuko', 18);

SELECT * FROM users;
SELECT id, name FROM users WHERE id = 1;
UPDATE users SET status = 'sleepy' WHERE name = 'Asa';
SELECT * FROM users;
DELETE FROM users WHERE id = 3;
SELECT * FROM users;
SHOW DATABASES;
SHOW TABLES;
DESCRIBE users;
