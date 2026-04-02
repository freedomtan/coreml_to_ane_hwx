def decode_unified_m4(buffer):
    """
    Unified ANE M4 (H16) HWX Parser
    Handles:
    - Standard Burst Writes (Sequential)
    - Single Register Writes (Masked)
    - DMA Relocations (Op 1/5/etc as burst-writes to Reg 0x0)
    """
    i = 0
    total_words = len(buffer)
    
    while i < total_words:
        header = buffer[i]
        i += 1
        
        # Bits 0-14: Word Address (Strip bottom 2 bits)
        word_addr = header & 0x7FFF
        phys_addr = word_addr << 2
        
        # Bit 31: Opcode (0=SEQ/BURST, 1=MASK/SINGLE)
        if (header >> 31) == 0:
            # --- Sequential / Burst Mode ---
            # Bits 15-20: 6-bit Register Count
            num_registers = (header >> 15) & 0x3F
            
            # Identify "Relocation" Special Cases (Targeting Reg 0x0)
            if word_addr == 0 and num_registers == 2:
                # Op 1: Weights Base Addr (64-bit)
                lo, hi = buffer[i], buffer[i+1]
                print(f"[OP 1] Weights DMA Base: 0x{hi:08x}{lo:08x}")
                i += 2
            elif word_addr == 0 and num_registers == 10:
                # Op 5: Input Dimensions / TD Header
                print(f"[OP 5] Input Config Block (10 words):")
                for k in range(10):
                    print(f"  Reg[0x{k*4:02x}] = 0x{buffer[i]:08x}")
                    i += 1
            else:
                # Standard Register Burst
                print(f"[BURST] Base: 0x{phys_addr:04x}, Count: {num_registers}")
                for k in range(num_registers):
                    val = buffer[i]
                    print(f"  Reg[0x{(phys_addr + k*4):04x}] = 0x{val:08x}")
                    i += 1
            
            # --- The Dummy Word ---
            # User Discovery: There is always a 4-byte dummy word at the end of a Sequential block
            if i < total_words:
                dummy = buffer[i]
                # print(f"  (Skipping Dummy Word: 0x{dummy:08x})")
                i += 1
        else:
            # --- Masked / Scattered Mode ---
            # Mask is 16 bits (15 to 30)
            mask = (header >> 15) & 0xFFFF
            
            # Count set bits (Popcount)
            count = bin(mask).count('1')
            print(f"[MASK] Base: 0x{phys_addr:04x}, Mask: 0x{mask:04x} ({count} regs)")
            
            for bit in range(16):
                if (mask >> bit) & 1:
                    val = buffer[i]
                    reg_addr = phys_addr + (bit << 2)
                    print(f"  Reg[0x{reg_addr:04x}] = 0x{val:08x}")
                    i += 1
            
            # --- The Dummy Word ---
            # User Discovery: There is also a dummy word at the end of a Mask/Scattered block
            if i < total_words:
                dummy = buffer[i]
                # print(f"  (Skipping Dummy Word: 0x{dummy:08x})")
                i += 1

# Example Usage with a Weights Relocation (Op 1)
# sample_hwx = [
#     0x00010000, # SEQ, Count 2, Addr 0 (OP 1)
#     0x12345678, # LoAddr
#     0x00000009  # HiAddr
# ]
# decode_unified_m4(sample_hwx)
