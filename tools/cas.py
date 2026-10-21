import sys,os
H=bytes.fromhex('1fa6debacc137d74')
d=open(sys.argv[1],'rb').read(); out=sys.argv[2]; os.makedirs(out,exist_ok=True)
parts=d.split(H)[1:]
i=0;n=0
while i<len(parts):
    b=parts[i].rstrip(b'\0') if False else parts[i]
    if len(b)>=16 and b[:10] in (b'\xd0'*10,b'\xd3'*10,b'\xea'*10):
        typ={0xd0:'BIN',0xd3:'BAS',0xea:'ASC'}[b[0]]; name=b[10:16].decode('latin1')
        data=parts[i+1]
        if typ=='BIN':
            s=data[0]|data[1]<<8; e=data[2]|data[3]<<8; x=data[4]|data[5]<<8
            print(f"#{n} {typ} '{name}' start={s:04x} end={e:04x} exec={x:04x} len={e-s+1}")
            open(f"{out}/{n:02d}_{name.strip()}_{s:04x}.bin",'wb').write(data[6:6+e-s+1])
        else:
            print(f"#{n} {typ} '{name}' len={len(data)}")
            open(f"{out}/{n:02d}_{name.strip()}.{typ.lower()}",'wb').write(data)
        i+=2
    else:
        print(f"#{n} RAW len={len(b)}"); open(f"{out}/{n:02d}_raw.bin",'wb').write(b); i+=1
    n+=1
