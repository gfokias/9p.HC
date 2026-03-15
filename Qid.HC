#define QID_VERS 0x0

#define QTFILE 0x00
#define QTDIR 0x80

#help_index "9p;Qid"
public class CQid
{
  U8 bin[0];
  U8 type;
  U32 vers;
  U64 path;
};

public CQid *QidInit(CQid *qid=NULL,U32 fid,Bool is_dir)
{
  if (!qid)
    qid=MAlloc(sizeof(CQid));
  if (is_dir)
    qid->type=QTDIR;
  else
    qid->type=QTFILE;
  qid->vers=QID_VERS;
  qid->path=fid;
  return qid;
}

public CQid *QidInitFromDirEntry(CQid *qid=NULL,U32 fid,CDirEntry *entry)
{
  Bool is_dir=IsDir(entry->full_name);
  if (!is_dir && !FileFind(entry->full_name))
    throw('InvlFile');
  return QidInit(qid,fid,is_dir);
}
