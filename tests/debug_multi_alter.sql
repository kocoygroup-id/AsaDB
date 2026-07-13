-- Copyright (C) 2026 Kocoy Group and AsaDB contributors
-- SPDX-License-Identifier: GPL-3.0-only
-- Simplified test to identify the issue
CREATE DATABASE test_debug;
USE test_debug;

CREATE TABLE test_multi (
  col1 INT,
  col2 VARCHAR(50),
  col3 TEXT
);

-- This multi-operation ALTER is causing the issue
ALTER TABLE test_multi
  ADD COLUMN col4 VARCHAR(100),
  DROP COLUMN col3;

DESCRIBE test_multi;

DROP TABLE test_multi;
DROP DATABASE test_debug;
