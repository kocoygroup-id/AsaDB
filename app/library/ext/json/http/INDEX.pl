/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(reply_json(?), http_json, http_json).
index(reply_json(?,?), http_json, http_json).
index(reply_json_dict(?), http_json, http_json).
index(reply_json_dict(?,?), http_json, http_json).
index(http_read_json(?,?), http_json, http_json).
index(http_read_json(?,?,?), http_json, http_json).
index(http_read_json_dict(?,?), http_json, http_json).
index(http_read_json_dict(?,?,?), http_json, http_json).
index(is_json_content_type(?), http_json, http_json).
index(:(public,json_type(_)), http_json, http_json).
index(js_token(?,?,?), js_grammar_compat, js_grammar).
