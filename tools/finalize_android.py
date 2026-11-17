"""Normalize app label and launcher assets in a reused Godot template. Run before alignment/signing."""
import struct, sys, zipfile
from pathlib import Path
APK=Path(sys.argv[1]); icons=Path(sys.argv[2]); TITLE='La Quête des Cristaux'
def strings_decode(chunk):
    count,styles,flags,start,style_start=struct.unpack_from('<5I',chunk,8)
    assert styles==0
    head=struct.unpack_from('<H',chunk,2)[0]
    def length(off):
        if flags&256:
            n=chunk[off];return (((n&127)<<8)|chunk[off+1],off+2) if n&128 else (n,off+1)
        n=struct.unpack_from('<H',chunk,off)[0];return (((n&32767)<<16)|struct.unpack_from('<H',chunk,off+2)[0],off+4) if n&32768 else (n,off+2)
    out=[]
    for i in range(count):
        off=start+struct.unpack_from('<I',chunk,head+i*4)[0];n,off=length(off)
        if flags&256:n,off=length(off);out.append(chunk[off:off+n].decode('utf8'))
        else:out.append(chunk[off:off+n*2].decode('utf-16-le'))
    return out,flags
def strings_encode(strings,flags):
    def length(n):
        if flags&256:return bytes([n]) if n<128 else bytes([128|(n>>8),n&255])
        return struct.pack('<H',n) if n<32768 else struct.pack('<HH',32768|(n>>16),n&65535)
    raw=bytearray();offsets=[]
    for text in strings:
        offsets.append(len(raw));encoded=text.encode('utf8' if flags&256 else 'utf-16-le')
        raw+=length(len(text.encode('utf-16-le'))//2)
        if flags&256:raw+=length(len(encoded))
        raw+=encoded+(b'\0' if flags&256 else b'\0\0')
    raw+=b'\0'*((-len(raw))%4);start=28+4*len(strings)
    return struct.pack('<HHI5I',1,28,start+len(raw),len(strings),0,flags,start,0)+struct.pack('<'+'I'*len(strings),*offsets)+raw

def rewrite(data,is_xml):
    header=struct.unpack_from('<H',data,2)[0];p=header;parts=[];strings=[];pool=-1;flags=0
    while p<len(data):
        kind,head,size=struct.unpack_from('<HHI',data,p);c=bytearray(data[p:p+size]);p+=size
        if kind==1:
            strings,flags=strings_decode(c);pool=len(parts)
            strings=[TITLE if t=='Village vs Chenapan' else t for t in strings]
            if is_xml:strings.append(TITLE)
        elif is_xml and kind==0x102:
            tag=strings[struct.unpack_from('<I',c,20)[0]];start,width,count=struct.unpack_from('<3H',c,24)
            if tag=='application':
                for i in range(count):
                    off=16+start+i*width;name=strings[struct.unpack_from('<I',c,off+4)[0]]
                    if name=='label':
                        struct.pack_into('<I',c,off+8,len(strings)-1);c[off+15]=3;struct.pack_into('<I',c,off+16,len(strings)-1)
                    if name=='appCategory':struct.pack_into('<I',c,off+16,0)
                    if name=='isGame':struct.pack_into('<I',c,off+16,0xffffffff)
        parts.append(c)
    assert pool>=0
    parts[pool]=strings_encode(strings,flags)
    out=bytearray(data[:header])+b''.join(parts);struct.pack_into('<I',out,4,len(out));return bytes(out)
with zipfile.ZipFile(APK) as src, zipfile.ZipFile(APK.with_suffix('.normalized.apk'),'w') as dst:
    for info in src.infolist():
        if info.filename.startswith('META-INF/'):continue
        content=src.read(info.filename)
        if info.filename=='AndroidManifest.xml':content=rewrite(content,True)
        elif info.filename=='resources.arsc':content=rewrite(content,False)
        elif info.filename.startswith('res/mipmap-') and info.filename.endswith('.webp'):
            name=Path(info.filename).name
            if (icons/name).exists():content=(icons/name).read_bytes()
        dst.writestr(info,content)
APK.with_suffix('.normalized.apk').replace(APK)
print('Application label, game category and launcher icons normalized')
