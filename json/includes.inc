SimpleIncludes

#define jsnum(%x)    ##class(Simple.Number).%New(%x)
#define jsnull       ##class(Simple.Null).%New()
#define jstrue       ##class(Simple.Boolean).%New(1)
#define jsfalse      ##class(Simple.Boolean).%New(0)
#define jsbool(%x)   ##class(Simple.Boolean).%New(%x)