-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
CREATE DATABASE prod;
USE prod;

CREATE TABLE orders (
  id INT PRIMARY KEY,
  customer VARCHAR(80),
  qty INT DEFAULT 1,
  status VARCHAR(20) DEFAULT 'open'
);

INSERT INTO orders (id, customer, qty) VALUES
  (1, 'Aires', 2),
  (2, 'Asa', 5),
  (3, 'Nia', 10);

CREATE INDEX idx_orders_qty ON orders (qty);
SHOW INDEX FROM orders;

SELECT id, qty + 1 AS next_qty
FROM orders
WHERE qty BETWEEN 2 AND 10 OR customer LIKE 'Air%'
ORDER BY qty DESC
LIMIT 1 OFFSET 1;

START TRANSACTION;
UPDATE orders SET qty = qty + 1 WHERE id IN (1, 2);
ROLLBACK;

SELECT id, qty FROM orders ORDER BY id;

CREATE USER reader IDENTIFIED BY 'pw';
GRANT select ON prod.orders TO reader;
SHOW GRANTS FOR reader;
LOGIN reader IDENTIFIED BY 'pw';
SELECT id, customer FROM orders WHERE status = 'open' ORDER BY id;
