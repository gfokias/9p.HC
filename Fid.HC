#define NOFID (~0(U32))

class CFid
{
  CFid *next;
  U32 value;
  I64 hash;
  U8 str[0];
};

static CFid *fids=NULL;

public U0 FidsReset()
{
  if (fids!=NULL)
    LinkedLstDel(fids);
  fids=NULL;
}

public CFid *FidAdd(U32 value,U8 *str)
{
  CFid *fid;
  fid=MAlloc(sizeof(CFid)+StrLen(str));
  fid->next=fids;
  fid->value=value;
  fid->hash=HashStr(str);
  StrCpy(&fid->str[0],str);
  fids=fid;
  return fid;
}

public U32 FidAddStr(U8 *str)
{//Create an fid with a random value. Returns the value
  return FidAdd(RandU32,str)->value;
}

public Bool FidDelValue(U32 value)
{//Delete fid from value
  CFid *fid,*prev;
  prev=NULL;
  for (fid=fids;fid!=NULL;fid=fid->next) {
    if (fid->value==value) {
      prev->next=fid->next;
      Free(fid);
      return TRUE;
    }
    prev=fid;
  }
  return FALSE;
}

public U8 *FidFile(U32 value)
{//Get fid file from value. Don't Free
  CFid *fid;
  for (fid=fids;fid!=NULL;fid=fid->next)
    if (fid->value==value)
      return &fid->str[0];
  return NULL;
}

public U32 FidValueOrAdd(U8 *str)
{//Get fid value from file. If it doesn't exist, create a new fid
  CFid *fid;
  I64 hash=HashStr(str);
  for (fid=fids;fid!=NULL;fid=fid->next)
    if (fid->hash==hash)
      return &fid->value;
  return FidAddStr(str);
}
