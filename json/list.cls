Class %CDEV.JSON.List Extends Base
{

Property %data As %ZEN.Datatype.string(XMLPROJECTION = "NONE") [ Internal, MultiDimensional ];

Method %WriteJSON()
{
	w "["
	f i=0:1:..Count()-1
	{
		s x = ..Get(i)
		i $isobject(x)
		{
			d x.%WriteJSON()
		} else {
			w """", x, """"
		}
		w:..Count()>(i+1) ","
	}
	w "]"
}

ClassMethod Create(data...) As List [Internal]
{
	s x = ##class(List).%New()
	d x.OnCreate(data...)
	q x
}

Method OnCreate(data...) [Internal]
{
	m ..%data = data
}

Method Get(index As %Integer) As %String
{
	s trueStart = $o(..%data(""))
	s trueEnd = $o(..%data(""), -1)
	s trueIndex = $s(index >= 0: trueStart + index, 1: trueEnd + (index+1))
	q ..%data(trueIndex)
}

Method Slice(start = "", end = "") As List
{
	s trueStart = $o(..%data(""))
	s trueEnd = $o(..%data(""), -1)
	s startIndex = $s(start = "": trueStart, start >= 0: trueStart + start, 1: trueEnd + start + 1)
	s endIndex = $s(end = "": trueEnd, end >= 0: trueStart + end - 1, 1: trueEnd + end)
	w trueStart _":" _ trueEnd _ ":" _ startIndex _ ":" _ endIndex
	
	f i=startIndex:1:endIndex
	{
		s x($i(x)) = ..%data(i)
	}
	q ##class(List).Create(x...)
}

Method Append(value As %String)
{
	d ..Add(value, -1)
}

Method Prepend(value As %String)
{
	d ..Add(value, 1)
}

Method PopBack() As %String
{
	q ..Pop(-1)
}

Method PopFront() As %String
{
	q ..Pop(1)
}

Method Count() As %Integer
{
	q ..%data
}

Method Add(value As %String, order) [Internal]
{
	s index = $o(..%data(""), order)
	s:index="" index = order
	s ..%data(index-order) = value
	s ..%data = $i(..%data)
}


Method Pop(order) As %String [Internal]
{
	s lastIndex = $o(..%data(""), order)
	s x = ..%data(lastIndex)
	k ..%data(lastIndex)
	s ..%data = $i(..%data, -1)
	q x
}

}