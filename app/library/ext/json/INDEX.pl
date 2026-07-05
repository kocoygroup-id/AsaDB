/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(json_read(?,?), json, json).
index(json_read(?,?,?), json, json).
index(atom_json_term(?,?,?), json, json).
index(json_write(?,?), json, json).
index(json_write(?,?,?), json, json).
index(is_json_term(?), json, json).
index(is_json_term(?,?), json, json).
index(json_read_dict(?,?), json, json).
index(json_read_dict(?,?,?), json, json).
index(json_write_dict(?,?), json, json).
index(json_write_dict(?,?,?), json, json).
index(atom_json_dict(?,?,?), json, json).
index(json(?,?,?,?), json, json).
index(prolog_to_json(:,-), json_convert, json_convert).
index(json_to_prolog(+,:), json_convert, json_convert).
index(json_object(?), json_convert, json_convert).
index(:(op,op(1150,fx,json_object)), json_convert, json_convert).
index(json_token(?,?,?), json_grammar, json_grammar).
index(json_call(+,+,-,:), json_rpc_client, json_rpc_client).
index(json_notify(?,?,?), json_rpc_client, json_rpc_client).
index(json_batch(?,?,?,?,?), json_rpc_client, json_rpc_client).
index(json_full_duplex(+,:), json_rpc_client, json_rpc_client).
index(json_rpc_send(?,?,?), json_rpc_common, json_rpc_common).
index(json_method(?), json_rpc_server, json_rpc_server).
index(json_rpc_dispatch(:,+), json_rpc_server, json_rpc_server).
index(json_rpc_error(?,?), json_rpc_server, json_rpc_server).
index(json_rpc_error(?,?,?), json_rpc_server, json_rpc_server).
index(:(op,op(1100,fx,json_method)), json_rpc_server, json_rpc_server).
index(json_validate(?,?,?), json_schema, json_schema).
index(json_compile_schema(?,?,?), json_schema, json_schema).
index(json_check(?,?,?), json_schema, json_schema).
