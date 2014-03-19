SimpleIncludes

#define jsnum(%x)    ##class(%CDEV.JSON.Number).%New(%x)
#define jsnull       ##class(%CDEV.JSON.Null).%New()
#define jstrue       ##class(%CDEV.JSON.Boolean).%New(1)
#define jsfalse      ##class(%CDEV.JSON.Boolean).%New(0)
#define jsbool(%x)   ##class(%CDEV.JSON.Boolean).%New(%x)
#define jsobj        ##class(%CDEV.JSON.Object).%New()
#define jslist       ##class(%CDEV.JSON.List).%New()
#define jsstream(%x) ##class(%CDEV.JSON.Stream).%New(%x)