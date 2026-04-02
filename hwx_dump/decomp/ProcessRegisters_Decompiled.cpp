#include <algorithm>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// --- ANE Command Base Classes (Pseudocode) ---

struct ZinAneCommand {
  virtual ~ZinAneCommand() = default;
  virtual uint32_t GetWordCount() const = 0;
};

// --- Command Constructors (Decompiled from assembly) ---

/**
 * ZinAneSequentialCommand_v11: Represents a sequential block of registers for
 * H16 (M4). Encodings:
 * - base: Target register address (unscaled, >> 2)
 * - count: Number of registers in this block (1 to 64)
 */
struct ZinAneSequentialCommand_v11 : public ZinAneCommand {
  uint32_t val;
  ZinAneSequentialCommand_v11(uint32_t base, uint32_t count) {
    // Bits 0-14: Word Address (unscaled >> 2)
    // Bits 15-20: Count (Verified by ubfx in disassembly)
    uint32_t c_bits = (count << 15) & 0x001F8000;
    uint32_t b_bits = (base >> 2) & 0x00007FFF;
    this->val = c_bits | b_bits;
  }
  uint32_t GetWordCount() const override {
    // Returns RegisterCount + 1 (The compiler includes the dummy word in the
    // total)
    return ((val >> 15) & 0x3F) + 1;
  }
};

/**
 * ZinAneSequentialCommand_v7minus: Represents a sequential block of registers
 * for H13 (M1).
 */
struct ZinAneSequentialCommand_v7minus : public ZinAneCommand {
  uint32_t val;
  ZinAneSequentialCommand_v7minus(uint32_t base, uint32_t count) {
    // Assembly: 0x1a6b15878 - 0x1a6b15884
    // bfi w1, w2, #0x1a, #0x6 -> count at bit 26
    // mov w8, #0xfc000000
    // add w8, w1, w8 -> mysterious offset mapping
    this->val = (base & 0x03FFFFFF) | (count << 26) | 0xFC000000;
  }
  uint32_t GetWordCount() const override { return 1 + (val >> 26 & 0x3F); }
};

/**
 * ZinAneMaskCommand_v11: Represents a masked register write for H16 (M4).
 * Header Layout:
 * [Bit 31]: Opcode (1 = Mask)
 * [Bits 30-15]: Data bitfield or Partial Mask
 * [Bits 14-0]: Base Address (unscaled >> 2)
 */
struct ZinAneMaskCommand_v11 : public ZinAneCommand {
  uint32_t head;
  std::vector<uint32_t> data;
  ZinAneMaskCommand_v11(uint32_t base, uint32_t mask,
                        const std::vector<uint32_t> &values) {
    // Bits 31: Opcode (1 = Mask)
    // Bits 30-15: 16-bit Mask (each bit = 1 register)
    // Bits 14-0: Base Address (unscaled >> 2)
    this->head =
        0x80000000 | ((mask << 15) & 0x7FFF8000) | ((base >> 2) & 0x7FFF);
    this->data = values;
  }
  uint32_t GetWordCount() const override {
    // Header + one word per set bit in the mask
    return 1 + data.size();
  }
};

// --- Internal Data Structures for Optimization ---

namespace ZinRegisterPacking {

struct Command {
  uint32_t type; // 0: Masked, 1: Sequential
  uint32_t count;
  uint32_t offset;
};

/**
 * IntermediatePackingResult: Used by the DP optimizer to track costs.
 */
struct IntermediatePackingResult {
  uint32_t cost;       // total words to cover from this point
  uint32_t mode;       // 1: Sequential, 0: Mask
  uint32_t step;       // how many registers this command covers
  uint32_t base_index; // original register index
};

/**
 * GetOptimalCommands: The core of the ANE compiler's register packing
 * optimizer. Uses Dynamic Programming to minimize the number of words used to
 * program a list of registers.
 *
 * It solves: dp[i] = min(COST_MASK + dp[i+1], COST_SEQ(N) + dp[i+N])
 */
void GetOptimalCommands(const std::vector<uint32_t> &registers,
                        std::vector<Command> &optimal_cmds, bool is_v11) {
  size_t n = registers.size();
  if (n == 0)
    return;

  std::vector<IntermediatePackingResult> dp(n + 1);
  dp[n] = {0, 0, 0, 0};

  // Iterate backwards through registers (assembly: 0x1a6b6fb4c to 0x1a6b6fc88)
  for (int i = (int)n - 1; i >= 0; --i) {
    // Option 1: Program current register as a single Mask Command (Cost = 2
    // words)
    uint32_t best_cost = 2 + dp[i + 1].cost;
    uint32_t best_mode = 0; // Mask
    uint32_t best_step = 1;

    // Option 2: Try covering a range [i, i+k] with a single Sequential Command
    // (Cost = 1 + k words) Limitations: Sequential block must have contiguous
    // addresses and max length (usually 64)
    for (int k = 1; k <= 64 && (i + k) <= n; ++k) {
      // Heuristic: Check if registers are contiguous or dense enough
      // In assembly, this involves checking if (reg[i+k] - reg[i]) == k
      bool is_contiguous = true; // In assembly, 0x1a6b6fba0 check

      if (is_contiguous) {
        uint32_t seq_cost = (1 + k) + dp[i + k].cost;
        if (seq_cost < best_cost) {
          best_cost = seq_cost;
          best_mode = 1; // Sequential
          best_step = k;
        }
      } else {
        break; // Break if gap is too large for sequential
      }
    }
    dp[i] = {best_cost, best_mode, best_step, (uint32_t)i};
  }

  // Reconstruct the optimal path from dp table
  int current = 0;
  while (current < n) {
    optimal_cmds.push_back(
        {dp[current].mode, dp[current].step, (uint32_t)current});
    current += dp[current].step;
  }
}

/**
 * ProcessRegisters: The main entry point for register serialization.
 * 1. Filters inputs against the skip_set.
 * 2. Resolves addresses using reg_map.
 * 3. Runs the DP optimizer to group registers.
 * 4. Encodes and writes the final command stream.
 */
uint32_t ProcessRegisters(const uint32_t *src, size_t count, uint32_t base_addr,
                          uint32_t *output_ptr, PackTask task, PackMode mode,
                          const std::unordered_map<uint32_t, uint32_t> &reg_map,
                          const std::unordered_set<uint32_t> &skip_set,
                          bool optimize, const std::vector<uint32_t> &extra) {
  std::vector<uint32_t> filtered_regs;
  uint32_t words_written = 0;

  // Loop 1: Filtering and Mapping (Assembly: 0x1a695ddd4 to 0x1a695df1c)
  for (uint32_t i = 0; i < count; ++i) {
    uint32_t addr = base_addr + (i << 2);
    if (skip_set.find(addr) != skip_set.end())
      continue;

    auto it = reg_map.find(addr);
    if (it == reg_map.end())
      continue;

    // In assembly, it checks against some 'extra' list or flags
    // to decide if this register is "active" for this pass.
    filtered_regs.push_back(i);
  }

  // Loop 2: Command Selection and Encoding
  std::vector<Command> command_list;
  GetOptimalCommands(filtered_regs, command_list,
                     true); // Simplified to always v11 for this dump

  for (const auto &cmd : command_list) {
    if (cmd.type == 1) { // Sequential
      // Instantiate v11 or v7 based on target
      auto *s_cmd = new ZinAneSequentialCommand_v11(
          base_addr + (cmd.offset << 2), cmd.count);
      output_ptr[words_written++] = s_cmd->val;

      // Copy the actual register data values
      for (uint32_t k = 0; k < cmd.count; ++k) {
        output_ptr[words_written++] = src[cmd.offset + k];
      }
      delete s_cmd;
    } else { // Masked / Scattered
      // Calculate mask from filtered registers (simplified for this decomp)
      uint32_t mask = 1; // Bit 0 set
      std::vector<uint32_t> vals = {src[cmd.offset]};

      auto *m_cmd =
          new ZinAneMaskCommand_v11(base_addr + (cmd.offset << 2), mask, vals);
      output_ptr[words_written++] = m_cmd->head;
      for (uint32_t v : m_cmd->data) {
        output_ptr[words_written++] = v;
      }
      delete m_cmd;
    }
  }

  return words_written;
}
} // namespace ZinRegisterPacking
