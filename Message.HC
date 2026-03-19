//See https://man.cat-v.org/plan_9/5/intro
#include "IO"
#include "Qid"
#include "PrefixedStr"
#include "Stat"

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

#define TYPE_RVERSION TYPE_TVERSION+1
#define TYPE_RAUTH TYPE_TAUTH+1
#define TYPE_RATTACH TYPE_TATTACH+1
#define TYPE_RERROR TYPE_TERROR+1
#define TYPE_RFLUSH TYPE_TFLUSH+1
#define TYPE_RWALK TYPE_TWALK+1
#define TYPE_ROPEN TYPE_TOPEN+1
#define TYPE_RCREATE TYPE_TCREATE+1
#define TYPE_RREAD TYPE_TREAD+1
#define TYPE_RWRITE TYPE_TWRITE+1
#define TYPE_RCLUNK TYPE_TCLUNK+1
#define TYPE_RREMOVE TYPE_TREMOVE+1
#define TYPE_RSTAT TYPE_TSTAT+1
#define TYPE_RWSTAT TYPE_TWSTAT+1

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
  CPrefixedStrs names;
};

public class CTwalk : CTmessage
{
  U32 fid;
  U32 newfid;
  U16 nwname;
  CPrefixedStrs names;
};

public class CTopen : CTmessage
{
  U32 fid;
  U8 mode;
};

//'mode' and 'perm' are actually after the
//name, but for easy access to them this
//message needs to be rearranged.
public class CTcreate : CTmessage
{
  U32 fid;
  U8 body[0];//This is where the rearranging needs to happen
  U32 perm;
  U8 mode;
  U8 name[0];//This will be null terminated
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
  U8 data[0];
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
  U16 stat_length;
  CStat stat;
};

#help_index "9p;R-messages"
public U0 Rversion(U16 tag,U32 msize,U8 *version)
{
  OutMsgFmt(,TYPE_RVERSION,tag,sizeof(msize),msize,-StrLen(version),version);
}

public U0 Rattach(U16 tag,CQid qid)
{
  OutMsgFmt(,TYPE_RATTACH,tag,sizeof(qid),&qid);
}

public U0 Rerror(U16 tag,U8 *reason)
{
  PrintWarn("%s\n",reason);
  OutMsgFmt(,TYPE_RERROR,tag,-StrLen(reason),reason);
}

public U0 Rstat(U16 tag,CStat *stat)
{
  OutMsgFmt(,TYPE_RSTAT,tag,-(stat->size+sizeof(CStat.size)),stat);
}

public U0 Rwalk(U16 tag,U16 nwqid=0,CQid *qids=NULL)
{
  OutMsgFmt(,TYPE_RWALK,tag,sizeof(nwqid),nwqid,nwqid*sizeof(CQid),qids);
}

public U0 Rclunk(U16 tag)
{
  OutMsgFmt(,TYPE_RCLUNK,tag);
}

public U0 Ropen(U16 tag,CQid qid,U32 iounit)
{
  OutMsgFmt(,TYPE_ROPEN,tag,sizeof(CQid),&qid,sizeof(iounit),iounit);
} 

public U0 Rread(U16 tag,U32 count,U8 *data)
{
  OutMsgFmt(,TYPE_RREAD,tag,sizeof(count),count,count,data);
}

public U0 Rflush(U16 tag)
{
  OutMsgFmt(,TYPE_RFLUSH,tag);
}

public U0 Rcreate(U16 tag,CQid qid,U32 iounit)
{//This is literally just Ropen again
  OutMsgFmt(,TYPE_RCREATE,tag,sizeof(CQid),&qid,sizeof(iounit),iounit);
} 

public U0 Rwstat(U16 tag)
{
  OutMsgFmt(,TYPE_RWSTAT,tag);
}

public U0 Rremove(U16 tag)
{
  OutMsgFmt(,TYPE_RREMOVE,tag);
}

public U0 Rwrite(U16 tag, U32 count)
{
  OutMsgFmt(,TYPE_RWRITE,tag,sizeof(count),count);
}

U0 ReorderTcreate(CTcreate* msg)
{//Tcreate's format is not very approachable.
//This function reorders it to be better suited
//to reading. This function is also not divine
//intellect, but I digress.
  CPrefixedStr *name;
  I64 i;
  U32 perm;
  U16 length;
  U8 mode,*buffer;

  i=msg->length;
  mode=msg->body[i-=sizeof(CTcreate.perm)];
  perm=*(&msg->body[i-=sizeof(CTcreate.mode)](U32*));

  name=&msg->body[0];
  length=name->length;

  buffer=MAlloc(length);
  MemCpy(buffer,&name->str[0],length);
  MemCpy(&msg->name[0],buffer,length);
  Free(buffer);

  msg->perm=perm;
  msg->mode=mode;
  msg->name[length]=0;
}

#help_index "9p;Message In"
public CTmessage *Tmessage()
{
  CTmessage *msg;
  
  if (InBlockingLengthU8(,&msg)<sizeof(CTmessage)) {
    PrintWarn("Received packet smaller than message headers");
    Free(msg);
    return NULL;
  }

  if (msg->type==TYPE_TCREATE)
    ReorderTcreate(msg);
  
  return msg;
}
