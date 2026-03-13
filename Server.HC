#include "D:/Message.HC"

#define FID_TABLE_SIZE 512

#define NOFID (~0(U32))
#define VERSION "9P2000"

static Qid qid;
static U16 msize = ~1;
static CHashTable *fids;

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

U0 OnVersion(CVersion *msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(,msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn("Invalid version in Tversion packet\n");
    Rversion(,msg->tag,msg->msize,"unknown");
  }
}

U0 OnAttach(CAttach *msg)
{
  I64 i;
  FidHashAdd(msg->fid, "C:/");
  for (i = 0; i < sizeof(qid); i++)
    qid.v[i]=RandU16;
  Rattach(,msg->tag,qid);
}

public U0 Start9p()
{
  CMessage *msg;
  fids = HashTableNew(FID_TABLE_SIZE);
		      
  while (TRUE) {
    msg=InBlockingMessage();
 
    switch (msg->type) {
    case TYPE_VERSION:
      OnVersion(msg); break;
    case TYPE_ATTACH:
      OnAttach(msg); break;
    default:
      PrintWarn("Unknown packet type %d\n",msg->type); break;
    }
    
    Free(msg);
  }
}

Start9p;
