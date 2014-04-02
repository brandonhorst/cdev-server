Include %CDEV.JSON.Includes

Class %CDEV.Server Extends %CSP.REST
{

//Used to handle Namespace Switching. If a ClassMethod that ends in an N and does not exist is called, it will switch the NameSpace
//to the first argument, and call the classmethod with the same arguments, but without the N
ClassMethod %DispatchClassMethod(Class As %String, Method As %String, Args...)
{
    if $extract(Method, *) = "N"
    {
        s actualMethod = $extract(Method, 1, *-1)

        if $g(Args) {
            s namespace = Args(1)
            n $namespace
            s $namespace = namespace
        }
        s %response.ContentType = "application/json"
        s %input = ..GetRequest()
        s response = $classmethod(Class, actualMethod, Args...)
        d response.%WriteJSON()
        q $$$OK
    } else {
        q "Class Method Not Found"
    }
}

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/" Method="GET" Call="ListOptionsN" />
    <Route Url="/namespaces" Method="GET" Call="GetNamespaceListN" />
    <Route Url="/namespaces/:namespace" Method="GET" Call="GetNamespaceN" />

    <Route Url="/namespaces/:namespace/files" Method="GET" Call="GetFileListN" />
    <Route Url="/namespaces/:namespace/files" Method="PUT" Call="PutNewFileN" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="GET" Call="GetFileN" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="PUT" Call="PutFileN" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="POST" Call="FileActionN" />
    <Route Url="/namespaces/:namespace/files/:filename/generated" Method="GET" Call="GetFileGeneratedN" />

    <Route Url="/namespaces/:namespace/files/:filename/xml" Method="GET" Call="GetXMLN" />
    <Route Url="/namespaces/:namespace/files/:filename/xml" Method="PUT" Call="PutXMLN" />

    <Route Url="/namespaces/:namespace/xml" Method="PUT" Call="PutNewXMLN" />

    <Route Url="/namespaces/:namespace/globals" Method="GET" Call="GetGlobalListN" />
    <Route Url="/namespaces/:namespace/globals/:globalname" Method="GET" Call="GetGlobalN" />

    <Route Url="/namespaces/:namespace/queries" Method="GET" Call="GetQueryListN" />
    <Route Url="/namespaces/:namespace/queries" Method="PUT" Call="PutNewQueryN" />
    <Route Url="/namespaces/:namespace/queries/:query" Method="GET" Call="GetQueryN" />
    <Route Url="/namespaces/:namespace/queries/:query" Method="POST" Call="QueryActionN" />
    <Route Url="/namespaces/:namespace/queries/:query/plan" Method="GET" Call="GetQueryPlanN" />
    <Route Url="/namespaces/:namespace/queries/:query/cached" Method="GET" Call="GetQueryCachedN" />

    <Route Url="/namespaces/:namespace/code" Method="GET" Call="GetCodeListN" />
    <Route Url="/namespaces/:namespace/code" Method="PUT" Call="PutNewCodeN" />
    <Route Url="/namespaces/:namespace/code/:code" Method="GET" Call="GetCodeN" />
    <Route Url="/namespaces/:namespace/code/:code" Method="POST" Call="CodeActionN" />
</Routes>
}

ClassMethod ListOptions() As %Status
{
    s result = $$$jsobj
    s result.namespaces = ..CreatePath("namespaces")
    s result.version = "v0.0.3"

    q result
}

ClassMethod GetNamespaceList() As %Status
{
    s rs = ..DoSQL("%SYS.Namespace::List")
    s results = $$$jslist
    while rs.%Next()
    {
        if '$d(%request.Data("name", 1)) || (rs.%GetData(1) = $zcvt(%request.Data("name", 1), "U"))
        {
            s obj = ..NamespaceObject($zcvt(rs.%GetData(1), "L"))
            d results.Append(obj)
        }
    }

    q results
}

ClassMethod GetFileList(namespace As %String) As %Status
{
    s results = $$$jslist

    s sql = "SELECT Name||'.cls' FROM %Dictionary.ClassDefinition"
    s rs = ..DoSQL(sql)
    while rs.%Next() {
        s obj = $$$jsobj
        s obj.name = rs.%GetData(1)
        s obj.id = ..CreatePath("namespaces", namespace, "files", obj.name)
        d results.Append(obj)
    }
    s sql = "%Library.Routine::RoutineList"
    s rs = ..DoSQL(sql)
    while rs.%Next() {
        s obj = $$$jsobj
        s obj.name = ..FileName(rs.%GetData(1)) _ "." _ ..FileExtension(rs.%GetData(1))
        s obj.id = ..CreatePath("namespaces", namespace, "files", obj.name)
        d results.Append(obj)
    }

    q results
}

ClassMethod GetNamespace(namespace As %String) As %Status
{
    s result = ..NamespaceObject(namespace)

    q result
}

ClassMethod NamespaceObject(namespace As %String) As %CDEV.JSON.Object
{
    s obj = $$$jsobj

    s obj.id = ..CreatePath("namespaces", namespace)
    s obj.name = $zcvt(namespace, "U")
    s obj.files = ..CreatePath("namespaces", namespace, "files")
    s obj.globals = ..CreatePath("namespaces", namespace, "globals")
    s obj.xml = ..CreatePath("namespaces", namespace, "xml")
    s obj.queries = ..CreatePath("namespaces", namespace, "queries")

    q obj
}

ClassMethod FileObject(namespace As %String, filename As %String) As %CDEV.JSON.Object
{
    s obj = $$$jsobj

    if ..FileExtension(filename) = "cls"
    {
        s systemName = ..FileName(filename)
        if ##class(%Dictionary.ClassDefinition).%ExistsId(systemName)
        {
            d ##class(%Compiler.UDL.TextServices).GetTextAsStream(,..FileName(filename),.classStream) 
            s obj.content = $$$jsstream(classStream)
        } else {
            q ""
        }
    } else {
        s systemName = filename
        i ##class(%Routine).Exists(filename)
        {
            s routine = ##class(%Routine).%OpenId(filename)
            s obj.content = $$$jsstream(routine)
        } else {
            q ""
        }
    }

    s obj.id = ..CreatePath("namespaces", namespace, "files", filename)
    s obj.generatedfiles = obj.id _ "/generated"
    s obj.name = filename
    s obj.xml = ..CreatePath("namespaces", namespace, "files", filename, "xml")
    s obj.url = ..GetURLForClass(systemName)
    q obj
}

ClassMethod GetFile(namespace As %String, filename As %String) As %Status
{
    s result = ..FileObject(namespace, filename)

    q result
}

ClassMethod PutFile(namespace As %String, filename As %String) As %Status
{
    if ..FileExtension(filename) = "cls"
    {
        s systemName = ..FileName(filename)
        i $isobject(%input.content)
        {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromStream(,systemName,%input.content.Read()) 
        } else {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromString(,systemName,%input.content) 
        }
    } else {
        s trueName = ..FileName(filename) _ "." _ $zcvt(..FileExtension(filename), "U")
        if ##class(%Routine).Exists(trueName)
        {
            s routine = ##class(%Routine).%OpenId(trueName)
            d routine.Clear()
        } else {
            s routine = ##class(%Routine).%New(trueName)
        }
        i $isobject(%input.content)
        {
            d routine.CopyFrom(%input.content)
        } else {
            d routine.Write(%input.content)
        }
        s sc = routine.%Save()
    }


    s result = $$$jsobj
    i $$$ISERR(sc)
    {
        s result.success = $$$jsfalse
        s result.errors = ..ErrorsList(sc)
    } else {
        s result.success = $$$jstrue
        s result.name = filename
        s result.file = ..FileObject(namespace, filename)
    }

    q result
}

ClassMethod PutNewFile(namespace As %String) As %Status
{
    q ..PutFile(namespace, %input.name)
}

ClassMethod FileAction(namespace As %String, filename As %String) As %Status
{
    s classname = ..FileName(filename)
    s result = $$$jsobj
    if %input.action = "compile"
    {
        d $system.OBJ.Compile(classname, %input.spec_"-d", .errorlog)
        i errorlog {
            s result.success = $$$jsfalse
            s result.errors = $$$jslist
            f i=1:1:errorlog
            {
                d result.errors.Append(errorlog(i))
            }
        } else {
            s result.success = $$$jstrue
        }
    }
    s result.file = ..FileObject(namespace, filename)

    q result
}

ClassMethod GetXML(namespace As %String, filename As %String) As %Status
{
    s exportname = ..FileName(filename) _ "." _ $zcvt(..FileExtension(filename), "U")
    s sc = $system.OBJ.ExportToStream(exportname, .stream, "-d /diffexport")

    s result = $$$jsobj
    s result.id = ..CreatePath("namespaces", namespace, "files", filename, "xml")
    s result.content = $$$jsstream(stream)

    q result
}

ClassMethod PutXML(namespace As %String, filename As %String) As %Status
{
    if '$isobject(%input.content) {
        s stream = ##class(%Stream.TmpCharacter).%New()
        d stream.Write(%input.content)
    } else {
        s stream = %input.content
    }
    s sc = $system.OBJ.LoadStream(stream, "-c-d",,.loadedlist)

    s result = $$$jsobj
    if $$$ISERR(sc)
    {
        s result.success = $$$jsfalse
        s result.errors = ..ErrorsList(sc)
    } else {
        s result.success = $$$jstrue
        s name = $o(loadedlist(""))
        s displayname = ..FileName(name) _ "." _ $zcvt(..FileExtension(name),"L")
        s result.file = ..FileObject(namespace, displayname)
    }

    q result
}

ClassMethod PutNewXML(namespace As %String) As %Status
{
    //This is fine, because it doesn't make use of filename, yet
    q ..PutXML(namespace, "")
}

ClassMethod GetFileGenerated(namespace As %String, filename As %String) As %Status
{
    s type = $zcvt(..FileExtension(filename),"U")
    s file = ..FileName(filename)
    s results = $$$jslist
    s genFileList = ##class(%RoutineMgr).GetOther(file,type)
    i $l(genFileList)
    {
        f i=1:1:$l(genFileList, ",")
        {
            s obj = $$$jsobj
            s name = $p(genFileList, ",", i)
            s obj.name = ..FileName(name) _ "." _ $zcvt(..FileExtension(name),"L")
            s obj.id = ..CreatePath("namespaces",namespace,"files",obj.name)
            d results.Append(obj)
        }
    }

    q results
}

ClassMethod GlobalObject(namespace As %String, global As %String) As %CDEV.JSON.Object
{
    s obj = $$$jsobj

    s obj.id = ..CreatePath("namespaces", namespace, "globals", global)

    s jsrep = $$$jsobj

    s node = "^"_global_"("""")"
    f {
        s node = $query(@node, 1, target)
        q:node=""
        s nodename = $replace($replace($e($p(node, "(", 2,9999), 1, *-1), ",""", ","), """,", ",")
        s $property(jsrep, nodename) = target
    }
    s obj.content = jsrep
    s obj.name = global
    q obj
}

ClassMethod GetGlobalList(namespace As %String)
{
    s results = $$$jslist
    s global = ""
    f
    {
        s global = $o(^$g(global))
        q:global=""
        s obj = $$$jsobj
        s obj.name = $e(global,2,999)
        s obj.id = ..CreatePath("namespaces", namespace, "globals", obj.name)
        d results.Append(obj)
    }

    q results
}

ClassMethod GetGlobal(namespace As %String, global As %String)
{
    q ..GlobalObject(namespace, global)
}



ClassMethod QueryObject(namespace As %String, id As %Integer) As %CDEV.JSON.Object
{
    s obj = $$$jsobj
    s obj.id = ..CreatePath("namespaces", namespace, "queries", id)
    s obj.content = ^CacheTempCDEVQuery(id, "text")
    s obj.plan = ..CreatePath("namespaces", namespace, "queries", id, "plan")
    s obj.cached = ..CreatePath("namespaces", namespace, "queries", id, "cached")
    q obj
}

ClassMethod GetQueryList(namespace As %String)
{
    s results = $$$jslist

    s id = ""
    if $data(^CacheTempCDEVQuery)
    {
        f
        {
            s id = $o(^CacheTempCDEVQuery(id))
            q:id=""
            d results.Append(..QueryObject(namespace, id))
        }
    }

    q results
}

ClassMethod GetQuery(namespace As %String, query As %Integer)
{
    s result = ..QueryObject(namespace, query)

    q result
}

ClassMethod PutNewQuery(namespace As %String)
{
    s result = $$$jsobj
    if $length(%input.content)
    {
        s id = $increment(^CacheTempCDEVQuery)
        s ^CacheTempCDEVQuery(id, "text") = %input.content
        s result.success = $$$jstrue
        s result.query = ..QueryObject(namespace, id)
    } else {
        s result.success = $$$jsfalse
        s result.errors = "No query supplied"
    }

    q result
}

ClassMethod QueryAction(namespace As %String, query As %Integer)
{
    s queryObject = ..QueryObject(namespace, query)
    s result = $$$jsobj

    i %input.action = "execute"
    {

        s st = ##class(%SQL.Statement).%New()
        s sc = st.%Prepare(queryObject.content)
        if $$$ISERR(sc)
        {
            s result.success = $$$jsfalse
            s result.errors = ..ErrorsList(sc)
        } else {
            d st.%GetImplementationDetails(.cachedQueryName)
            s ^CacheTempCDEVQuery(query, "cachedQueryName") = cachedQueryName
            s result.success = $$$jstrue
            s result.resultset = $$$jsobj
            s rs = st.%Execute()
            s mt = rs.%GetMetadata()

            //This could probably be optimized significantly!
            for i=1:1:mt.columnCount
            {
                s $property(result.resultset, mt.columns.GetAt(i).colName) = $$$jslist
            }
            while rs.%Next()
            {
                for i=1:1:mt.columnCount
                {
                    d $method($property(result.resultset, mt.columns.GetAt(i).colName), "Append", rs.%GetData(i))
                }
            }
        }
    }
    q result
}

ClassMethod CodeObject(namespace As %String, id As %Integer) As %CDEV.JSON.Object
{
    s obj = $$$jsobj
    s obj.id = ..CreatePath("namespaces", namespace, "code", id)
    s obj.content = ^CacheTempCDEVCode(id, "text")
    q obj
}

ClassMethod GetCodeList(namespace As %String)
{
    s results = $$$jslist

    s id = ""
    if $data(^CacheTempCDEVQuery)
    {
        f
        {
            s id = $o(^CacheTempCDEVCode(i))
            d results.Append(..QueryObject(namespace, id))
        }
    }

    q results
}

ClassMethod GetCode(namespace As %String, code As %Integer)
{
    s result = ..CodeObject(namespace, code)

    q result
}

ClassMethod PutNewCode(namespace As %String)
{
    s result = $$$jsobj
    if $length(%input.content)
    {
        s id = $increment(^CacheTempCDEVCode)
        s ^CacheTempCDEVCode(id, "text") = %input.content
        s result.success = $$$jstrue
        s result.code = ..CodeObject(namespace, id)
    } else {
        s result.success = $$$jsfalse
        s result.errors = "No code supplied"
    }

    q result
}

ClassMethod CodeAction(namespace As %String, code As %Integer)
{
    s queryObject = ..CodeObject(namespace, code)
    i %input.action = "execute"
    {
        s result = $$$jsobj

        try {
            s resultStream = ..CaptureIO(queryObject.content)
            s result.success = $$$jstrue
            s result.results = $$$jsstream(resultStream)
        } catch {
            s result.success = $$$jsfalse
            s result.errors = ..ErrorsList($ze)
        }
    }

    q result
}
ClassMethod QueryPlanOperationObject(text As %String) As %CDEV.JSON.Object
{
    s %queryArray = 1
    s %queryArray(1) = text

    s xStatement = "do ShowPlan^%apiSQL(.%queryArray, 0, 0, 1)"
    s planStream = ..CaptureIO(xStatement)

    s sc = ##class(%XML.TextReader).ParseStream(planStream, .reader)
    s obj = $$$jsobj
    if $$$ISERR(sc)
    {
        s obj.success = $$$jsfalse
        s obj.errors = $$$jslist
        d planStream.Rewind()
        d obj.errors.Append(planStream.Read())
    } else {
        s obj.success = $$$jstrue
        s textStream = ##class(%Stream.TmpCharacter).%New()

        s elementStack = $$$jslist
        while reader.Read()
        {
            if reader.NodeType = "element"
            {
                d elementStack.Append(reader.Name)
            } elseif reader.NodeType = "endelement"
            {
                d elementStack.PopBack()
            }
            elseif reader.NodeType = "chars"
            {
                if elementStack.Get(-1) = "plan"
                {
                    d textStream.Write(reader.Value)
                }
            }
        }
        s obj.content = $$$jsstream(textStream)
    }
    q obj
}

ClassMethod GetQueryPlan(namespace As %String, query As %Integer)
{
    s obj = ..QueryObject(namespace, query)
    s result = ..QueryPlanOperationObject(obj.content)

    q result
}

ClassMethod GetQueryCached(namespace As %String, query As %Integer)
{
    s filename =  ^CacheTempCDEVQuery(query, "cachedQueryName")

    s result = ..FileObject(namespace, filename _ ".1.int")

    q result
}

ClassMethod RunCode(namespace As %String)
{
    i %input.action = "execute"
    {

    }
}

ClassMethod FileExtension(filename As %String) As %String
{
    q $zcvt($p(filename, ".", *), "L")
}

ClassMethod FileName(filename As %String) As %String
{
    q $p(filename, ".", 1, *-1)
}

ClassMethod CreatePath(components...) As %String
{
    s path = $e(%request.Application, 1, *-1)
    s i = ""
    f
    {
        s i = $o(components(i), 1, component)
        q:i=""
        s path = path _ "/" _ $zcvt(component,"O","URL")
    }
    q path
}


ClassMethod GetRequest() As %ZEN.proxyObject
{
    s request = ""
    if %request.Content
    {
        d %request.Content.Rewind()
        d ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(%request.Content,,.request)
    }
    q request
}

ClassMethod DoSQL(sql As %String, args...) As %SQL.StatementResult
{
    s st = ##class(%SQL.Statement).%New()
    if $find(sql,"::") {
        d st.%PrepareClassQuery($p(sql,"::",1), $p(sql,"::",2))
    } else {
        d st.%Prepare(sql)
    }
    s x = st.%Execute(args...)
    q x
}

ClassMethod GetURLForClass(classname As %String) As %String
{
    s classNamespace = $namespace
    n $namespace
    s $namespace = "%SYS"

    s rs = ..DoSQL("SELECT %ID FROM Security.Applications WHERE NameSpace=?", classNamespace)
    s cspapp = rs.%GetData(1)

    q cspapp _ classname _ ".cls"
}

ClassMethod ErrorsList(sc As %Status) As %CDEV.JSON.List
{
    s list = $$$jslist
    d DecomposeStatus^%apiOBJ(sc, .err, "-d")
    for i=1:1:err
    {
        d list.Append(err(i))
    }
    q list
}


ClassMethod CaptureIO(textString As %String) As %Stream.TmpCharacter [ ProcedureBlock = 0 ]
{
    //I don't know why this is required but it is.
    w " " 

    set myStream = ##class(%Stream.TmpCharacter).%New()

    use $io::("^"_$ZNAME)

    do ##class(%Device).ReDirectIO(1)

    xecute textString

    do ##class(%Device).ReDirectIO(0)

    quit myStream

rchr(c)      quit
rstr(sz,to)  quit
wchr(s)      do output($char(s))  quit
wff()        do output($char(12))  quit
wnl()        do output($char(13,10))  quit
wstr(s)      do output(s)  quit
wtab(s)      do output($char(9))  quit
output(s)    do myStream.Write(s)  quit
}

}

