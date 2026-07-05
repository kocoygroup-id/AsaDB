/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(double_metaphone(?,?), double_metaphone, double_metaphone).
index(double_metaphone(?,?,?), double_metaphone, double_metaphone).
index(isub(?,?,?,?), isub, isub).
index('$isub'(?,?,?,?,?), isub, isub).
index(porter_stem(?,?), porter_stem, porter_stem).
index(unaccent_atom(?,?), porter_stem, porter_stem).
index(tokenize_atom(?,?), porter_stem, porter_stem).
index(atom_to_stem_list(?,?), porter_stem, porter_stem).
index(snowball(?,?,?), snowball, snowball).
index(snowball_current_algorithm(?), snowball, snowball).
