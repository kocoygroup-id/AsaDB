/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(load_rdf(?,?), rdf, rdf).
index(load_rdf(+,-,:), rdf, rdf).
index(xml_to_rdf(?,?,?), rdf, rdf).
index(process_rdf(+,:,:), rdf, rdf).
index(rdf_diagram_from_file(?), rdf_diagram, rdf_diagram).
index(xml_to_plrdf(?,?,?), rdf_parser, rdf_parser).
index(element_to_plrdf(?,?,?), rdf_parser, rdf_parser).
index(make_rdf_state(?,?,?), rdf_parser, rdf_parser).
index(rdf_modify_state(?,?,?), rdf_parser, rdf_parser).
index(rdf_name_space(?), rdf_parser, rdf_parser).
index(rdf_triples(?,?), rdf_triple, rdf_triple).
index(rdf_triples(?,?,?), rdf_triple, rdf_triple).
index(rdf_reset_ids, rdf_triple, rdf_triple).
index(rdf_start_file(?,?), rdf_triple, rdf_triple).
index(rdf_end_file(?), rdf_triple, rdf_triple).
index(anon_prefix(?), rdf_triple, rdf_triple).
index(rdf_write_xml(?,?), rdf_write, rdf_write).
index(rewrite_term(1,+), rewrite_term, rewrite_term).
index(rew_term_expansion(?,?), rewrite_term, rewrite_term).
index(rew_goal_expansion(?,?), rewrite_term, rewrite_term).
index(:(op,op(1200,xfx,::=)), rewrite_term, rewrite_term).
