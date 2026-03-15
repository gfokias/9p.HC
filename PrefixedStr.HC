#help_index "9p;Prefixed String"
public class CPrefixedStr
{
  U16 length;
  U8 str[0];
};

public class CPrefixedStrs : CPrefixedStr
{//Same as CPrefixedStr, but makes it clear that it's a list of them
};

public CPrefixedStr *PrefixedStrNext(CPrefixedStr *ptr)
{
  return ptr->length+sizeof(CPrefixedStr.length)+ptr(U8*);
}

public I64 PrefixedStrSize(U8 *str)
{
  return sizeof(CPrefixedStr.length)+StrLen(str);
}

public CPrefixedStr *PrefixedStrSetStep(CPrefixedStr *ptr,U8 *str)
{//Initializes a prefixed str. ptr needs to point to a 2+length long struct.
//Returns the start of the next prefixed str
  ptr->length=StrLen(str);
  MemCpy(ptr->str,str,ptr->length);
  return PrefixedStrNext(ptr);
}

public U8 *PrefixedStrToNullTerminated(CPrefixedStr *pstr)
{//Allocates a prefixed string. Free it when done
  U8 *str=MAlloc(pstr->length+1);
  MemCpy(str,pstr->str,pstr->length);
  str[pstr->length]='\0';
  return str;
}
