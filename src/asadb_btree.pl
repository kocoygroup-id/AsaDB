% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_btree, [
    asadb_btree_build/2,
    asadb_btree_lookup/3,
    asadb_btree_range/4,
    asadb_btree_stats/2,
    asadb_btree_file_build/3,
    asadb_btree_file_build_stream/4,
    asadb_btree_file_candidate/4,
    asadb_btree_file_ordered_rid/3,
    asadb_btree_file_ordered_rids/3,
    asadb_btree_file_stats/2
]).

:- use_module(library(utf8)).
:- use_module(library(filesex)).
:- use_module('asadb_pager.pl').
:- use_module('asadb_page_manager.pl').

:- meta_predicate asadb_btree_file_build_stream(+, ?, 0, -).

leaf_capacity(64).
branch_capacity(32).

asadb_btree_build(RawEntries, btree(Count, Root)) :-
    raw_entries_to_pairs(RawEntries, Pairs),
    keysort(Pairs, Sorted),
    group_sorted_pairs(Sorted, Groups),
    length(Groups, Count),
    build_leaf_level(Groups, Leaves),
    build_tree_level(Leaves, Root).

asadb_btree_lookup(btree(_, Root), RawKey, Rows) :-
    canonical_key(RawKey, Key),
    btree_lookup_node(Root, Key, Rows), !.
asadb_btree_lookup(_, _, []).

asadb_btree_range(btree(_, Root), Op, RawKey, Rows) :-
    canonical_key(RawKey, Key),
    btree_range_node(Root, Op, Key, Nested),
    append(Nested, Rows), !.
asadb_btree_range(_, _, _, []).

asadb_btree_stats(btree(Keys, Root), btree_stats{keys:Keys, height:Height}) :-
    node_height(Root, Height).

raw_entries_to_pairs([], []).
raw_entries_to_pairs([RawKey-Row|Entries], [Key-row_value(RawKey, Row)|Pairs]) :-
    canonical_key(RawKey, Key),
    raw_entries_to_pairs(Entries, Pairs).

canonical_key(null, null) :- !.
canonical_key(Value, number(Number)) :-
    number(Value), !,
    Number is Value.
canonical_key(Value, number(Number)) :-
    atom(Value),
    atom_number(Value, Number), !.
canonical_key(Value, text(Lower)) :-
    atom(Value), !,
    downcase_atom(Value, Lower).
canonical_key(Value, text(Lower)) :-
    string(Value), !,
    string_lower(Value, LowerString),
    atom_string(Lower, LowerString).
canonical_key(Value, term(Value)).

group_sorted_pairs([], []).
group_sorted_pairs([Key-row_value(Raw, Row)|Pairs], [k(Key, Raw, Rows)|Groups]) :-
    take_same_key(Key, Pairs, Rest, [Row], RevRows),
    reverse(RevRows, Rows),
    group_sorted_pairs(Rest, Groups).

take_same_key(Key, [Key-row_value(_, Row)|Pairs], Rest, Acc, Rows) :- !,
    take_same_key(Key, Pairs, Rest, [Row|Acc], Rows).
take_same_key(_, Rest, Rest, Rows, Rows).

build_leaf_level([], [leaf(null, null, [])]) :- !.
build_leaf_level(Groups, Leaves) :-
    leaf_capacity(Size),
    chunk_list(Size, Groups, Chunks),
    groups_to_leaves(Chunks, Leaves).

groups_to_leaves([], []).
groups_to_leaves([Groups|Chunks], [leaf(First, Last, Groups)|Leaves]) :-
    Groups = [k(First, _, _)|_],
    last(Groups, k(Last, _, _)),
    groups_to_leaves(Chunks, Leaves).

build_tree_level([Root], Root) :- !.
build_tree_level(Nodes, Root) :-
    branch_capacity(Size),
    chunk_list(Size, Nodes, Chunks),
    chunks_to_branches(Chunks, Parents),
    build_tree_level(Parents, Root).

chunks_to_branches([], []).
chunks_to_branches([Children|Chunks], [node(First, Last, Children)|Parents]) :-
    Children = [FirstChild|_],
    node_bounds(FirstChild, First, _),
    last(Children, LastChild),
    node_bounds(LastChild, _, Last),
    chunks_to_branches(Chunks, Parents).

btree_lookup_node(leaf(_, _, Groups), Key, Rows) :-
    member(k(Key, _, Rows), Groups), !.
btree_lookup_node(leaf(_, _, _), _, []).
btree_lookup_node(node(_, _, Children), Key, Rows) :-
    child_for_key(Key, Children, Child), !,
    btree_lookup_node(Child, Key, Rows).
btree_lookup_node(node(_, _, _), _, []).

child_for_key(Key, [Child|_], Child) :-
    node_bounds(Child, First, Last),
    key_between(Key, First, Last), !.
child_for_key(Key, [_|Children], Child) :-
    child_for_key(Key, Children, Child).

btree_range_node(leaf(_, _, Groups), Op, Key, Rows) :-
    include_group_range(Op, Key, Groups, Rows).
btree_range_node(node(_, _, Children), Op, Key, Rows) :-
    include_children_range(Op, Key, Children, Rows).

include_children_range(_, _, [], []).
include_children_range(Op, Key, [Child|Children], Rows) :-
    ( node_may_match(Op, Key, Child)
    -> btree_range_node(Child, Op, Key, Head),
       include_children_range(Op, Key, Children, Tail),
       append(Head, Tail, Rows)
    ;  include_children_range(Op, Key, Children, Rows)
    ).

include_group_range(_, _, [], []).
include_group_range(Op, Key, [k(GroupKey, _, GroupRows)|Groups], Rows) :-
    ( key_matches(Op, GroupKey, Key)
    -> include_group_range(Op, Key, Groups, Tail),
       Rows = [GroupRows|Tail]
    ;  include_group_range(Op, Key, Groups, Rows)
    ).

node_may_match(Op, Key, Node) :-
    node_bounds(Node, First, Last),
    node_range_may_match(Op, Key, First, Last).

node_range_may_match('=', Key, First, Last) :- key_between(Key, First, Last).
node_range_may_match('>', Key, _, Last) :- compare(>, Last, Key).
node_range_may_match('>=', Key, _, Last) :- compare(C, Last, Key), member(C, [>, =]).
node_range_may_match('<', Key, First, _) :- compare(<, First, Key).
node_range_may_match('<=', Key, First, _) :- compare(C, First, Key), member(C, [<, =]).

key_matches('=', A, B) :- A == B.
key_matches('>', A, B) :- compare(>, A, B).
key_matches('>=', A, B) :- compare(C, A, B), member(C, [>, =]).
key_matches('<', A, B) :- compare(<, A, B).
key_matches('<=', A, B) :- compare(C, A, B), member(C, [<, =]).

key_between(Key, First, Last) :-
    compare(C1, Key, First),
    member(C1, [>, =]),
    compare(C2, Key, Last),
    member(C2, [<, =]).

node_bounds(leaf(First, Last, _), First, Last).
node_bounds(node(First, Last, _), First, Last).

node_height(leaf(_, _, _), 1).
node_height(node(_, _, [Child|_]), Height) :-
    node_height(Child, ChildHeight),
    Height is ChildHeight + 1.

chunk_list(_, [], []) :- !.
chunk_list(Size, List, [Chunk|Chunks]) :-
    take_chunk(Size, List, Chunk, Rest),
    chunk_list(Size, Rest, Chunks).

take_chunk(0, Rest, [], Rest) :- !.
take_chunk(_, [], [], []) :- !.
take_chunk(N, [Item|Items], [Item|Chunk], Rest) :-
    N > 0,
    N1 is N - 1,
    take_chunk(N1, Items, Chunk, Rest).

/* Persistent page-backed B+Tree. Page 0 stores the root metadata. */

asadb_btree_file_build(File, RawEntries, Stats) :-
    RawEntries == [], !,
    prepare_empty_file(File, Temp),
    asadb_page_build(1, btree_leaf, none, none, [], LeafPage),
    asadb_pager_write_page(Temp, 1, LeafPage),
    term_record_bytes(btree_meta(1, 1, 0, 1), MetaBytes),
    asadb_page_build(0, btree_internal, none, none, [MetaBytes], MetaPage),
    asadb_pager_write_page(Temp, 0, MetaPage),
    asadb_pager_flush,
    replace_index_file(File, Temp),
    Stats = btree_file_stats{keys:0,height:1,leaf_pages:1,root_page:1}.
asadb_btree_file_build(File, RawEntries, Stats) :-
    raw_entries_to_pairs(RawEntries, Pairs),
    keysort(Pairs, Sorted),
    group_sorted_pairs(Sorted, Groups),
    maplist(term_record_bytes, Groups, LeafRecords),
    pack_page_records(LeafRecords, LeafChunks),
    length(LeafChunks, LeafCount),
    prepare_empty_file(File, Temp),
    write_leaf_chunks(LeafChunks, Temp, 1, LeafCount, LeafDescriptors, NextPage),
    length(Groups, KeyCount),
    build_persistent_levels(LeafDescriptors, Temp, NextPage, 1,
                            RootPage, Height, _),
    term_record_bytes(btree_meta(RootPage, Height, KeyCount, LeafCount), MetaBytes),
    asadb_page_build(0, btree_internal, none, none, [MetaBytes], MetaPage),
    asadb_pager_write_page(Temp, 0, MetaPage),
    asadb_pager_flush,
    replace_index_file(File, Temp),
    Stats = btree_file_stats{keys:KeyCount,height:Height,leaf_pages:LeafCount,root_page:RootPage}.

/* External bulk builder. Only one bounded run and one record per run are kept
   in memory while the final leaf chain is written. */
asadb_btree_file_build_stream(File, Pair, Goal, Stats) :-
    btree_run_directory(File, RunDir),
    setup_call_cleanup(
        prepare_run_directory(RunDir),
        setup_call_cleanup(
            engine_create(Pair, Goal, Engine),
            ( write_sorted_runs(Engine, RunDir, 0, RunFiles),
              build_file_from_runs(File, RunFiles, Stats)
            ),
            catch(engine_destroy(Engine), _, true)
        ),
        delete_directory_and_contents(RunDir)
    ).

btree_run_chunk_size(2048).

btree_run_directory(File, RunDir) :- atom_concat(File, '.runs', RunDir).

prepare_run_directory(RunDir) :-
    ( exists_directory(RunDir) -> delete_directory_and_contents(RunDir) ; true ),
    make_directory_path(RunDir).

write_sorted_runs(Engine, RunDir, RunNo, RunFiles) :-
    btree_run_chunk_size(Size),
    collect_engine_pairs(Engine, Size, RawPairs, Exhausted),
    ( RawPairs == [] ->
        RunFiles = []
    ; maplist(normalize_stream_pair, RawPairs, Pairs),
      keysort(Pairs, Sorted),
      format(atom(Name), 'run-~|~`0t~d~6+.terms', [RunNo]),
      directory_file_path(RunDir, Name, RunFile),
      write_run_file(RunFile, Sorted),
      RunFiles = [RunFile|Rest],
      ( Exhausted == true -> Rest = []
      ; Next is RunNo + 1,
        write_sorted_runs(Engine, RunDir, Next, Rest)
      )
    ).

collect_engine_pairs(_, 0, [], false) :- !.
collect_engine_pairs(Engine, Count, Pairs, Exhausted) :-
    ( engine_next(Engine, Pair) ->
        Pairs = [Pair|Rest],
        Next is Count - 1,
        collect_engine_pairs(Engine, Next, Rest, Exhausted)
    ; Pairs = [], Exhausted = true
    ).

normalize_stream_pair(RawKey-Rid, Key-row_value(RawKey, Rid)) :-
    canonical_key(RawKey, Key).

write_run_file(File, Pairs) :-
    setup_call_cleanup(
        open(File, write, Stream, [encoding(utf8)]),
        forall(member(Pair, Pairs),
               ( write_canonical(Stream, Pair), write(Stream, '.\n') )),
        close(Stream)
    ).

build_file_from_runs(File, [], Stats) :- !,
    asadb_btree_file_build(File, [], Stats).
build_file_from_runs(File, RunFiles, Stats) :-
    prepare_empty_file(File, Temp),
    setup_call_cleanup(
        open_run_states(RunFiles, States),
        merge_run_states(States, Temp, LeafDescriptors, KeyCount, LeafCount),
        close_run_states(States)
    ),
    NextPage is LeafCount + 1,
    build_persistent_levels(LeafDescriptors, Temp, NextPage, 1,
                            RootPage, Height, _),
    term_record_bytes(btree_meta(RootPage, Height, KeyCount, LeafCount), MetaBytes),
    asadb_page_build(0, btree_internal, none, none, [MetaBytes], MetaPage),
    asadb_pager_write_page(Temp, 0, MetaPage),
    asadb_pager_flush,
    replace_index_file(File, Temp),
    Stats = btree_file_stats{keys:KeyCount,height:Height,
                             leaf_pages:LeafCount,root_page:RootPage}.

open_run_states([], []).
open_run_states([File|Files], States) :-
    open(File, read, Stream, [encoding(utf8)]),
    read_term(Stream, Term, []),
    ( Term == end_of_file ->
        close(Stream),
        open_run_states(Files, States)
    ; States = [run(Stream,Term)|Rest],
      open_run_states(Files, Rest)
    ).

close_run_states([]).
close_run_states([run(Stream,_)|States]) :-
    catch(close(Stream), _, true),
    close_run_states(States).

merge_run_states(States0, File, Descriptors, KeyCount, LeafCount) :-
    Leaf0 = leaf_acc(1, none, [], 32, [], 0),
    merge_run_pairs(States0, none, File, Leaf0, Leaf, States),
    close_run_states(States),
    finish_leaf_acc(File, Leaf, Descriptors, KeyCount, LeafCount).

merge_run_pairs([], Group, File, Leaf0, Leaf, []) :- !,
    flush_key_group(Group, File, Leaf0, Leaf).
merge_run_pairs(States0, Group0, File, Leaf0, Leaf, States) :-
    pop_smallest_run(States0, Pair, States1),
    Pair = Key-row_value(RawKey, Rid),
    ( Group0 = group(Key, GroupRaw, Rids0) ->
        Group = group(Key, GroupRaw, [Rid|Rids0]),
        Leaf1 = Leaf0
    ; flush_key_group(Group0, File, Leaf0, Leaf1),
      Group = group(Key, RawKey, [Rid])
    ),
    merge_run_pairs(States1, Group, File, Leaf1, Leaf, States).

pop_smallest_run(States0, Pair, States) :-
    select_smallest_run(States0, Smallest, Others),
    Smallest = run(Stream, Pair),
    read_term(Stream, Next, []),
    ( Next == end_of_file ->
        close(Stream), States = Others
    ; States = [run(Stream,Next)|Others]
    ).

select_smallest_run([Run|Runs], Smallest, Others) :-
    select_smallest_run_(Runs, Run, [], Smallest, Others).

select_smallest_run_([], Smallest, Acc, Smallest, Others) :- reverse(Acc, Others).
select_smallest_run_([Run|Runs], Current, Acc, Smallest, Others) :-
    run_pair_key(Run, Key),
    run_pair_key(Current, CurrentKey),
    ( compare(<, Key, CurrentKey) ->
        select_smallest_run_(Runs, Run, [Current|Acc], Smallest, Others)
    ; select_smallest_run_(Runs, Current, [Run|Acc], Smallest, Others)
    ).

run_pair_key(run(_, Key-_), Key).

flush_key_group(none, _, Leaf, Leaf) :- !.
flush_key_group(group(Key, RawKey, Rids0), File, Leaf0, Leaf) :-
    reverse(Rids0, Rids),
    term_record_bytes(k(Key, RawKey, Rids), Bytes),
    add_leaf_record(File, Bytes, Leaf0, Leaf).

add_leaf_record(File, Bytes,
                leaf_acc(PageNo, Prev, Records0, Used0, Descs0, Keys0), Leaf) :-
    length(Bytes, Length),
    Used is Used0 + Length + 4,
    asadb_pager_page_size(PageSize),
    ( Used =< PageSize ->
        Leaf = leaf_acc(PageNo, Prev, [Bytes|Records0], Used, Descs0, Keys1)
    ; Records0 \== [],
      NextNo is PageNo + 1,
      write_leaf_acc_page(File, PageNo, Prev, NextNo, Records0, Descriptor),
      NewUsed is 32 + Length + 4,
      Leaf = leaf_acc(NextNo, PageNo, [Bytes], NewUsed,
                      [Descriptor|Descs0], Keys1)
    ),
    Keys1 is Keys0 + 1.

finish_leaf_acc(File, leaf_acc(PageNo, Prev, Records, _, Descs0, KeyCount),
                Descriptors, KeyCount, LeafCount) :-
    write_leaf_acc_page(File, PageNo, Prev, none, Records, Descriptor),
    reverse([Descriptor|Descs0], Descriptors),
    length(Descriptors, LeafCount).

write_leaf_acc_page(File, PageNo, Prev, Next, RecordsRev, Descriptor) :-
    reverse(RecordsRev, Records),
    records_bounds(Records, First, Last),
    asadb_page_build(PageNo, btree_leaf, Prev, Next, Records, Page),
    asadb_pager_write_page(File, PageNo, Page),
    Descriptor = child(First, Last, PageNo).

write_leaf_chunks([], _, Next, _, [], Next).
write_leaf_chunks([Records|Chunks], File, PageNo, LeafCount,
                  [child(First,Last,PageNo)|Descriptors], NextPage) :-
    records_bounds(Records, First, Last),
    ( PageNo =:= 1 -> Prev = none ; Prev is PageNo - 1 ),
    ( PageNo >= LeafCount -> Next = none ; Next is PageNo + 1 ),
    asadb_page_build(PageNo, btree_leaf, Prev, Next, Records, Page),
    asadb_pager_write_page(File, PageNo, Page),
    Page1 is PageNo + 1,
    write_leaf_chunks(Chunks, File, Page1, LeafCount, Descriptors, NextPage).

build_persistent_levels([child(_,_,Root)], _, Next, Height, Root, Height, Next) :- !.
build_persistent_levels(Descriptors, File, PageStart, Height0, Root, Height, NextPage) :-
    maplist(term_record_bytes, Descriptors, Records),
    pack_page_records(Records, Chunks),
    write_internal_chunks(Chunks, File, PageStart, Parents, Next0),
    Height1 is Height0 + 1,
    build_persistent_levels(Parents, File, Next0, Height1, Root, Height, NextPage).

write_internal_chunks([], _, Next, [], Next).
write_internal_chunks([Records|Chunks], File, PageNo,
                      [child(First,Last,PageNo)|Parents], NextPage) :-
    records_bounds(Records, First, Last),
    asadb_page_build(PageNo, btree_internal, none, none, Records, Page),
    asadb_pager_write_page(File, PageNo, Page),
    Page1 is PageNo + 1,
    write_internal_chunks(Chunks, File, Page1, Parents, NextPage).

records_bounds([FirstBytes|Records], First, Last) :-
    record_term(FirstBytes, FirstTerm),
    term_bounds(FirstTerm, First, _),
    last([FirstBytes|Records], LastBytes),
    record_term(LastBytes, LastTerm),
    term_bounds(LastTerm, _, Last).

term_bounds(k(Key, _, _), Key, Key).
term_bounds(child(First, Last, _), First, Last).

pack_page_records([], []) :- !.
pack_page_records(Records, [Chunk|Chunks]) :-
    take_page_records(Records, [], Chunk, Rest),
    Chunk \== [],
    pack_page_records(Rest, Chunks).

take_page_records([], Acc, Chunk, []) :- !, reverse(Acc, Chunk).
take_page_records([Record|Records], Acc, Chunk, Rest) :-
    reverse([Record|Acc], Candidate),
    page_records_fit(Candidate), !,
    take_page_records(Records, [Record|Acc], Chunk, Rest).
take_page_records(Rest, Acc, Chunk, Rest) :- reverse(Acc, Chunk).

page_records_fit(Records) :-
    length(Records, Count),
    records_bytes_length(Records, Payload),
    asadb_pager_page_size(PageSize),
    32 + Count * 4 + Payload =< PageSize.

records_bytes_length([], 0).
records_bytes_length([Bytes|Records], Total) :-
    length(Bytes, Length),
    records_bytes_length(Records, Rest),
    Total is Length + Rest.

asadb_btree_file_candidate(File, '=', RawKey, Rid) :- !,
    canonical_key(RawKey, Key),
    btree_file_meta(File, Root, _, _, _),
    descend_file_tree(File, Root, Key, LeafPage),
    page_terms(File, LeafPage, Terms),
    member(k(Key, _, Rids), Terms),
    member(Rid, Rids).
asadb_btree_file_candidate(File, Op, RawKey, Rid) :-
    canonical_key(RawKey, Key),
    btree_file_meta(File, Root, _, _, _),
    range_start_leaf(File, Root, Op, Key, LeafPage),
    btree_leaf_range_candidate(File, LeafPage, Op, Key, Rid).

range_start_leaf(_, _, Op, _, 1) :- memberchk(Op, ['<','<=']), !.
range_start_leaf(File, Root, _, Key, LeafPage) :-
    descend_file_tree(File, Root, Key, LeafPage).

btree_leaf_range_candidate(File, PageNo, Op, Key, Rid) :-
    asadb_pager_read_page(File, PageNo, Page),
    asadb_page_validate(Page),
    asadb_page_header(Page, Meta),
    page_record_terms(Page, Terms),
    ( member(k(GroupKey, _, Rids), Terms),
      key_matches(Op, GroupKey, Key),
      member(Rid, Rids)
    ; range_may_continue(Op, Key, Terms),
      Meta.next_page \== none,
      btree_leaf_range_candidate(File, Meta.next_page, Op, Key, Rid)
    ).

asadb_btree_file_ordered_rid(File, asc, Rid) :-
    btree_ordered_leaf(File, 1, asc, Rid).
asadb_btree_file_ordered_rid(File, desc, Rid) :-
    btree_file_meta(File, _, _, _, LeafCount),
    btree_ordered_leaf(File, LeafCount, desc, Rid).

asadb_btree_file_ordered_rids(File, asc, Rids) :-
    btree_ordered_leaf_rids(File, 1, asc, Rids).
asadb_btree_file_ordered_rids(File, desc, Rids) :-
    btree_file_meta(File, _, _, _, LeafCount),
    btree_ordered_leaf_rids(File, LeafCount, desc, Rids).

btree_ordered_leaf_rids(File, PageNo, Direction, Rids) :-
    asadb_pager_read_page(File, PageNo, Page),
    asadb_page_validate(Page),
    asadb_page_header(Page, Meta),
    page_record_terms(Page, Terms0),
    orient_leaf_terms(Direction, Terms0, Terms),
    terms_ordered_rids(Terms, Direction, CurrentRids),
    ( CurrentRids \== [], Rids = CurrentRids
    ; ordered_sibling(Direction, Meta, Sibling),
      Sibling \== none,
      btree_ordered_leaf_rids(File, Sibling, Direction, Rids)
    ).

terms_ordered_rids([], _, []).
terms_ordered_rids([k(_, _, Group0)|Terms], Direction, Rids) :-
    orient_leaf_terms(Direction, Group0, Group),
    terms_ordered_rids(Terms, Direction, Rest),
    append(Group, Rest, Rids).

btree_ordered_leaf(File, PageNo, Direction, Rid) :-
    asadb_pager_read_page(File, PageNo, Page),
    asadb_page_validate(Page),
    asadb_page_header(Page, Meta),
    page_record_terms(Page, Terms0),
    orient_leaf_terms(Direction, Terms0, Terms),
    ( member(k(_, _, Rids0), Terms),
      orient_leaf_terms(Direction, Rids0, Rids),
      member(Rid, Rids)
    ; ordered_sibling(Direction, Meta, Sibling),
      Sibling \== none,
      btree_ordered_leaf(File, Sibling, Direction, Rid)
    ).

orient_leaf_terms(desc, Values, Oriented) :- !, reverse(Values, Oriented).
orient_leaf_terms(_, Values, Values).

ordered_sibling(desc, Meta, Sibling) :- !, Sibling = Meta.previous_page.
ordered_sibling(_, Meta, Sibling) :- Sibling = Meta.next_page.

range_may_continue(Op, _, _) :- memberchk(Op, ['>','>=']), !.
range_may_continue(Op, Key, Terms) :-
    memberchk(Op, ['<','<=']),
    last(Terms, k(LastKey, _, _)),
    key_matches(Op, LastKey, Key).

descend_file_tree(File, PageNo, Key, LeafPage) :-
    asadb_pager_read_page(File, PageNo, Page),
    asadb_page_header(Page, Meta),
    ( Meta.page_type == btree_leaf -> LeafPage = PageNo
    ; page_record_terms(Page, Children),
      child_descriptor_for_key(Key, Children, Child),
      descend_file_tree(File, Child, Key, LeafPage)
    ).

child_descriptor_for_key(Key, [child(First,Last,Page)|_], Page) :-
    key_between(Key, First, Last), !.
child_descriptor_for_key(Key, [child(_,Last,Page)|[]], Page) :-
    compare(>, Key, Last), !.
child_descriptor_for_key(Key, [_|Children], Page) :-
    child_descriptor_for_key(Key, Children, Page).

asadb_btree_file_stats(File, Stats) :-
    btree_file_meta(File, Root, Height, Keys, LeafCount),
    asadb_pager_page_count(File, Pages),
    Stats = btree_file_stats{keys:Keys,height:Height,leaf_pages:LeafCount,
                             pages:Pages,root_page:Root}.

btree_file_meta(File, Root, Height, Keys, LeafCount) :-
    page_terms(File, 0, [btree_meta(Root, Height, Keys, LeafCount)|_]).

page_terms(File, PageNo, Terms) :-
    asadb_pager_read_page(File, PageNo, Page),
    asadb_page_validate(Page),
    page_record_terms(Page, Terms).

page_record_terms(Page, Terms) :-
    asadb_page_records(Page, Records),
    record_terms(Records, Terms).

record_terms([], []).
record_terms([_-Bytes|Records], [Term|Terms]) :-
    record_term(Bytes, Term),
    record_terms(Records, Terms).

term_record_bytes(Term, Bytes) :-
    with_output_to(codes(Codes), write_canonical(Term)),
    phrase(utf8_codes(Codes), Bytes).

record_term(Bytes, Term) :-
    phrase(utf8_codes(Codes), Bytes),
    read_term_from_codes(Codes, Term, []).

prepare_empty_file(File, Temp) :-
    atom_concat(File, '.tmp', Temp),
    asadb_pager_invalidate_file(Temp),
    delete_file_if_exists(Temp),
    file_directory_name(Temp, Dir),
    ensure_btree_directory(Dir),
    setup_call_cleanup(open(Temp, write, Stream, [type(binary)]), true, close(Stream)).

replace_index_file(File, Temp) :-
    asadb_pager_invalidate_file(File),
    asadb_pager_invalidate_file(Temp),
    atom_concat(File, '.bak', Backup),
    delete_file_if_exists(Backup),
    ( exists_file(File) -> rename_file(File, Backup) ; true ),
    catch((rename_file(Temp, File), delete_file_if_exists(Backup)), Error,
          ( delete_file_if_exists(File),
            ( exists_file(Backup) -> rename_file(Backup, File) ; true ),
            throw(Error) )).

delete_file_if_exists(File) :- ( exists_file(File) -> delete_file(File) ; true ).

ensure_btree_directory('.') :- !.
ensure_btree_directory('') :- !.
ensure_btree_directory(Dir) :- exists_directory(Dir), !.
ensure_btree_directory(Dir) :-
    file_directory_name(Dir, Parent),
    ensure_btree_directory(Parent),
    make_directory(Dir).
