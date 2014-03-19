Class %CDEV.JSON.Stream Extends Base
{
	Property %data As %Stream.Object [ Internal ];

	Method %OnNew(data As %Stream.Object) As %Status
	{
		s %data = ##class(%Stream.TmpCharacter).%New()
		s sc = %data.CopyFrom(data)
		q sc
	}
	Method %WriteJSON()
	{
		s len = 32000
		w """"
		f
		{
			w $zcvt(%data.Read(.len, .sc), "O", "JSON")
			q:len=-1
		}
		w """"
	}
}