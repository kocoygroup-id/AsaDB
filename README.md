# AsaDB v1.0.0

This repository contains the public Windows release package for AsaDB, including
the portable runtime, AsAPanel local web interface, launcher scripts, and sample
SQL files.

AsaDB is a local database runtime backed by a Prolog engine. It can be used from
a browser-based local panel or directly from the command line through `AsA.exe`.

This README describes the release package layout, how to run the runtime, what
is included in the package, and how the local database files are handled.

## Release Package

The v1.0.0 package is designed as a portable Windows distribution.

The package includes:

    app/                    Runtime directory
    app/AsA.exe              Main AsaDB executable
    app/web/                 AsAPanel local web interface
    data/                    Local database files
    samples/                 Safe sample SQL files
    START_ASADB.bat          Start AsaDB and open the browser
    START_ASADB_NO_BROWSER.bat
                             Start AsaDB without opening the browser
    RUN_CLI_SAMPLE.bat       Run the CLI sample
    LICENSE.md               License information
    SECURITY.md              Security policy
    README.md                This file

The engine source tree, internal development tools, internal tests, and private
database files are not part of this release package.

## Starting AsaDB

The simplest way to start AsaDB is to run:

    START_ASADB.bat

This starts the local AsaDB runtime and opens AsAPanel in the browser.

The panel runs on:

    http://127.0.0.1:8088

If the browser does not open automatically, open the address manually.

To start the runtime without opening a browser, run:

    START_ASADB_NO_BROWSER.bat

## Running The CLI Sample

A CLI sample is included so the runtime can be tested without using the web
panel.

Run:

    RUN_CLI_SAMPLE.bat

Or run the executable manually:

    cd app
    AsA.exe cli ..\data\sample-run.asa ..\samples\feature-tour.sql

The command above runs AsaDB against a local `.asa` database file and executes
the sample SQL script from the `samples/` directory.

## AsAPanel

AsAPanel is the local browser interface included in this release.

It is served from the local runtime and is intended for working with local
database files. From the panel, users can create databases, execute SQL, inspect
tables, and import the sample SQL script.

The public panel is wired to the local Prolog-backed runtime through `AsA.exe`.

## Supported SQL Surface In v1.0.0

The v1.0.0 release supports the following SQL surface.

### Database and Table Commands

    CREATE
    DROP
    USE
    SHOW
    DESCRIBE

### Data Manipulation

    INSERT
    SELECT
    UPDATE
    DELETE
    TRUNCATE

### ALTER TABLE

    ADD COLUMN
    DROP COLUMN
    MODIFY COLUMN
    CHANGE COLUMN
    RENAME COLUMN
    RENAME TABLE

### SELECT Features

    INNER JOIN
    LEFT JOIN
    RIGHT JOIN
    GROUP BY
    COUNT
    SUM
    AVG
    MIN
    MAX

### Expressions and Functions

    UNION
    CASE
    CONCAT
    LOWER
    UPPER

### Subqueries

    IN (SELECT ...)
    scalar subquery

### Views

    CREATE VIEW
    DROP VIEW
    SELECT from view

### Routine Catalog

    CREATE FUNCTION
    DROP FUNCTION
    CREATE PROCEDURE
    DROP PROCEDURE
    CREATE TRIGGER
    DROP TRIGGER

Routine statements are stored in the AsaDB catalog for metadata-level handling.

### Index Catalog

    CREATE INDEX
    DROP INDEX
    SHOW INDEX

Index statements are tracked in the AsaDB catalog.

### Transaction Snapshot

    BEGIN
    START TRANSACTION
    COMMIT
    ROLLBACK

### User and Permission Catalog

    CREATE USER
    GRANT
    REVOKE
    SHOW GRANTS
    LOGIN

## Database Files

AsaDB stores local database data inside the `data/` directory.

The package uses the following file types:

    *.asa
    *.journal

The `.asa` file contains local database state. The `.journal` file is used for
runtime state tracking and transaction-related recovery data.

User database files should not be committed to a public Git repository. A public
release repository should ignore local database files with a `.gitignore` entry
similar to:

    data/*.asa
    data/*.journal

## Source Distribution

This repository is a public release package, not the internal engine source
tree.

The following internal development directories and files are intentionally not
included in this package:

    src/
    tests/
    tools/
    internal docs/
    private .asa files
    development-only scripts

The public package is distributed around the portable executable runtime and the
local panel assets.

## Runtime Flow

A typical runtime session looks like this:

    1. User runs START_ASADB.bat
    2. AsA.exe starts the local runtime
    3. AsAPanel is served at 127.0.0.1:8088
    4. User opens or creates a database in data/
    5. SQL is submitted from the panel or CLI
    6. The local engine processes the statement
    7. Database changes are written back to the local .asa file

The same runtime can also be used from the CLI by passing a database path and
SQL script path to `AsA.exe`.

## Package Tree Map

    AsaDB-v1.0.0-Windows/
    |-- app/
    |   |-- AsA.exe
    |   `-- web/
    |
    |-- data/
    |   |-- .gitkeep
    |   |-- *.asa
    |   `-- *.journal
    |
    |-- samples/
    |   `-- feature-tour.sql
    |
    |-- START_ASADB.bat
    |-- START_ASADB_NO_BROWSER.bat
    |-- RUN_CLI_SAMPLE.bat
    |-- LICENSE.md
    |-- SECURITY.md
    `-- README.md

## Release Notes

AsaDB v1.0.0 is the first public Windows release package.

This release focuses on:

    - portable local runtime
    - browser-based local panel
    - command-line execution path
    - local `.asa` database files
    - SQL feature tour sample
    - public package layout suitable for GitHub releases

## Verifying A Release Package

When downloading AsaDB from a release page, use the release archive provided by
the maintainer.

For release builds, a SHA256 checksum can be published together with the archive.
On Windows, a downloaded executable can be checked with:

    certutil -hashfile app\AsA.exe SHA256

Compare the output against the checksum published in the release notes.

Do not compare against a checksum from an untrusted mirror.

## Uploading This Package To GitHub

Use the public release folder as a new repository.

Do not initialize Git from the internal development project folder.

Example:

    cd "AsaDB-v1.0.0-Windows"
    git init
    git add .
    git commit -m "AsaDB v1.0.0 public release"
    git branch -M main
    git remote add origin https://github.com/USERNAME/REPO.git
    git push -u origin main

Before pushing, check the files that will be committed:

    git status
    git diff --cached --name-only

Make sure the commit does not include private database files, internal source
files, test fixtures, or development-only tools.

## Contact

Bug reports, feature requests, and usage questions can be opened through the
GitHub issue tracker for the public release repository.

For security-related reports, follow the instructions in:

    SECURITY.md

Do not post private `.asa` databases, private journals, access credentials, or
sensitive user data in public issues.

## License

See:

    LICENSE.md

## Maintainer

AsaDB is built and maintained by Aires Zam Wibisono.

The project provides a portable local database runtime, a browser-based local
panel, and a Prolog-backed engine packaged for Windows.
