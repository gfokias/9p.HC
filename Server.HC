#include "D:/Message.HC"

#define FID_TABLE_SIZE 512

#define NOFID (~0(U32))
#define VERSION "9P2000"

static Qid qid;
static U16 msize;
static CHashTable *fids = NULL;

CHashGeneric *FidHashAdd(U32 fid, U8 *path)
{
  CHashGeneric *word;

  word = MAlloc(sizeof(CHashGeneric));
  word->type=HTT_FILE;
  word->str=StrNew(path);
  word->user_data0=fid;
  HashAdd(word,fids);

  return word;
}

U0 OnTversion(CTversion *msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(,msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn("Invalid version in Tversion packet\n");
    Rversion(,msg->tag,msg->msize,"unknown");
  }
}

U0 OnTattach(CTattach *msg)
{
  I64 i;
  FidHashAdd(msg->fid, "C:/");
  for (i = 0; i < sizeof(qid); i++)
    qid.v[i]=RandU16;
  Rattach(,msg->tag,qid);
}

public U0 Start9p()
{
  CTmessage *msg;
  
  if (fids == NULL)
    fids = HashTableNew(FID_TABLE_SIZE);
		      
  while (TRUE) {
    msg=InBlockingTmessage();
 
    switch (msg->type) {
    case TYPE_TVERSION:
      OnTversion(msg); break;
    case TYPE_TATTACH:
      OnTattach(msg); break;
    default:
      PrintWarn("Unknown packet %d\n",msg->type);
      Rerror(,msg->tag,"unkown packet");
      break;
    }
    
    Free(msg);
  }
}

Start9p;
