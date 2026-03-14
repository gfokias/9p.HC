#include "D:/Message.HC"

#define FID_NUM 512

#define NOFID (~0(U32))
#define VERSION "9P2000"

static CQid qid;
static U16 msize;
static U8 *fids[FID_NUM];

CDirEntry *RootDirEntry()
{
  CDirEntry *entry;
  entry=MAlloc(sizeof(CDirEntry));
  entry->next=entry->parent=entry->sub=entry->full_name=NULL;
  entry->name[0]='/';
  entry->name[1]='\0';
  entry->clus=entry->size=0;
  return entry;
}

U0 OnTversion(CTversion *msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(,msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn("Invalid version in Tversion\n");
    Rversion(,msg->tag,msg->msize,"unknown");
  }
}

U0 OnTattach(CTattach *msg)
{
  I64 i;  

  if (msg->fid>FID_NUM||fids[msg->fid]!=0) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }

  fids[msg->fid]="C:/";

  if (msg->afid!=NOFID)
    PrintWarn("afid specified in Tattach\n");
  
  for (i = 0; i < sizeof(qid); i++)
    qid.bin[i]=RandU16;

  Rattach(,msg->tag,qid);
}

U0 OnTstat(CTstat *msg)
{
  U8 *name = NULL;
  CDirEntry *entry;
  
  if (msg->fid>FID_NUM||!fids[msg->fid]) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }

  if (msg->fid==0) {
    name="/";
    entry=RootDirEntry;
  } else {
    if (!FileFind(fids[msg->fid], &entry)) {
      Rerror(,msg->tag,"Could not open file");
      return;
    }
  }
  

  Rstat(,msg->tag,msg->fid,entry,name);
  Free(entry);
}

public U0 Start9p()
{
  CTmessage *msg;
  
  MemSet(&fids[0], 0, sizeof(fids));
  
  while (TRUE) {
    msg=InBlockingTmessage();

    "%d\n", msg->type;
    
    switch (msg->type) {
    case TYPE_TVERSION:
      OnTversion(msg); break;
    case TYPE_TATTACH:
      OnTattach(msg); break;
    case TYPE_TSTAT:
      OnTstat(msg); break;
    default:
      PrintWarn("Unknown packet %d\n",msg->type);
      Rerror(,msg->tag,"unkown packet");
      break;
    }
    
    Free(msg);
  }
}

Start9p;
