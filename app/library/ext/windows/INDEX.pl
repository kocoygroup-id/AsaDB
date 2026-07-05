/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(registry_get_key(?,?), win_registry, registry).
index(registry_get_key(?,?,?), win_registry, registry).
index(registry_set_key(?,?), win_registry, registry).
index(registry_set_key(?,?,?), win_registry, registry).
index(registry_delete_key(?), win_registry, registry).
index(registry_lookup_key(?,?,?), win_registry, registry).
index(win_flush_filetypes, win_registry, registry).
index(shell_register_file_type(?,?,?,?), win_registry, registry).
index(shell_register_file_type(?,?,?,?,?), win_registry, registry).
index(shell_register_dde(?,?,?,?,?,?), win_registry, registry).
index(shell_register_prolog(?), win_registry, registry).
