#include "Fid"
#include "Message"
#include "Qid"

#define INVALID_VERSION_ERROR "Invalid version in Tversion"
#define INVALID_FID_ERROR "Fid is not associated with any file"
#define OPEN_FAIL_ERROR "Could not open file"

#define VERSION "9P2000"

static U16 msize;

U0 Tversion(CTversion *msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn(INVAID_VERSION_ERROR"\n");
    Rversion(msg->tag,msg->msize,"unknown");
  }
}

//I could check for an afid, not that it matters since there is no authentication
U0 Tattach(CTattach *msg)
{
  CQid qid;
  FidsReset;
  FidAdd(msg->fid,"C:/");
  QidInit(&qid,msg->fid,TRUE);
  Rattach(msg->tag,qid);
}

U0 Tstat(CTstat *msg)
{
  CDirEntry entry;
  CStat *stat;
  U8 *file_name;

  file_name=FidFile(msg->fid);
  
  if (!file_name) {
    Rerror(msg->tag,INVALID_FID_ERROR);
    return;
  }

  if (StrCmp("C:/",file_name)) {
    if (!FileFind(file_name, &entry)) {
      Rerror(msg->tag,OPEN_FAIL_ERROR);
      return;
    }
    stat=StatFromDirEntry(msg->fid,&entry);
    Free(entry.full_name);
  } else {
    stat=StatNew("/",msg->fid,TRUE,0,0);
  }
  
  Rstat(msg->tag,stat);
  Free(stat);
}

U0 Twalk(CTwalk *msg)
{
  //CDirEntry *entry,*e;
  CPrefixedStr *pstr;
  CQid *qids;
  U8 *file_name,*str;
  I64 i;
  U32 nwqid,fid;
  Bool is_dir;

  file_name=FidFile(msg->fid);
  
  if (!file_name) {
    Rerror(msg->tag,INVALID_FID_ERROR);
    return;
  }

  if (msg->nwname==0) {
    if (msg->fid!=msg->newfid) {
      FidAdd(msg->newfid,file_name);
    }
    Rwalk(msg->tag);
    return;
  }

  if (!Cd(file_name)) {
    Rerror(msg->tag,OPEN_FAIL_ERROR);
    return;
  }
    
  nwqid=0;
  str=&msg->names;
  
  qids=MAlloc(sizeof(CQid)*msg->nwname);
    
  for (i=0;i<msg->nwname;i++) {
    str=PrefixedStrToNullTerminated(pstr);

    if (Cd(str)) {
      is_dir=TRUE;
    } else if (FileFind(str)) {
      is_dir=FALSE;
    } else {
      Free(str);
      break;
    }
    if (i==msg->nwname-1)//Last element
      fid=msg->newfid;
    else
      fid=FidAddStr(str);
    QidInit(&qids[nwqid++],fid,is_dir);	
    Free(str);
  }

  Rwalk(msg->tag,nwqid,qids);
  Free(qids);
}

U0 Tclunk(CTclunk *msg)
{
  FidDelValue(msg->fid);
  Rclunk(msg->tag);
}

U0 Topen(CTopen *msg)
{
  CDirEntry entry;
  CQid qid;
  U8 *file_name;

  file_name=FidFile(msg->fid);

  if (!file_name) {
    Rerror(msg->tag,INVALID_FID_ERROR);
    return;
  }

  if (!StrCmp(file_name,"C:/")) {
    QidInit(&qid,msg->fid,TRUE);
    Ropen(msg->tag,qid,0);
    return;
  }

  if (!FileFind(file_name, &entry)) {
    Rerror(msg->tag,OPEN_FAIL_ERROR);
    return;
  }
  
  QidInitFromDirEntry(&qid,msg->fid,&entry);
  Free(entry.full_name);
  
  Ropen(msg->tag,qid,0);
}

public U0 Tread(CTread *msg)
{
}

public U0 Start9p()
{
  CTmessage *msg;

  FidsReset;
  
  while (TRUE) {
    msg=Tmessage;
    "%d\n",msg->type;  
    switch (msg->type) {
    case TYPE_TVERSION:
      Tversion(msg); break;
    case TYPE_TATTACH:
      Tattach(msg); break;
    case TYPE_TSTAT:
      Tstat(msg); break;
    case TYPE_TWALK:
      Twalk(msg); break;
    case TYPE_TCLUNK:
      Tclunk(msg); break;
    case TYPE_TOPEN:
      Topen(msg); break;
    case TYPE_TREAD:
      Tread(msg); break;
    default:
      PrintWarn("Unknown packet %d\n",msg->type);
      Rerror(msg->tag,"Unkown packet");
      break;
    }
    Free(msg);
  }
}

Start9p;
