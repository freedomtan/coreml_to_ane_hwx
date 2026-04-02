#include <cstdint>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// --- ANE Data Structures ---

/**
 * ZinTdCodegenParams: Parameters for the TD (Task Descriptor) code generation.
 * Contains metadata and pointers to the current instruction stream.
 */
struct ZinTdCodegenParams {
  uint8_t padding[0xd0];
  struct ZinAneTdInstruction *current_instr; // Found at Offset 0xd0
};

/**
 * ZinAneTdInstruction: Represents a single ANE instruction (e.g., a convolution
 * task). Contains the hardware register values and metadata.
 */
struct ZinAneTdInstruction {
  // Header words (0x00 to 0x24 in H14 ANE)
  // In memory, these start at offset 0x8 of the object
  uint32_t header[10]; // Offset 0x8 to 0x2c

  // Get information about registers that require relocation (DMA addresses)
  std::vector<struct ZinAneRelocInfo> GetRelocInfos() const;

  // Get raw register value for a specific unscaled address
  uint32_t GetRegisterValueFromAddress(uint32_t addr) const;
};

/**
 * ZinAneRelocInfo: Metadata for a relocatable field in the task.
 */
struct ZinAneRelocInfo {
  uint8_t type;    // Offset 0x0
  uint8_t subtype; // Offset 0x1
  uint8_t padding[0x1e];
  uint32_t word0; // Offset 0x20 - The command word to write to the binary
};

// --- Register Packing Logic ---

namespace ZinRegisterPacking {
enum class PackTask : uint32_t { Default = 1 };
enum class PackMode : uint32_t { Sequential = 1, Masked = 2 };
/**
 * ProcessRegisters: Packs raw register values into ANE-specific commands.
 * returns the number of 32-bit words written to the output buffer.
 */
uint32_t ProcessRegisters(const uint32_t *src, size_t count, uint32_t base_addr,
                          uint32_t *output_ptr, PackTask task, PackMode mode,
                          const std::unordered_map<uint32_t, uint32_t> &reg_map,
                          const std::unordered_set<uint32_t> &skip_set,
                          bool optimize, const std::vector<uint32_t> &extra);
} // namespace ZinRegisterPacking

// --- Helper Declarations ---

template <unsigned int T>
std::unordered_set<uint32_t>
GetDontCareRegisters(const ZinAneTdInstruction *instr);

void AddBARRelocation(const std::string &name, struct ZinIrSection *sec,
                      uint64_t addr, bool flag,
                      std::vector<struct ZinIrSymbolData> &symbols,
                      uint64_t displacement, uint8_t type);
void AddRelocation(const std::string &name, struct ZinIrSection *sec,
                   uint64_t addr, bool flag,
                   std::vector<struct ZinIrSymbolData> &symbols);
void AddSymbol(const std::string &name, struct ZinIrSection *sec,
               uint32_t displacement, uint32_t size,
               std::vector<struct ZinIrSymbolData> &symbols);

/**
 * ZinAneRelocationCommand_v11: Helper to decode relocation command words.
 */
struct ZinAneRelocationCommand_v11 {
  uint32_t word;
  ZinAneRelocationCommand_v11(uint32_t w) : word(w) {}
  uint32_t GetAddress() const { return (word & 0x7FFF) << 2; }
};

// --- Decompiled Function ---

/**
 * DumpTask<17u>: Specialization for M4 / H16 architecture.
 * This function serializes a high-level Zin instruction into the raw binary
 * form expected by the ANE HWX format.
 *
 * Template <17u> refers to Instruction version 17 (v17).
 */
template <unsigned int TaskType>
void DumpTask(const std::unordered_map<uint32_t, uint32_t> &reg_map, // x24
              const ZinTdCodegenParams &params,                      // x20
              std::vector<struct ZinIrSymbolData> &symbols,          // x19
              const ZinAneTdInstruction
                  *instr_begin, // x22 (actually calculated from x25)
              const ZinAneTdInstruction *instr_end,
              struct ZinIrNetworkStatus *status,
              ZinRegisterPacking::PackMode pack_mode, // x23
              uint32_t **output_ptr_ref, // x21 (pointer to the pointer)
              struct ZinIrSection *section1, struct ZinIrSection *section2,
              int flags) {
  // 1. Get the instruction object
  const ZinAneTdInstruction *instr =
      params.current_instr; // ldr x25, [x3, #0xd0]

  // 2. Setup Symbol names (Internal)
  std::string base_name = "__nid0__tid"; // bl basic_string constructor
  std::string task_name =
      base_name +
      std::to_string(instr->header[0] >> 16); // Heuristic demangling

  // 3. Manual Header Copy (9 Mandatory Words + 1 Optional)
  // This copies the A64 Task Descriptor Header.
  // In M4/H16, the standard header is 9 words (36 bytes).
  uint32_t *out = *output_ptr_ref;
  for (int i = 0; i < 9; ++i) {
    out[i] = instr->header[i];
  }

  // Check if the 10th word (offset 0x24) should be copied.
  // Flag is bit 1 of Word 8 (instr->header[8]).
  if (instr->header[8] & 0x2) {
    out[9] = instr->header[9];
    *output_ptr_ref += 10;
  } else {
    *output_ptr_ref += 9;
  }

  // 4. Extract Displacement / Offset
  // Used for calculating symbol offsets relative to the section start.
  uint32_t displacement =
      (uint32_t)(*output_ptr_ref - (uint32_t *)0); // Simplified

  // 5. Register Packing - Block 1 (A15/M2 Style Dense Range)
  // Base: 0x5500, Count: 72
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x30), 0x48, 0x5500, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map,
      GetDontCareRegisters<17u>(instr), false, {});

  // 6. Register Packing - Block 2 (Header / Control)
  // Base: 0, Count: 23
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x1f8), 0x17, 0, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 7. Register Packing - Block 3 (L2 Config Group)
  // Base: 0x4d00, Count: 81
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x25c), 0x51, 0x4d00, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 8. Register Packing - Block 4 (NE Core Cfg)
  // Base: 0x4100, Count: 41
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x3a8), 0x29, 0x4100, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 9. Register Packing - Block 5 (NE Core Ext)
  // Base: 0x4500, Count: 15
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x454), 0x0f, 0x4500, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 10. Register Packing - Block 6 (NE Misc)
  // Base: 0x4900, Count: 12
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x498), 0x0c, 0x4900, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 11. Register Packing - Block 7 (Common Layer Cfg)
  // Base: 0x5100, Count: 21
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x4d0), 0x15, 0x5100, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 12. Register Packing - Block 8 (Misc Extension)
  // Base: 0x5900, Count: 12
  *output_ptr_ref += ZinRegisterPacking::ProcessRegisters(
      (uint32_t *)((uint8_t *)instr + 0x52c), 0x0c, 0x5900, *output_ptr_ref,
      ZinRegisterPacking::PackTask::Default, pack_mode, reg_map, {}, false, {});

  // 7. Handle Relocations (DMA Base Addresses)
  // This is where BaseAddrLo/Hi are written.
  std::vector<ZinAneRelocInfo> relocs = instr->GetRelocInfos();
  for (const auto &reloc : relocs) {
    uint32_t cmd_word = reloc.word0;
    **output_ptr_ref = cmd_word; // Write the "Relocation Command" (e.g., Op 1)
    (*output_ptr_ref)++;

    // Add to internal symbol table for later patching by the loader
    if (reloc.type == 1) {
      if (reloc.subtype == 1) {
        AddBARRelocation(task_name, section1, 0, false, symbols, displacement,
                         7);
      } else {
        AddRelocation(task_name, section1, 0, false, symbols);
      }
    }

    // Write the actual register value associated with this relocation
    // The loader will later overwrite this with the physical address.
    ZinAneRelocationCommand_v11 cmd(cmd_word);
    uint32_t addr = cmd.GetAddress();
    **output_ptr_ref = instr->GetRegisterValueFromAddress(addr);
    (*output_ptr_ref)++;

    // If it's a 64-bit address (M4/H16), usually indicated by a multi-word
    // burst (Count >= 2 targeting a BaseAddr register). Note: The specific bit
    // 15 flag might be use-case dependent, but the word stream follows the
    // Count field.
    if (((cmd_word >> 15) & 0x1FF) >= 2) {
      **output_ptr_ref = instr->GetRegisterValueFromAddress(addr + 4);
      (*output_ptr_ref)++;
    }
  }

  // 8. Finalize Symbol
  AddSymbol(task_name, section1, displacement, 0, symbols);
}
