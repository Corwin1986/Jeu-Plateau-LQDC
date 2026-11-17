"""Align stored APK members; shared libraries use Android's 16 KiB page boundary."""
import struct, sys, zipfile
source,target=sys.argv[1:]
with zipfile.ZipFile(source) as src, zipfile.ZipFile(target,'w') as dst:
 for info in src.infolist():
  data=src.read(info.filename)
  if info.compress_type==zipfile.ZIP_STORED:
   alignment=16384 if info.filename.endswith('.so') else 4
   offset=dst.fp.tell()+30+len(info.filename.encode('utf-8'))+len(info.extra)
   padding=(-offset)%alignment
   if padding:
    while padding<4:padding+=alignment
    info.extra+=struct.pack('<HH',0xd935,padding-4)+bytes(padding-4)
  dst.writestr(info,data)
with zipfile.ZipFile(target) as z,open(target,'rb') as f:
 for info in z.infolist():
  if info.compress_type==zipfile.ZIP_STORED:
   f.seek(info.header_offset+26);a,b=struct.unpack('<HH',f.read(4))
   offset=info.header_offset+30+a+b
   assert offset%(16384 if info.filename.endswith('.so') else 4)==0,info.filename
print('APK alignment verified, native libraries 16 KiB')
