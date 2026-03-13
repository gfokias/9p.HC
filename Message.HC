//See https://man.cat-v.org/plan_9/5/intro
#define SLEEP_INTERVAL 1

#define UART_LSR 0x5
#define LSR_DATA 1 >> 0
#define SERIAL0 0x3F8

#define TYPE_VERSION 100
#define TYPE_AUTH 102
#define TYPE_ATTACH 104
#define TYPE_ERROR 106 /* Illegal */
#define TYPE_FLUSH 108
#define TYPE_WALK 110
#define TYPE_OPEN 112
#define TYPE_CREATE 114
#define TYPE_READ 116
#define TYPE_WRITE 118
#define TYPE_CLUNK 120
#define TYPE_REMOVE 122
#define TYPE_STAT 124
#define TYPE_WSTAT 126

public class Qid
{
  U8 v[13];
};

public class CPrefixedStr
{
  U16 length;
  U8 str[0];
};

//The classes represent T-messages.
//R-messages are written with functions
//defined below.
public class CMessage
{
  U32 length;
  U8 bin[0];
  U8 type;
  U16 tag;
};

public class CVersion : CMessage
{
  U32 msize;
  CPrefixedStr version;
};

public class CAuth : CMessage
{
  U32 afid;
  CPrefixedStr names; //two of them here, use NextPrefixedStr
};

public class CFlush : CMessage
{
  U16 oldtag;
};

public class CAttach : CMessage
{
  U32 fid;
  U32 afid;
  CPrefixedStr names;
};

public class CWalk : CMessage
{
  U32 fid;
  U32 newfid;
  U16 nwname;
};

public class COpen : CMessage
{
  U32 fid;
  U8 mode;
};

//Normally 'mode' and 'perm' are after the name,
//so this message needs to be rearranged 
public class CCreate : CMessage
{
  U32 fid;
  U32 perm;
  U8 mode;
  CPrefixedStr name;
};

public class CRead : CMessage
{
  U32 fid;
  U64 offset;
  U32 count;
};

public class CWrite : CMessage
{
  U32 fid;
  U64 offset;
  U32 count;
};

public class CClunk : CMessage
{
  U32 fid;
};

public class CRemove : CMessage
{
  U32 fid;
};

public class CStat : CMessage
{
  U32 fid;
};

public class CWstat : CMessage
{
  U32 fid;
  CPrefixedStr stat;
};

//RepOutU8 fails with 'invalid opcode'
U0 OutU8s(U8 *buf,I64 len,I64 port)
{
  I64 i;
  for (i=0;i<len;i++)
    OutU8(port, *(buf++));
}

U0 OutRmessage(I64 port=SERIAL0,U8 type,U16 tag,...)
{//argv should be length followed by the value. strings should have a length of -StrLen
  U32 i,length;

  if (argc%2)
    throw('InvlArgs');

  length=sizeof(length)+sizeof(type)+sizeof(tag);

  for (i=0;i<argc;i+=2) {
    if (argv[i] < 0)
      length+=sizeof(U16);
    length+=AbsI64(argv[i]);
  }

  OutU8s(&length,sizeof(length),port);
  OutU8(port,type);
  OutU8s(&tag,sizeof(tag),port);

  length=sizeof(length)+sizeof(type)+sizeof(tag);
  
  for (i=0;i<argc;i+=2)
    switch (argv[i]) {
    case 1:
      OutU8(port,argv[i+1]);
      break;
    case 2:
    case 4:
    case 8:
      OutU8s(&argv[i+1],argv[i],port);
      break;
    default: //strings should have negative length because they can be 1/2/4/8 bytes long
      argv[i]=AbsI64(argv[i]);
      OutU8s(&argv[i],sizeof(U16),port);
      OutU8s(argv[i+1],argv[i],port);
      break;
    }
}

public U0 Rversion(I64 port=SERIAL0,U16 tag,U32 msize,U8 *version)
{
  OutRmessage(port,TYPE_VERSION+1,tag,sizeof(msize),msize,-StrLen(version),version);
}

public U0 Rattach(I64 port=SERIAL0,U16 tag,Qid qid)
{
  OutRmessage(port,TYPE_ATTACH+1,tag,sizeof(qid),&qid);
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

public CMessage *InBlockingMessage(I64 port=SERIAL0)
{
  CMessage *msg;
  U32 len,i;
  
  BlockingRepInU8(&len,sizeof(len),port);

  msg=MAlloc(len);
  msg->length=len;

  BlockingRepInU8(&msg->bin[0],len-sizeof(len),port);

  if (msg->type==TYPE_CREATE) {
    i=len-sizeof(CCreate.mode);
    SwapU8(msg(CCreate*)->mode,msg->bin[i-offset(CMessage.bin)]);
    i-=sizeof(CCreate.perm);
    SwapU32(msg(CCreate*)->perm,msg->bin[i-offset(CMessage.bin)]);
  }
  
  return msg;
}

public CPrefixedStr *NextPrefixedStr(CPrefixedStr *str)
{//TODO
  return (str->length + sizeof(CPrefixedStr.length) + (str(U8*)));
}
