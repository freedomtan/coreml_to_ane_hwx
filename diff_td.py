import struct
import sys

HWX_MAGIC_64 = 0xbeefface
LC_SEGMENT_64 = 0x19

def parse_hwx(filename):
    with open(filename, 'rb') as f:
        magic = struct.unpack('<I', f.read(4))[0]
        if magic != HWX_MAGIC_64:
            return None

        f.seek(16)
        ncmds, sizeofcmds = struct.unpack('<II', f.read(8))

        text_offset = None
        current_pos = 32
        for i in range(ncmds):
            f.seek(current_pos)
            cmd_type, cmd_size = struct.unpack('<II', f.read(8))
            if cmd_type == LC_SEGMENT_64:
                seg_data = struct.unpack('<16sQQQQiiII', f.read(8 * 4 + 16 + 4 * 4))
                segname = seg_data[0].strip(b'\x00').decode('ascii')
                nsects = seg_data[7]
                for j in range(nsects):
                    sect_data = struct.unpack('<16s16sQQIIIIIIII', f.read(16 + 16 + 8 * 2 + 4 * 8))
                    sectname = sect_data[0].strip(b'\x00').decode('ascii')
                    if sectname == '__text' and segname == '__TEXT':
                        text_offset = sect_data[4]
            current_pos += cmd_size

        if text_offset is None:
            return None

        tds = []
        current_offset = text_offset
        while True:
            f.seek(current_offset)
            td_raw = f.read(0x300)
            if len(td_raw) < 0x300: break
            tds.append(td_raw)
            next_ptr = struct.unpack('<I', td_raw[28:32])[0]
            if next_ptr == 0: break
            current_offset = text_offset + next_ptr
        
        return tds

def diff_tds(td1, td2):
    print(f"{'Offset':8} | {'TD1 Val':8} | {'TD2 Val':8} | {'Notes'}")
    print("-" * 50)
    for i in range(0, 0x300, 4):
        v1 = struct.unpack('<I', td1[i:i+4])[0]
        v2 = struct.unpack('<I', td2[i:i+4])[0]
        if v1 != v2:
            notes = ""
            if i == 0x130: notes = "Common.ChCfg"
            if i == 0x1e4: notes = "L2.SourceCfg"
            if i == 0x210: notes = "L2.ResultCfg"
            if i == 0x1a4: notes = "TileDmaSrc.Fmt"
            if i == 0x270: notes = "TileDmaDst.Fmt"
            if i == 0x240: notes = "NE.KernelCfg"
            if i == 0x128: notes = "InDim"
            if i == 0x13c: notes = "OutDim"
            if i == 0x134: notes = "Cin"
            if i == 0x138: notes = "Cout"
            if i == 0x01c: notes = "NextPointer"
            if i == 0x160: notes = "TaskInfo (TaskID)"
            
            print(f"0x{i:03x}    | 0x{v1:08x} | 0x{v2:08x} | {notes}")

if __name__ == "__main__":
    tds = parse_hwx(sys.argv[1])
    if tds and len(tds) >= 2:
        print("Diffing TD 1 and TD 2:")
        diff_tds(tds[0], tds[1])
        print("\nDiffing TD 2 and TD 3:")
        diff_tds(tds[1], tds[2])
