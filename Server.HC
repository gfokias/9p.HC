#include "Fid"
#include "Message"
#include "Qid"

#define INVALID_VERSION_ERROR "Invalid version in Tversion"
#define INVALID_FID_ERROR "Fid is not associated with any file"
#define OPEN_FAIL_ERROR "Could not open file"
#define INVALID_FILE_ERROR "File does not exist"

#define VERSION "9P2000"

static U16 msize;

U0 Tversion(CTversion *msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn(INVALID_VERSION_ERROR"\n");
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
    if (!FileFind(file_name,&entry)) {
      Rerror(msg->tag,OPEN_FAIL_ERROR);
      return;
    }
    stat=StatInitFromDirEntry(,msg->fid,&entry);
    Free(entry.full_name);
  } else {
    stat=StatInit(,"/",msg->fid,TRUE,0,0);
  }
  
  Rstat(msg->tag,stat);
  Free(stat);
}

U0 Twalk(CTwalk *msg)
{
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
  pstr=&msg->names;
  
  qids=MAlloc(sizeof(CQid)*msg->nwname);

  for (i=0;i<msg->nwname;i++) {
    str=PrefixedStrToNullTerminated(pstr);
    pstr=PrefixedStrNext(pstr);
    
    if (FileFind(str,,FUF_JUST_FILES)) {
      is_dir=FALSE;
    } else if (Cd(str)) {
      is_dir=TRUE;
      Free(str);
      str=DirCur;
    } else {
      Free(str);
      break;
    }
    if (i==msg->nwname-1)//Last element
      fid=FidUniqueFile(msg->newfid,str)->value;
    else
      fid=FidValueOrAdd(str);
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

  if (!FileFind(file_name,&entry)) {
    Rerror(msg->tag,OPEN_FAIL_ERROR);
    return;
  }
  
  QidInitFromDirEntry(&qid,msg->fid,&entry);
  Free(entry.full_name);
  
  Ropen(msg->tag,qid,0);
}

U0 Tread_dir(CTread *msg,U8 *dir_name)
{//This function does not split data into different packets, even though it probably should.
//On the other side, ~60 files fit in a ~3kB buffer, so with say, 9pfs, you can send a folder
//with ~500 files on it without splitting. I will fix this when The Standard Temple IBM PC
//V2.0 is finally released
  CStat *stats,*stat;
  CDirEntry *entries,*entry;
  I64 size;
  U32 fid;

  entries=FilesFind(dir_name);
  entry=entries;

  if (entries==NULL)
    throw('NullEntr');
  
  if (msg->offset!=0) {
    Rread(msg->tag,0,0);
    return;
  }

  size=0;
  for (entry=entries;entry!=NULL;entry=entry->next)
    size+=StatSize(entry->name);
  
  stats=MAlloc(size);
  stat=stats;
  
  for (entry=entries;entry!=NULL;entry=entry->next) { 
    fid=FidValueOrAdd(entry->full_name);
    StatInitFromDirEntry(stat,fid,entry);
    stat=StatSize(entry->name)+stat(U8*);
  }

  DirTreeDel(entries);
  
  Rread(msg->tag,size,stats);
  Free(stats);
}

U0 Tread_file(CTread *msg,U8 *file_name)
{//Working under the assumption that the client will request one file at a time
  static U8 *last_raw=NULL;
  static U32 last_fid;
  static I64 last_size;
  U32 count;
  
  if (!last_raw||last_fid!=msg->fid) {
    if (last_raw)
      Free(last_raw);
    last_raw=FileRead(file_name,&last_size);
    last_fid=msg->fid;
  }

  if (last_size<=msg->offset)
    count=0;
  else
    count=Min(msg->count,last_size-msg->offset);

  Rread(msg->tag,count,last_raw+msg->offset);
}

U0 Tread(CTread *msg)
{
  U8 *file_name;
  
  file_name=FidFile(msg->fid);
 
  if (!file_name) {
    Rerror(msg->tag,INVALID_FID_ERROR);
    return;
  }

  if (IsDir(file_name))
    Tread_dir(msg,file_name);
  else if (FileFind(file_name))
    Tread_file(msg,file_name);
  else
    Rerror(msg->tag,INVALID_FILE_ERROR);
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
