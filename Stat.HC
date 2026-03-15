#include "PrefixedStr"
#include "Qid"

#define GMUID "God" //guid,uid,muid
#define DMDIR 0x80000000
#define DMFILE 0x00000000

#define STAT_TYPE 0x0
#define STAT_NUM_STRS 4

//Stolen from $LK,"TOSNIST.HC",A="FI:::/Demo/AcctExample/TOS/TOSNIST.HC"$
#define NIST_TIME_OFFSET (-8049-local_time_offset/CDATE_FREQ)

#help_index "9p;Stat"
public class CStat
{
  U16 size;
  U16 pad;//???????????????????????
  U16 type;
  U32 dev;
  CQid qid;
  U32 mode;
  U32 atime;
  U32 mtime;
  U64 length;
  CPrefixedStr strings[0];//Needs to be 0-length array so it doesn't influence the MAlloc
};

//Stolen from $LK,"TOSNIST.HC",A="FI:::/Demo/AcctExample/TOS/TOSNIST.HC"$
I64 CDate2Unix(CDate dt)
{//TempleOS datetime to Unix timestamp.
  return ToI64((dt-Str2Date("1/1/1970"))/CDATE_FREQ+NIST_TIME_OFFSET);
}

public CStat *StatNew(U8 *name,U32 fid,Bool is_dir,U64 length,U32 time)
{
  CStat *stat;
  CPrefixedStr *str;
  I64 i;
  U16 len;

  len=sizeof(CStat)+PrefixedStrSize(name)+3*PrefixedStrSize(GMUID);
  stat=MAlloc(len);
  
  QidInit(&stat->qid,fid,is_dir);
  
  stat->size=len-sizeof(CStat.size);
  stat->pad=0;//??
  stat->type=STAT_TYPE;
  if (stat->qid.type&QTDIR)
    stat->mode=DMDIR;
  else
    stat->mode=DMFILE;
  stat->atime=time;
  stat->mtime=time;
  stat->length=length;

  str=PrefixedStrSetStep(&stat->strings[0],name);
  
  for (i=0;i<STAT_NUM_STRS-1;i++)
    str=PrefixedStrSetStep(str,GMUID);

  return stat;
}

public CStat *StatFromDirEntry(U32 fid,CDirEntry *entry)
{
  return StatNew(entry->name,fid,IsDir(entry->full_name),entry->size,CDate2Unix(entry->datetime));
}
