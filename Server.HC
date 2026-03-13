#include "D:/Message.HC"

#define VERSION "9P2000"

static U16 msize = ~1;

U0 OnVersion(CVersion* msg)
{
  if (!StrNCmp(VERSION,msg->version.str,msg->version.length)) {
    msize=msg->msize;
    Rversion(,msg->tag,msg->msize,VERSION);
  } else {
    PrintWarn("Invalid version in Tversion packet\n");
    Rversion(,msg->tag,msg->msize,"unknown");
  }
}

public U0 Start9p()
{
  CMessage *msg;
  
  while (TRUE) {
    msg=InBlockingMessage();
 
    switch (msg->type) {
    case TYPE_VERSION:
      OnVersion(msg); break;
    default:
      PrintWarn("Unknown packet type %d\n",msg->type);
      break;
    }
    
    Free(msg);
  }
}

Start9p;
