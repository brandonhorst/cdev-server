Class %CDEV.JSON.Boolean Extends Base
{

Property %data As %String [ Internal ];

Method %OnNew(data) As %Status
{
	s %data = data
	q $$$OK
}

Method %WriteJSON()
{
	w $s(%data: "true", 1: "false")
}

}