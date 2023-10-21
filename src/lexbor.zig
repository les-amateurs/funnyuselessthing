const c_lexbor = @cImport({
    @cInclude("lexbor/core/types.h");
    @cInclude("lexbor/core/lexbor.h");
    @cInclude("lexbor/html/html.h");
    @cInclude("lexbor/dom/dom.h");
});

pub fn init() c_lexbor.lxb_status_t {
    return c_lexbor.lexbor_memory_setup(null, null, null, null);
}

pub const Html = struct {
    pub fn docCreate() ?*c_lexbor.lxb_html_document {
        return c_lexbor.lxb_html_document_create();
    }

    pub fn docParse(doc: *c_lexbor.lxb_html_document, html_src: [*:0]const u8, len: usize) c_lexbor.lxb_status_t {
        return c_lexbor.lxb_html_document_parse(doc, html_src, len);
    }

    pub fn docDestroy(doc: *c_lexbor.lxb_html_document) void {
        c_lexbor.lxb_html_document_destroy(doc);
    }
};
