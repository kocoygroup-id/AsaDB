/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(format_paragraph(?,?), text_format, format).
index(trim_line(?,?), text_format, format).
index(element_css(?,?,?), format_style, html_style).
index(css_block_options(?,?,?,?,?), format_style, html_style).
index(css_inline_options(?,?,?), format_style, html_style).
index(attrs_classes(?,?), format_style, html_style).
index(style_css_attrs(?,?), format_style, html_style).
index(html_text(?), html_text, html_text).
index(html_text(?,?), html_text, html_text).
