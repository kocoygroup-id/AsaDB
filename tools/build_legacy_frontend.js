// Copyright (C) 2026 Kocoy Group and AsaDB contributors
// SPDX-License-Identifier: GPL-3.0-only
// Build driver used by scripts/build_legacy_frontend.sh.
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const [moduleRoot, sourcePath, outputPath] = process.argv.slice(2);
if (!moduleRoot || !sourcePath || !outputPath) {
  console.error('Usage: node build_legacy_frontend.js NODE_MODULES SOURCE OUTPUT');
  process.exit(2);
}

const babel = require(path.join(moduleRoot, '@babel', 'core'));
const presetEnv = require(path.join(moduleRoot, '@babel', 'preset-env'));
const source = fs.readFileSync(sourcePath, 'utf8');
const transformed = babel.transformSync(source, {
  filename: path.basename(sourcePath),
  presets: [[presetEnv, {
    targets: { firefox: '38' },
    modules: false,
    bugfixes: true,
  }]],
  comments: true,
  compact: false,
});

if (!transformed || !transformed.code) {
  throw new Error('Babel did not produce a frontend bundle.');
}

const banner = '/* AsaDB legacy browser bundle; generated from app.js. GPL-3.0-only. */\n';
fs.writeFileSync(outputPath, `${banner}${transformed.code}\n`, 'utf8');
