% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
%
% SWI-Prolog pack manifest.  This file intentionally lives at the repository
% root: `swipl pack install` requires `pack.pl` at the root of an archive or
% Git checkout.  `pack/pack.pl` is kept as an identical discoverability copy.

name(asadb).
title('AsaDB local SQL database engine').
version('1.5.0').
author('Kocoy Group', 'https://github.com/kocoygroup-id').
maintainer('Kocoy Group', 'https://github.com/kocoygroup-id').
packager('Kocoy Group', 'https://github.com/kocoygroup-id').
pack_version(1).
home('https://github.com/kocoygroup-id/AsaDB').
download('https://github.com/kocoygroup-id/AsaDB.git').
% Pack applications (`swipl asadb`) were added in SWI-Prolog 9.1.18.
requires(prolog >= '9.1.18').
provides(asadb_sql).
keywords([database, sql, prolog, local, storage, backup, interchange]).
description([
    'One Pack, Two Modes: local SQL engine, web workspace, and Flask server.',
    'Provides a documented Prolog API for embedded use and the complete',
    'AsaDB CLI, AsAPanel, offline Python wheelhouse, and server source tree.'
]).
