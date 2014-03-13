Include %CDEV.JSON.Includes

Class %CDEV.Server Extends %CSP.REST
{

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
    <Route Url="/namespaces" Method="GET" Call="GetNamespaceList" />
    <Route Url="/namespaces/:namespace" Method="GET" Call="GetNamespace" />
    <Route Url="/namespaces/:namespace/xml" Method="PUT" Call="PutNewXML" />
    <Route Url="/namespaces/:namespace/files" Method="GET" Call="GetFileList" />
    <Route Url="/namespaces/:namespace/files" Method="PUT" Call="PutNewFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="GET" Call="GetFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="PUT" Call="PutFile" />
    <Route Url="/namespaces/:namespace/files/:filename" Method="POST" Call="FileAction" />
    <Route Url="/namespaces/:namespace/files/:filename/generated" Method="GET" Call="GetGenerated" />
    <Route Url="/namespaces/:namespace/files/:filename/xml" Method="GET" Call="GetXML" />
    <Route Url="/namespaces/:namespace/files/:filename/xml" Method="PUT" Call="PutXML" />
    <Route Url="/namespaces/:namespace/xml" Method="PUT" Call="PutNewXML" />
    <Route Url="/namespaces/:namespace/globals" Method="GET" Call="GetGlobalList" />
    <Route Url="/namespaces/:namespace/globals/:globalname" Method="GET" Call="GetGlobal" />
    <Route Url="/namespaces/:namespace/queries" Method="POST" Call="QueryAction" />
</Routes>
}

ClassMethod GetNamespaceList() As %Status
{
    s rs = ..DoSQL("%SYS.Namespace::List")
    s results = $$$jslist
    while rs.%Next() {
        s obj = ..NamespaceObject($zcvt(rs.%GetData(1), "L"))
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
    s obj = ..NamespaceObject(namespace)

    s %response.ContentType="application/json"
    d obj.%WriteJSON()
    q $$$OK
}

ClassMethod NamespaceObject(namespace As %String) As %CDEV.JSON.Object
{
    s obj = $$$jsobj
    s obj.id = ..CreatePath("namespaces", namespace)
    s obj.name = $zcvt(namespace, "U")
    s obj.files = ..CreatePath("namespaces", namespace, "files")
    s obj.xml = ..CreatePath("namespaces", namespace, "xml")

    q obj
}

ClassMethod FileObject(namespace As %String, filename As %String) As %CDEV.JSON.Object
{
    s result = $$$jsobj

    if ..FileExtension(filename) = "cls"
    {
        s systemName = ..FileName(filename)
        if ##class(%Dictionary.ClassDefinition).%ExistsId(systemName)
        {
            d ##class(%Compiler.UDL.TextServices).GetTextAsStream(,..FileName(filename),.classStream) 
            s result.content = $$$jsstream(classStream)
        } else {
            q ""
        }
    } else {
        s systemName = filename
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
    s result.name = filename
    s result.xml = ..CreatePath("namespaces", namespace, "files", filename, "xml")
    s result.url = ..GetURLForClass(systemName)
    q result
}

ClassMethod GetFile(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s result = ..FileObject(namespace, filename)

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
        s systemName = ..FileName(filename)
        i $isobject(requestObject.content)
        {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromStream(,systemName,requestObject.content.Read()) 
        } else {
            s sc = ##class(%Compiler.UDL.TextServices).SetTextFromString(,systemName,requestObject.content) 
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
        s result.name = filename
        s result.file = ..FileObject(namespace, filename)
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
    s result.file = ..FileObject(namespace, filename)
    s %response.ContentType="application/json"
    d result.%WriteJSON()
    q $$$OK
}

ClassMethod GetXML(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s exportname = ..FileName(filename) _ "." _ $zcvt(..FileExtension(filename), "U")
    s sc = $system.OBJ.ExportToStream(exportname, .stream, "-d")

    s result = $$$jsobj
    s result.id = ..CreatePath("namespaces", namespace, "files", filename, "xml")
    s result.content = $$$jsstream(stream)

    s %response.ContentType="application/json"
    d result.%WriteJSON()
    q $$$OK
}

ClassMethod PutXML(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace

    s request = ..GetRequest()

    if '$isobject(request.content) {
        s stream = ##class(%Stream.TmpCharacter).%New()
        d stream.Write(request.content)
    } else {
        s stream = request.content
    }
    s sc = $system.OBJ.LoadStream(stream, "-c-d",,.loadedlist)

    s result = $$$jsobj
    if $$$ISERR(sc)
    {
        s result.success = $$$jstrue
        s result.errors = $$DecomposeStatus^%apiOBJ(sc)
    } else {
        s result.success = $$$jstrue
        s name = $o(loadedlist(""))
        s displayname = ..FileName(name) _ "." _ $zcvt(..FileExtension(name),"L")
        s result.file = ..FileObject(namespace, displayname)
    }
    s %response.ContentType="application/json"
    d result.%WriteJSON()
    q $$$OK
}

ClassMethod PutNewXML(namespace As %String) As %Status
{
    //This is fine, because it doesn't make use of filename, yet
    q ..PutXML(namespace, "")
}


ClassMethod GetGenerated(namespace As %String, filename As %String) As %Status
{
    n $namespace
    s $namespace = namespace
    
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

ClassMethod QueryAction(namespace As %String)
{
    n $namespace
    s $namespace = namespace

    s request = ..GetRequest()
    i request.action = "execute"
    {
        d ##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONFromSQL("",request.content)
    }
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

