Class %CDEV.JSON.Base Extends %Library.RegisteredObject [Abstract]
{

Method %WriteJSON() { }

ClassMethod %WriteJSONString(x As %String)
{
	try {
		w $zcvt(x, "O", "JSON")
	} catch {
		w $replace($replace($zcvt(x, "O", "JS"), "\/", "/"), "\'", "'")
	}
}

}