//See https://man.cat-v.org/plan_9/5/intro
#define SLEEP_INTERVAL 1

#define UART_LSR 0x5
#define LSR_DATA 1 >> 0
#define SERIAL0 0x3F8

#define TYPE_TVERSION 100
#define TYPE_TAUTH 102
#define TYPE_TATTACH 104
#define TYPE_TERROR 106 /* Illegal */
#define TYPE_TFLUSH 108
#define TYPE_TWALK 110
#define TYPE_TOPEN 112
#define TYPE_TCREATE 114
#define TYPE_TREAD 116
#define TYPE_TWRITE 118
#define TYPE_TCLUNK 120
#define TYPE_TREMOVE 122
#define TYPE_TSTAT 124
#define TYPE_TWSTAT 126

#define ID "God"

#define QTFILE 0x00
#define QTDIR 0x80
#define DMDIR 0x80000000

//Stolen from $LK,"TOSExt.HC",A="FI:::/Demo/AcctExample/TOS/TOSExt.HC"$
#define NIST_TIME_OFFSET (-8049-local_time_offset/CDATE_FREQ)

public class CQid
{
  U8 bin[0];
  U8 type;
  U32 vers;
  U64 path;
};

public class CPrefixedStr
{
  U16 length;
  U8 str[0];
};

public class Cstat
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
  U8 strings[0];
};

//The classes represent T-messages.
//R-messages are written with
//$LK,"functions defined below",A="HI:9p;R-messages"$
#help_index "9p;T-messages"
public class CTmessage
{
  U32 length;
  U8 bin[0];
  U8 type;
  U16 tag;
};

public class CTversion : CTmessage
{
  U32 msize;
  CPrefixedStr version;
};

public class CTauth : CTmessage
{
  U32 afid;
  CPrefixedStr names; //two of them here, use NextPrefixedStr
};

public class CTflush : CTmessage
{
  U16 oldtag;
};

public class CTattach : CTmessage
{
  U32 fid;
  U32 afid;
  CPrefixedStr names;
};

public class CTwalk : CTmessage
{
  U32 fid;
  U32 newfid;
  U16 nwname;
  CPrefixedStr names;
};

public class CTopen : CTmessage
{
  U32 fid;
  U8 mode;
};

//Normally 'mode' and 'perm' are after the name,
//so this message needs to be rearranged 
public class CTcreate : CTmessage
{
  U32 fid;
  U32 perm;
  U8 mode;
  CPrefixedStr name;
};

public class CTread : CTmessage
{
  U32 fid;
  U64 offset;
  U32 count;
};

public class CTwrite : CTmessage
{
  U32 fid;
  U64 offset;
  U32 count;
};

public class CTclunk : CTmessage
{
  U32 fid;
};

public class CTremove : CTmessage
{
  U32 fid;
};

public class CTstat : CTmessage
{
  U32 fid;
};

public class CTwstat : CTmessage
{
  U32 fid;
  Cstat stat;
};

U0 InitQid(CQid *qid, U32 fid, U8 *name)
{
  if (IsDir(name))
    qid->type=QTDIR;
  else
    qid->type=QTFILE;
  qid->vers=0;
  qid->path=fid;
}

//Stolen from $LK,"TOSNIST.HC",A="FI:::/Demo/AcctExample/TOS/TOSNIST.HC"$
I64 CDate2Unix(CDate dt)
{//TempleOS datetime to Unix timestamp.
  return ToI64((dt-Str2Date("1/1/1970"))/CDATE_FREQ+NIST_TIME_OFFSET);
}

//RepOutU8 fails with 'invalid opcode'
U0 OutU8s(U8 *buf,I64 len,I64 port)
{
  I64 i;
  for (i=0;i<len;i++)
    OutU8(port, *(buf++));
}

U0 OutRmessage(I64 port=SERIAL0,U8 type,U16 tag,...)
{//argv-s should be length followed by the value. strings should have a length of -StrLen
  U32 i,length;

  if (argc%2)
    throw('InvlArgs');

  length=sizeof(length)+sizeof(type)+sizeof(tag);

  for (i = 0;i<argc;i+=2) {
    if (argv[i]<0)
      length+=sizeof(U16);
    length+=AbsI64(argv[i]);
  }

  OutU8s(&length,sizeof(length),port);
  OutU8(port,type);
  OutU8s(&tag,sizeof(tag),port);
 
  for (i=0;i<argc;i+=2)
    switch (argv[i]) {
    case 0: break;
    case 1:
      OutU8(port,argv[i+1]); break;
    case 2:
    case 4:
    case 8:
      OutU8s(&argv[i+1],argv[i],port); break;
    default:
      if (argv[i]<0) {//strings should have negative length to show that they are prefixed
	argv[i]*=-1;
	OutU8s(&argv[i],sizeof(U16),port);
      }
      OutU8s(argv[i+1],argv[i],port);
      break;
    }
}

#help_index "9p;R-messages"
public U0 Rversion(I64 port=SERIAL0,U16 tag,U32 msize,U8 *version)
{
  OutRmessage(port,TYPE_TVERSION+1,tag,sizeof(msize),msize,-StrLen(version),version);
}

public U0 Rattach(I64 port=SERIAL0,U16 tag,CQid qid)
{
  OutRmessage(port,TYPE_TATTACH+1,tag,sizeof(qid),&qid);
}

public U0 Rerror(I64 port=SERIAL0,U16 tag,U8 *reason)
{
  OutRmessage(port,TYPE_TERROR+1,tag,-StrLen(reason),reason);
}

public U0 Rstat(I64 port=SERIAL0,U16 tag,U64 fid,CDirEntry *entry,Bool isdir=FALSE)
{
  Cstat rstat;
  
  rstat.size=sizeof(rstat)-sizeof(rstat.size)+4*sizeof(U16)+StrLen(entry->name)+3*StrLen(ID);
  rstat.pad=0;//???????????????????????????????????????????????????????
  rstat.type=69;
  rstat.dev=420;
  InitQid(&rstat.qid,fid,&entry->full_name);
  if (rstat.qid.type==QTDIR)
    rstat.mode=DMDIR;
  else
    rstat.mode=0;
  rstat.atime=rstat.mtime=CDate2Unix(entry->datetime);
  rstat.length=entry->size;

  OutRmessage(port,TYPE_TSTAT+1,tag,sizeof(rstat),&rstat,-StrLen(entry->name),entry->name,
	      -StrLen(ID),ID,-StrLen(ID),ID,-StrLen(ID),ID);
}

public U0 Rwalk(I64 port=SERIAL0,U16 tag,U16 nwqid,I64 *fids)
{
  CQid *qids;
  U16 i;

  qids=MAlloc(nwqid*sizeof(CQid));

  for (i=0;i<nwqid;i++) {
    qids[i].type=0;
    qids[i].vers=0;
    qids[i].path=fids[i];
  }

  OutRmessage(port,TYPE_TWALK+1,tag,sizeof(nwqid),nwqid,nwqid*sizeof(CQid),qids);
}

public U0 Rclunk(I64 port=SERIAL0,U16 tag)
{
  OutRmessage(port,TYPE_TCLUNK+1,tag);
}

public U0 Ropen(I64 port=SERIAL0,U16 tag,CQid qid,U32 iounit)
{
  OutRmessage(port,TYPE_TOPEN+1,tag,sizeof(CQid),&qid,sizeof(iounit),iounit);
} 

//Reader functions
U0 BlockingRepInU8(U8 *buf,I64 cnt,I64 port)
{
  I64 i;
  for (i=0;i<cnt;i++) {
    while (!(InU8(port+UART_LSR)&LSR_DATA)) {
      Sleep(SLEEP_INTERVAL);
      Yield;
    }
    buf[i]=InU8(port);
  }
}

public CTmessage *InBlockingTmessage(I64 port=SERIAL0)
{
  CTmessage *msg;
  U32 len,i;
  
  BlockingRepInU8(&len,sizeof(len),port);

  msg=MAlloc(len);
  msg->length=len;

  BlockingRepInU8(&msg->bin[0],len-sizeof(len),port);

  if (msg->type==TYPE_TCREATE) {
    i=len-sizeof(CTcreate.mode);
    SwapU8(msg(CTcreate*)->mode,msg->bin[i-offset(CTmessage.bin)]);
    i-=sizeof(CTcreate.perm);
    SwapU32(msg(CTcreate*)->perm,msg->bin[i-offset(CTmessage.bin)]);
  }
  
  return msg;
}

public CPrefixedStr *NextPrefixedStr(CPrefixedStr *str)
{//TODO
  return (str->length + sizeof(CPrefixedStr.length) + (str(U8*)));
}
