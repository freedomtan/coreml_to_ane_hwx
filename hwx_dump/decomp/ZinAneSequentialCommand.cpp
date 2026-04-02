#include <cstdint>

class ZinAneCommand {
public:
  virtual ~ZinAneCommand() = default;
};

class ZinAneSequentialCommand_v11 : public ZinAneCommand {
public:
  uint32_t val; // Offset 0x8

  // Constructor at 0x1a686cef8
  // w1: base offset (register index?)
  // w2: count
  ZinAneSequentialCommand_v11(uint32_t base, uint32_t count) {
    // vtable setup omitted

    // 0x1a686cf14: lsl w8, w2, #0xf
    // 0x1a686cf1c: and w8, w8, #0x1f8000
    // This takes the low 6 bits of count and places them at bits 15..20
    uint32_t tmp = (count << 15) & 0x1F8000;

    // 0x1a686cf20: bfxil w8, w1, #0x2, #0xf
    // Extract 15 bits from base starting at bit 2, insert into tmp at bit 0.
    // effectively: tmp = (tmp & ~0x7FFF) | ((base >> 2) & 0x7FFF)

    tmp = (tmp & 0xFFFF8000) | ((base >> 2) & 0x7FFF);

    this->val = tmp;
  }
};

class ZinAneSequentialCommand_v7minus : public ZinAneCommand {
public:
  uint32_t val; // Offset 0x8

  // Constructor at 0x1a6b1585c
  ZinAneSequentialCommand_v7minus(uint32_t base, uint32_t count) {
    // vtable setup omitted

    // 0x1a6b15878: bfi w1, w2, #0x1a, #0x6
    // Insert 6 bits of count into base at bit 26
    // w1 = (w1 & ~(0x3F << 26)) | ((count & 0x3F) << 26)
    uint32_t tmp = (base & 0x03FFFFFF) | ((count & 0x3F) << 26);

    // 0x1a6b1587c: mov w8, #0xfc000000
    // 0x1a6b15880: add w8, w1, w8
    // This adds a large constant offset? Or is it a mask?
    // 0xFC000000 is top 6 bits set.
    // It's an ADD instruction.
    tmp = tmp + 0xFC000000;

    this->val = tmp;
  }
};
