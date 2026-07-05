/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(doc_save(?,?), pldoc_files, doc_files).
index(doc_pack(?), pldoc_files, doc_files).
index(doc_enable(?), pldoc_http, doc_http).
index(doc_server(?), pldoc_http, doc_http).
index(doc_server(?,?), pldoc_http, doc_http).
index(doc_browser, pldoc_http, doc_http).
index(doc_browser(?), pldoc_http, doc_http).
index(doc_latex(?,?,?), pldoc_latex, doc_latex).
index(latex_for_file(?,?,?), pldoc_latex, doc_latex).
index(latex_for_wiki_file(?,?,?), pldoc_latex, doc_latex).
index(latex_for_predicates(?,?,?), pldoc_latex, doc_latex).
index(print_markdown(?,?), pldoc_markdown, doc_markdown).
index(doc_collect(?), pldoc, pldoc).
index(pldoc_loading, pldoc, pldoc).
