Class %CDEV.JSON.Number Extends Base
{

Property %data As %String [ Internal ];

Method %OnNew(data) As %Status
{
	s %data = data
	q $$$OK
}

Method %WriteJSON()
{
	w %data
}

}