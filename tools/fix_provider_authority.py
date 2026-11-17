"""Give AndroidX Startup its own URI authority before signing an exported APK."""
import struct,sys,zipfile,os
from pathlib import Path
apk=Path(sys.argv[1]); replacement=None
with zipfile.ZipFile(apk) as z:
 data=bytearray(z.read('AndroidManifest.xml'))
 pos=8;chunks=[];strings=[];pool_at=-1
 while pos<len(data):
  kind,head,size=struct.unpack_from('<HHI',data,pos)
  chunk=bytearray(data[pos:pos+size]);chunks.append(chunk)
  if kind==1:
   pool_at=len(chunks)-1
   count,styles,flags,start,style_start=struct.unpack_from('<5I',chunk,8)
   assert styles==0,'Unexpected styled XML string pool'
   def length(buf,off,utf8):
    if utf8:
     value=buf[off];return (((value&127)<<8)|buf[off+1],off+2) if value&128 else (value,off+1)
    value=struct.unpack_from('<H',buf,off)[0];return (((value&32767)<<16)|struct.unpack_from('<H',buf,off+2)[0],off+4) if value&32768 else (value,off+2)
   for i in range(count):
    off=start+struct.unpack_from('<I',chunk,head+i*4)[0]
    size_,off=length(chunk,off,bool(flags&256))
    if flags&256:size_,off=length(chunk,off,True);strings.append(bytes(chunk[off:off+size_]).decode('utf8'))
    else:strings.append(bytes(chunk[off:off+size_*2]).decode('utf-16-le'))
  pos+=size
 new_index=len(strings)
 for chunk in chunks:
  kind,head,size=struct.unpack_from('<HHI',chunk)
  if kind!=0x102:continue
  name=struct.unpack_from('<I',chunk,20)[0]
  if strings[name]!='provider':continue
  attr_start,attr_size,attr_count=struct.unpack_from('<3H',chunk,24)
  attrs={}
  for i in range(attr_count):
   off=16+attr_start+i*attr_size
   name_idx,raw=struct.unpack_from('<II',chunk,off+4)
   value=struct.unpack_from('<I',chunk,off+16)[0]
   attrs[strings[name_idx]]=(off,strings[value] if chunk[off+15]==3 else '')
  if attrs.get('name',(0,''))[1]=='androidx.startup.InitializationProvider':
   off,current=attrs['authorities'];replacement=current.removesuffix('.fileprovider')+'.androidx-startup'
   struct.pack_into('<I',chunk,off+8,new_index);struct.pack_into('<I',chunk,off+16,new_index)
 assert replacement,'Startup provider not found'
 strings.append(replacement)
 def enc_len(n,utf8):
  if utf8:return bytes([n]) if n<128 else bytes([128|(n>>8),n&255])
  return struct.pack('<H',n) if n<32768 else struct.pack('<HH',32768|(n>>16),n&65535)
 raw=bytearray();offsets=[]
 for text in strings:
  offsets.append(len(raw));encoded=text.encode('utf8' if flags&256 else 'utf-16-le');n=len(text.encode('utf-16-le'))//2
  raw+=enc_len(n,bool(flags&256))
  if flags&256:raw+=enc_len(len(encoded),True)
  raw+=encoded+(b'\0' if flags&256 else b'\0\0')
 raw+=b'\0'*((-len(raw))%4)
 start=28+4*len(strings);size=start+len(raw)
 chunks[pool_at]=struct.pack('<HHI5I',1,28,size,len(strings),0,flags,start,0)+struct.pack('<'+'I'*len(offsets),*offsets)+raw
 out=bytearray(data[:8])+b''.join(chunks);struct.pack_into('<I',out,4,len(out))
 temp=apk.with_suffix('.unsigned.apk')
 with zipfile.ZipFile(temp,'w') as target:
  for info in z.infolist():
   if info.filename.startswith('META-INF/'):continue
   target.writestr(info,bytes(out) if info.filename=='AndroidManifest.xml' else z.read(info.filename))
os.replace(temp,apk)
print('AndroidX Startup authority separated from FileProvider')
