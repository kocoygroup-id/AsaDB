# Third-Party Notices

AsaDB can be built with and distributed alongside third-party components. Their
licenses remain independent from the AsaDB GPL license.

## SWI-Prolog

AsaDB uses the SWI-Prolog runtime. SWI-Prolog is primarily distributed under
the Simplified BSD License. A copy of the runtime license used by the current
development environment is stored at
`licenses/SWI-Prolog-BSD-2-Clause.txt`.

SWI-Prolog distributions can load or bundle optional libraries with additional
license terms. Anyone preparing a binary distribution must audit the exact
runtime and libraries included in that build and reproduce all required notices.

Official license information:
https://www.swi-prolog.org/license.html

## AsaDB Media

The following project-owned media are distributed with AsaDB under
GPL-3.0-only as part of this repository:

- `web/assets/asadb-logo.png`;
- `web/assets/Icon/save.png`;
- `web/assets/Icon/tong_sampah.png`;
- success and failure audio under `web/assets/Effect/`.

Use of the AsaDB name and logo to identify a modified distribution is also
subject to `TRADEMARKS.md`.

## Adding Dependencies or Assets

Contributors must document the source, author, version, and license of every new
dependency or externally sourced asset. Do not add files whose redistribution
rights cannot be verified.
