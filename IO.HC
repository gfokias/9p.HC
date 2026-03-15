#define SERIAL0 0x3F8

#define IO_SLEEP_INTERVAL 1

#define UART_LSR 0x5
#define LSR_DATA 1 >> 0

U0 OutU8s(U8 *buf,I64 len,I64 port)
{//RepOutU8 fails with 'invalid opcode'
  I64 i;
  for (i=0;i<len;i++)
    OutU8(port, *(buf++));
}

#help_index "9p;Message Out"
public U0 OutMsgFmt(I64 port=SERIAL0,U8 type,U16 tag,...)
{//argv-s should be length followed by the value. strings should have a length of -StrLen
//Example: OutMsgFmt(,69,420,8,2000000,-8,"Hello",sizeof(CStat),&stat);
//1,2,4,8 byte structs should probably be passed without a pointer
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

U0 InBlockingRepU8(U8 *buf,I64 cnt,I64 port)
{
  I64 i;
  for (i=0;i<cnt;i++) {
    while (!(InU8(port+UART_LSR)&LSR_DATA)) {
      Sleep(IO_SLEEP_INTERVAL);
      Yield;
    }
    buf[i]=InU8(port);
  }
}

public U32 InBlockingLengthU8(I64 port=SERIAL0,U32 **ptr)
{
  U32 length;

  InBlockingRepU8(&length,sizeof(length),port);
  *ptr=MAlloc(length);
  **ptr=length;
  InBlockingRepU8((*ptr)+1,length-sizeof(length),port);
  
  return length;
}
