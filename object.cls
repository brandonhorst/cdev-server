Class %CDEV.JSON.Object Extends Base
{

Property %data As %String [ Internal, MultiDimensional ];

Method %WriteJSON()
{
	w "{"
	s k = $o(..%data(""), 1, v)
	f
	{
		q:k=""
		w """", k, """:"
		if $isobject(v)
		{
			d v.%WriteJSON()
		} else {
			w """", v, """"
		}
		s k = $o(..%data(k), 1, v)
		q:k=""
		w ","
	}
	w "}"
}

Method Count() As %Integer
{
	q ..%data
}

Method %DispatchGetProperty(name As %String) [ Final, Internal ]
{
	q $G(..%data(name))
}

Method %DispatchSetProperty(name As %String, value As %String) [ Final, Internal ]
{
	s:'$data(..%data(name)) ..%data = $i(..%data)
	s ..%data(name) = value
}	

}