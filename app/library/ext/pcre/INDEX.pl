/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(re_match(?,?), pcre, pcre).
index(re_match(?,?,?), pcre, pcre).
index(re_matchsub(?,?,?), pcre, pcre).
index(re_matchsub(?,?,?,?), pcre, pcre).
index(re_foldl(3,+,+,?,?,+), pcre, pcre).
index(re_split(?,?,?), pcre, pcre).
index(re_split(?,?,?,?), pcre, pcre).
index(re_replace(?,?,?,?), pcre, pcre).
index(re_replace(?,?,?,?,?), pcre, pcre).
index(re_compile(?,?,?), pcre, pcre).
index(re_flush, pcre, pcre).
index(re_config(?), pcre, pcre).
