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

## Babel Helpers and Regenerator Runtime

`web/assets/app.legacy.js` is generated with `@babel/core` and
`@babel/preset-env` version 7.26.0. Its checked-in output includes Babel helper
and regenerator-runtime code, which is available under the MIT License. The
runtime retains its license marker in the generated file. Babel is a build-time
dependency only; no Node.js or Babel installation is required to run AsaDB.

Official license information:
https://github.com/babel/babel/blob/main/LICENSE

## Noto Sans JP

AsAPanel includes the regular Japanese subset of Noto Sans JP version 5.3.0 in
WOFF2 and WOFF form at `web/assets/fonts/`. It is loaded only when the JP
interface is selected, so minimal Linux systems can render Japanese without a
system font package. Noto Sans JP is copyright Google Inc. and distributed
under the SIL Open Font License 1.1. The complete license is included at
`licenses/Noto-Sans-JP-OFL-1.1.txt`.

Source package:
https://www.npmjs.com/package/@fontsource/noto-sans-jp

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
