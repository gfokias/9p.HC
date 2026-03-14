#include "D:/Message.HC"

#define FID_NUM 512

#define NOFID (~0(U32))
#define VERSION "9P2000"

class CFid
{
  CFid *next;
  U32 val;
  I64 hash;
  U8 *str;
};

static CQid qid;
static U16 msize;
static CFid *fids;

CFid *FidAdd(U32 val,U8 *str)
{
  CFid *fid;

  fid = MAlloc(sizeof(CFid));
  fid->next=fids;
  fid->val=val;
  fid->hash=HashStr(str);
  fid->str=StrNew(str);

  fids=fid;
}

U8 *FidToFile(U32 val)
{
  CFid *v;
  for (v=fids;v!=NULL;v=v->next)
    if (v->val==val)
      return v->str;
  return NULL;
}

I64 FileToFid(U8 *str)
{
  CFid *v;
  I64 hash;
  hash=HashStr(str);
  for (v=fids;v!=NULL;v=v->next)
    if (v->hash==hash)
      return v->val;
  return NULL;
}

Bool FidDelFid(I64 val=-1)
{
  CFid *v,*p;
  for (v=fids;v!=NULL;v=v->next) {
    if (v->val==val) {
      p->next=v->next;
      Free(v->str);
      Free(v);
      return TRUE;
    }
    p=v;
  }
  return FALSE;
}

CDirEntry *RootDirEntry()
{
  static CDirEntry *entry = NULL;
  if (!entry) {
    entry=MAlloc(sizeof(CDirEntry));
    entry->next=entry->parent=entry->sub=entry->full_name=NULL;
    entry->name[0]='/';
    entry->name[1]='\0';
    entry->clus=entry->size=0;
  }
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

  if (FidToFile(msg->fid)) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }

  FidAdd(msg->fid,"C:/");
  
  if (msg->afid!=NOFID)
    PrintWarn("afid specified in Tattach\n");
  
  for (i = 0; i < sizeof(qid); i++)
    qid.bin[i]=RandU16;

  Rattach(,msg->tag,qid);
}

U0 OnTstat(CTstat *msg)
{
  CDirEntry *entry;
  U8 *file;

  file=FidToFile(msg->fid);
  
  if (!file) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }

  if (!StrCmp("C:/",file))
    entry=RootDirEntry;
  else
    if (!FileFind(file, &entry)) {
      Rerror(,msg->tag,"Could not open file");
      return;
    }
  
  Rstat(,msg->tag,msg->fid,entry,entry==RootDirEntry);
  Free(entry);
}

U0 OnTwalk(CTwalk *msg)
{
  CDirEntry *entry,*e;
  CPrefixedStr *str;
  U8 *file;
  I64 *qidfids,i;

  file=FidToFile(msg->fid);
  
  if (!file) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }

  if (msg->nwname==0) {
    if (msg->fid!=msg->newfid) {
      FidAdd(msg->newfid, file);
      file=NULL;
    }
  } else {
    qidfids=MAlloc(sizeof(I64)*msg->nwname);
    str=&msg->names;
    
    for (i=0;i<msg->nwname;i++);
  }

  Rwalk(,msg->tag,msg->nwname,qidfids);
}

U0 OnTclunk(CTclunk *msg)
{
  FidDelFid(msg->fid);
  Rclunk(,msg->tag);
}

U0 OnTopen(CTopen *msg)
{
  CQid qid;
  U8 *file;

  file=FidToFile(msg->fid);

  if (!file) {
    Rerror(,msg->tag,"Invalid fid");
    return;
  }
  
  InitQid(&qid,msg->fid,file);
  Ropen(,msg->tag,qid,0);
}

public U0 Start9p()
{
  CTmessage *msg;

  if (fids!=NULL)
    LinkedLstDel(&fids);
  fids=NULL;
  
  while (TRUE) {
    msg=InBlockingTmessage;

    "%d\n",msg->type;
    
    switch (msg->type) {
    case TYPE_TVERSION:
      OnTversion(msg); break;
    case TYPE_TATTACH:
      OnTattach(msg); break;
    case TYPE_TSTAT:
      OnTstat(msg); break;
    case TYPE_TWALK:
      OnTwalk(msg); break;
    case TYPE_TCLUNK:
      OnTclunk(msg); break;
    case TYPE_TOPEN:
      OnTopen(msg); break;
    default:
      PrintWarn("Unknown packet %d\n",msg->type);
      Rerror(,msg->tag,"unkown packet");
      break;
    }
    
    Free(msg);
  }
}

Start9p;
