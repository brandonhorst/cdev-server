Class %CDEV.JSON.Base Extends %Library.RegisteredObject [Abstract]
{

Method %WriteJSON() { }

ClassMethod %WriteJSONString(x As %String)
{
	w $zcvt(x, "O", "JSON")
}

}