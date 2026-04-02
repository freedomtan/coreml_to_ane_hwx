#include <stdint.h>
#include <stdio.h>

/**
 * decode_unified_m4: Analyzes an ANE M4 (H16) HWX instruction stream.
 * Standardizes decoding for Register Packing and DMA Relocations.
 */
void decode_unified_m4(const uint32_t *buffer, size_t total_words) {
  size_t i = 0;
  while (i < total_words) {
    uint32_t header = buffer[i++];

    // Bits 0-14: Word Address
    uint32_t word_addr = header & 0x7FFF;
    uint32_t phys_addr = word_addr << 2;

    // Bit 31: Toggle (0 = Burst/Sequential, 1 = Single/Masked)
    if ((header >> 31) == 0) {
      // --- Burst / Sequential Mode ---
      // Bits 15-20: Register Count (6 bits)
      uint32_t num_registers = (header >> 15) & 0x3F;

      // Context Detection (Targeting Base Registers)
      if (word_addr == 0) {
        if (num_registers == 2) {
          uint32_t lo = buffer[i++];
          uint32_t hi = buffer[i++];
          printf("[OP 1] Weights DMA: 0x%08x%08x\n", hi, lo);
        } else if (num_registers == 10) {
          printf("[OP 5] Input Config (10 words):\n");
          for (uint32_t k = 0; k < 10; ++k) {
            printf("  Reg[0x%02x] = 0x%08x\n", k * 4, buffer[i++]);
          }
        } else {
          printf("[BURST] Base 0x%04x, Count %u\n", phys_addr, num_registers);
          for (uint32_t k = 0; k < num_registers; ++k) {
            printf("  Reg[0x%04x] = 0x%08x\n", (word_addr + k) << 2,
                   buffer[i++]);
          }
        }
      } else {
        printf("[BURST] Base 0x%04x, Count %u\n", phys_addr, num_registers);
        for (uint32_t k = 0; k < num_registers; ++k) {
          printf("  Reg[0x%04x] = 0x%08x\n", (word_addr + k) << 2, buffer[i++]);
        }
      }

      // --- The Dummy Word ---
      // User Discovery: There is always a 4-byte dummy word at the end of a
      // Sequential block
      if (i < total_words) {
        // uint32_t dummy = buffer[i++];
        i++; // Skip dummy
      }
    } else {
      // --- Scattered / Masked Mode ---
      uint16_t mask = (header >> 15) & 0xFFFF;
      printf("[MASK] Base: 0x%04x, Mask: 0x%04x\n", phys_addr, mask);

      for (int bit = 0; bit < 16; bit++) {
        if ((mask >> bit) & 1) {
          uint32_t val = buffer[i++];
          printf("  Reg[0x%04x] = 0x%08x\n", (word_addr + bit) << 2, val);
        }
      }

      // --- The Dummy Word ---
      // User Discovery: There is also a dummy word at the end of a Mask block
      if (i < total_words) {
        // uint32_t dummy = buffer[i++];
        i++; // Skip dummy
      }
    }
  }
}
