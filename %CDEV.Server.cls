Include %CDEV.JSON.Includes

Class %CDEV.Server Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/namespaces" Method="GET" Call="GetNamespaceList" />
    <Route Url="/namespaces/:namespace" Method="GET" Call="GetNamespace" />
    <Route Url="/namespaces/:namespace/files" Method="GET" Call="GetFileList" />
    <Route Url="/namespaces/:namespace/files" Method="PUT" Call="PutNewFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="GET" Call="GetFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="PUT" Call="PutFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="POST" Call="FileAction" />
    <Route Url="/namespaces/:namespace/files/:filename/generated" Method="GET" Call="GetGenerated" />
    <Route Url="/namespaces/:namespace/globals" Method="GET" Call="GetGlobalList" />
    <Route Url="/namespaces/:namespace/globals/:globalname" Method="GET" Call="GetGlobal" />
</Routes>
}

ClassMethod GetNamespaceList() As %Status
{
    s rs = ..DoSQL("%SYS.Namespace::List")
    s results = $$$jslist
    while rs.%Next() {
        s obj = $$$jsobj
        s obj.name = rs.%GetData(1)
        s obj.id = ..CreatePath("namespaces", $zcvt(obj.name,"L"))
        s obj.files = obj.id _ "/files"
        d results.Append(obj)
    }

    s %response.ContentType="application/json"
    d results.%WriteJSON()
    q $$$OK
}

ClassMethod GetFileList(namespace As %String) As %Status
{
    n $namespace
    s $namespace = namespace

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

    s %response.ContentType="application/json"
    d results.%WriteJSON()
    q $$$OK
}

ClassMethod GetNamespace(namespace As %String) As %Status
{
    s obj = $$$jsobj
    s obj.id = ..CreatePath("namespaces", namespace)
    s obj.files = ..CreatePath("namespaces", namespace, "files")

    s %response.ContentType="application/json"
    d obj.%WriteJSON()
    q $$$OK
}

ClassMethod FileObject(filename As %String) As %CDEV.JSON.Object
{
    s result = $$$jsobj

    if ..FileExtension(filename) = "cls"
    {
        s displayName = ..FileName(filename)
        if ##class(%Dictionary.ClassDefinition).%ExistsId(displayName)
        {
            d ##class(%Compiler.UDL.TextServices).GetTextAsStream(,displayName,.classStream) 
            s result.content = $$$jsstream(classStream)
        } else {
            q ""
        }
    } else {
        s displayName = filename
        i ##class(%Routine).Exists(filename)
        {
            s routine = ##class(%Routine).%OpenId(filename)
            s result.content = $$$jsstream(routine)
        } else {
            q ""
        }
    }

    s result.id = ..CreatePath("namespaces", namespace, "files", filename)
    s result.generatedfiles = result.id _ "/generated"
    s result.name = displayName
    s result.url = ..GetURLForClass(displayName)
    q result
}

ClassMethod GetFile(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s result = ..FileObject(filename)

    d result.%WriteJSON()
    q $$$OK
}

ClassMethod PutFile(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s requestObject = ..GetRequest()

    if ..FileExtension(filename) = "cls"
    {
        s displayName = ..FileName(filename)
        i $isobject(requestObject.content)
        {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromStream(,displayName,requestObject.content.Read()) 
        } else {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromString(,displayName,requestObject.content) 
        }
    } else {
        s trueName = ..FileName(filename) _ "." _ $zcvt(..FileExtension(filename), "U")
        s displayName = filename
        if ##class(%Routine).Exists(trueName)
        {
            s routine = ##class(%Routine).%OpenId(trueName)
            d routine.Clear()
        } else {
            s routine = ##class(%Routine).%New(trueName)
        }
        i $isobject(requestObject.content)
        {
            d routine.CopyFrom(requestObject.content)
        } else {
            d routine.Write(requestObject.content)
        }
        s sc = routine.%Save()
    }


    s result = $$$jsobj
    i $$$ISERR(sc)
    {
        s result.success = $$$jsfalse
        s result.errors = $$DecomposeStatus^%apiOBJ(sc)
    } else {
        s result.success = $$$jstrue
        s result.name = displayName
        s result.file = ..FileObject(filename)
    }
    s %response.ContentType="application/json"
    d result.%WriteJSON()
    q $$$OK
}

ClassMethod PutNewFile(namespace As %String) As %Status
{
    s requestObject = ..GetRequest()
    q ..PutFile(namespace, requestObject.name)
}

ClassMethod FileAction(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s classname = ..FileName(filename)
    s request = ..GetRequest()
    s result = $$$jsobj
    if request.action = "compile"
    {
        d $system.OBJ.Compile(classname, request.spec_"-d", .errorlog)
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
    s result.file = ..FileObject(filename)
    s %response.ContentType="application/json"
    d result.%WriteJSON()
    q $$$OK
}

ClassMethod GetGenerated(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace
    
    s rs = ..DoSQL("")
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
    s %response.ContentType="application/json"
    d results.%WriteJSON()
    q $$$OK
}

ClassMethod GetGlobalList(namespace As %String)
{
    n $namespace
    s $namespace = namespace
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

    s %response.ContentType="application/json"
    d results.%WriteJSON()
    q $$$OK
}

ClassMethod GetGlobalList(namespace As %String)
{
    n $namespace
    s $namespace = namespace
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

    s %response.ContentType="application/json"
    d results.%WriteJSON()
    q $$$OK
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

ClassMethod SendJSON(object As %RegisteredObject) As %Status
{
    s %response.ContentType="application/json"
    d ##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONFromObject(,object)
}

ClassMethod GetRequest() As %ZEN.proxyObject
{
    d %request.Content.Rewind()
    d ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(%request.Content,,.request)
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

}

