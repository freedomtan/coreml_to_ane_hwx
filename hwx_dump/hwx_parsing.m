#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <unistd.h>

#define HWX_MAGIC 0xbeefface
#define LC_ANE_MAPPED_REGION 0x40

typedef struct __attribute__((packed)) {
  uint16_t tid;             // 0x000
  uint8_t nid;              // 0x002
  uint8_t lnid_eon;         // 0x003: LNID (bit 0), EON (bit 1)
  uint16_t exe_cycles;      // 0x004
  uint16_t next_size_pad;   // 0x006: NextSize (9 bits), Pad (7 bits)
  uint32_t log_events : 24; // 0x008
  uint32_t pad0 : 8;
  uint32_t exceptions : 24; // 0x00c
  uint32_t pad1 : 8;
  uint32_t debug_log_events : 24; // 0x010
  uint32_t pad2 : 8;
  uint32_t debug_exceptions : 24; // 0x014
  uint32_t pad3 : 8;
  uint32_t flags;        // 0x018
  uint32_t next_pointer; // 0x01c
} ane_td_header_t;

const char *get_ch_fmt_name(uint32_t fmt) {
  switch (fmt) {
  case 0:
    return "UINT8";
  case 1:
    return "INT8";
  case 2:
    return "FLOAT16";
  case 3:
    return "INT32";
  default:
    return "Unknown";
  }
}

void decode_ane_td(const uint8_t *ptr, size_t total_len) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_td_header_t) <= total_len) {
    const ane_td_header_t *td = (const ane_td_header_t *)(ptr + offset);
    printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
    printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid,
           td->nid, td->lnid_eon & 1, (td->lnid_eon >> 1) & 1);
    printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles,
           td->next_size_pad & 0x1FF);
    printf("        Flags: 0x%08x NextPointer: 0x%08x\n", td->flags,
           td->next_pointer);

    // Decode some common registers if they fit in the section
    if (offset + 0x140 <= total_len) {
      const uint32_t *regs = (const uint32_t *)(ptr + offset);
      // InDim: 0x128
      uint32_t indim = regs[0x128 / 4];
      uint16_t win = indim & 0x7FFF;
      uint16_t hin = (indim >> 16) & 0x7FFF;

      // ChCfg: 0x130
      uint32_t chcfg = regs[0x130 / 4];
      const char *infmt_name = get_ch_fmt_name(chcfg & 0x3);
      const char *outfmt_name = get_ch_fmt_name((chcfg >> 4) & 0x3);

      // Cin: 0x134, Cout: 0x138
      uint32_t cin = regs[0x134 / 4] & 0x1FFFF;
      uint32_t cout = regs[0x138 / 4] & 0x1FFFF;

      // OutDim: 0x13c
      uint32_t outdim = regs[0x13c / 4];
      uint16_t wout = outdim & 0x7FFF;
      uint16_t hout = (outdim >> 16) & 0x7FFF;

      printf("        %u x %u x %u (%s) -> %u x %u x %u (%s)\n", win, hin, cin,
             infmt_name, wout, hout, cout, outfmt_name);

      // ConvCfg: 0x144
      uint32_t convcfg = regs[0x144 / 4];
      uint8_t kw = convcfg & 0x1F;
      uint8_t kh = (convcfg >> 5) & 0x1F;

      if (kw != 0 || kh != 0) {
        uint8_t sx = (convcfg >> 13) & 0x3;
        uint8_t sy = (convcfg >> 15) & 0x3;
        uint8_t px = (convcfg >> 17) & 0x1F;
        uint8_t py = (convcfg >> 22) & 0x1F;
        printf("        ConvCfg: K=%ux%u S=%ux%u P=%ux%u\n", kw, kh, sx, sy, px,
               py);

        // GroupConvCfg: 0x14c
        uint32_t groupcfg = regs[0x14c / 4];
        uint16_t num_groups = groupcfg & 0x1FFF;
        uint16_t unicast_cin = (groupcfg >> 16) & 0xFFFF;
        printf("        GroupConvCfg: Groups=%u UnicastEn=%d ElemMult=%d "
               "UnicastCin=%u\n",
               num_groups, (groupcfg >> 14) & 1, (groupcfg >> 15) & 1,
               unicast_cin);
      }

      // Show NE and L2 details for all layers
      uint32_t common_cfg = regs[0x15c / 4];
      uint32_t active_ne = (common_cfg >> 18) & 0x7;
      printf("        ActiveNE: %u\n", active_ne);

      uint32_t maccfg = regs[0x244 / 4];
      uint8_t op_mode = maccfg & 0xF;
      uint8_t nl_mode = (maccfg >> 16) & 0x3;
      printf(
          "        NE MACCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d\n",
          op_mode, nl_mode, (maccfg >> 4) & 1, (maccfg >> 5) & 1);

      uint32_t l2cfg = regs[0x1e0 / 4];
      printf("        L2Cfg: InputRelu=%d PaddingMode=%u\n", l2cfg & 1,
             (l2cfg >> 1) & 0x3);

      // Show L2 Source and Result Cfg
      if (offset + 0x218 <= total_len) {
        // regs is already defined and points to the start of the current task's
        // registers

        uint32_t scfg = regs[0x1e4 / 4];
        printf("        SourceCfg: Type=%u Dep=%u Fmt=%u Intrlv=%u CmpV=%u "
               "OffCh=%u\n",
               scfg & 0x3, (scfg >> 2) & 0x3, (scfg >> 6) & 0x3,
               (scfg >> 8) & 0xF, (scfg >> 12) & 0xF, (scfg >> 16) & 0x7);

        uint32_t rcfg = regs[0x210 / 4];
        printf("        ResultCfg: Type=%u Bfr=%u Fmt=%u Intrlv=%u CmpV=%u "
               "OffCh=%u\n",
               rcfg & 0x3, (rcfg >> 2) & 0x3, (rcfg >> 6) & 0x3,
               (rcfg >> 8) & 0xF, (rcfg >> 12) & 0xF, (rcfg >> 16) & 0x7);
      }
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset)
      break;
    offset = td->next_pointer;
  }
}

void hex_dump(const char *label, const uint8_t *ptr, size_t len) {
  printf("      %s (%zu bytes):\n", label, len);
  for (size_t i = 0; i < len; i += 16) {
    printf("        %04lx: ", i);
    for (size_t j = 0; j < 16; j++) {
      if (i + j < len)
        printf("%02x ", ptr[i + j]);
      else
        printf("   ");
    }
    printf(" |");
    for (size_t j = 0; j < 16; j++) {
      if (i + j < len) {
        char c = ptr[i + j];
        printf("%c", (c >= 32 && c <= 126) ? c : '.');
      }
    }
    printf("|\n");
  }
}

const char *get_cmd_name(uint32_t cmd) {
  switch (cmd) {
  case LC_SEGMENT:
    return "LC_SEGMENT";
  case LC_SYMTAB:
    return "LC_SYMTAB";
  case LC_SYMSEG:
    return "LC_SYMSEG";
  case LC_THREAD:
    return "LC_THREAD";
  case LC_UNIXTHREAD:
    return "LC_UNIXTHREAD";
  case LC_LOADFVMLIB:
    return "LC_LOADFVMLIB";
  case LC_IDFVMLIB:
    return "LC_IDFVMLIB";
  case LC_IDENT:
    return "LC_IDENT";
  case LC_FVMFILE:
    return "LC_FVMFILE";
  case LC_PREPAGE:
    return "LC_PREPAGE";
  case LC_DYSYMTAB:
    return "LC_DYSYMTAB";
  case LC_LOAD_DYLIB:
    return "LC_LOAD_DYLIB";
  case LC_ID_DYLIB:
    return "LC_ID_DYLIB";
  case LC_LOAD_DYLINKER:
    return "LC_LOAD_DYLINKER";
  case LC_ID_DYLINKER:
    return "LC_ID_DYLINKER";
  case LC_PREBOUND_DYLIB:
    return "LC_PREBOUND_DYLIB";
  case LC_ROUTINES:
    return "LC_ROUTINES";
  case LC_SUB_FRAMEWORK:
    return "LC_SUB_FRAMEWORK";
  case LC_SUB_UMBRELLA:
    return "LC_SUB_UMBRELLA";
  case LC_SUB_CLIENT:
    return "LC_SUB_CLIENT";
  case LC_SUB_LIBRARY:
    return "LC_SUB_LIBRARY";
  case LC_TWOLEVEL_HINTS:
    return "LC_TWOLEVEL_HINTS";
  case LC_PREBIND_CKSUM:
    return "LC_PREBIND_CKSUM";
  case LC_LOAD_WEAK_DYLIB:
    return "LC_LOAD_WEAK_DYLIB";
  case LC_SEGMENT_64:
    return "LC_SEGMENT_64";
  case LC_ROUTINES_64:
    return "LC_ROUTINES_64";
  case LC_UUID:
    return "LC_UUID";
  case LC_RPATH:
    return "LC_RPATH";
  case LC_CODE_SIGNATURE:
    return "LC_CODE_SIGNATURE";
  case LC_SEGMENT_SPLIT_INFO:
    return "LC_SEGMENT_SPLIT_INFO";
  case LC_REEXPORT_DYLIB:
    return "LC_REEXPORT_DYLIB";
  case LC_LAZY_LOAD_DYLIB:
    return "LC_LAZY_LOAD_DYLIB";
  case LC_ENCRYPTION_INFO:
    return "LC_ENCRYPTION_INFO";
  case LC_DYLD_INFO:
    return "LC_DYLD_INFO";
  case LC_DYLD_INFO_ONLY:
    return "LC_DYLD_INFO_ONLY";
  case LC_LOAD_UPWARD_DYLIB:
    return "LC_LOAD_UPWARD_DYLIB";
  case LC_VERSION_MIN_MACOSX:
    return "LC_VERSION_MIN_MACOSX";
  case LC_VERSION_MIN_IPHONEOS:
    return "LC_VERSION_MIN_IPHONEOS";
  case LC_FUNCTION_STARTS:
    return "LC_FUNCTION_STARTS";
  case LC_DYLD_ENVIRONMENT:
    return "LC_DYLD_ENVIRONMENT";
  case LC_MAIN:
    return "LC_MAIN";
  case LC_DATA_IN_CODE:
    return "LC_DATA_IN_CODE";
  case LC_SOURCE_VERSION:
    return "LC_SOURCE_VERSION";
  case LC_DYLIB_CODE_SIGN_DRS:
    return "LC_DYLIB_CODE_SIGN_DRS";
  case LC_ENCRYPTION_INFO_64:
    return "LC_ENCRYPTION_INFO_64";
  case LC_LINKER_OPTION:
    return "LC_LINKER_OPTION";
  case LC_LINKER_OPTIMIZATION_HINT:
    return "LC_LINKER_OPTIMIZATION_HINT";
  case LC_VERSION_MIN_TVOS:
    return "LC_VERSION_MIN_TVOS";
  case LC_VERSION_MIN_WATCHOS:
    return "LC_VERSION_MIN_WATCHOS";
  case LC_NOTE:
    return "LC_NOTE";
  case LC_BUILD_VERSION:
    return "LC_BUILD_VERSION";
  case LC_ANE_MAPPED_REGION:
    return "LC_ANE_MAPPED_REGION"; // Mapped region based on ANECompiler 'Zin'
                                   // generation
  default:
    return "UNKNOWN";
  }
}

void print_macho_headers(NSData *data, BOOL dump_all_symbols, BOOL dump_threads,
                         BOOL dump_hexdump) {
  if (data.length < sizeof(struct mach_header_64)) {
    printf("Error: File too small.\n");
    return;
  }

  const struct mach_header_64 *header =
      (const struct mach_header_64 *)data.bytes;

  uint32_t magic = header->magic;
  if (magic != HWX_MAGIC) {
    printf("Error: Invalid magic 0x%08x (Expected 0x%08x)\n", magic, HWX_MAGIC);
    return;
  }
  printf("Magic verified: 0x%08x\n", magic);

  if (data.length < 32)
    return;

  printf("CPU Type: 0x%04x\n", header->cputype);
  printf("CPU Subtype: 0x%04x\n", header->cpusubtype);
  printf("File Type: 0x%04x\n", header->filetype);
  printf("Number of Load Commands: 0x%04x\n", header->ncmds);
  printf("Size of Load Commands: 0x%04x\n", header->sizeofcmds);
  printf("Flags: 0x%04x\n", header->flags);

  uint32_t offset = 32;
  for (uint32_t i = 0; i < header->ncmds; i++) {
    if (offset + sizeof(struct load_command) > data.length) {
      printf("Error: Unexpected EOF reading load command %u\n", i);
      break;
    }

    const struct load_command *lc =
        (const struct load_command *)(data.bytes + offset);
    const char *cmd_name = get_cmd_name(lc->cmd);

    printf("\nLoad Command %u:\n", i);
    printf("  Cmd: 0x%x (%s)\n", lc->cmd, cmd_name);
    printf("  Size: %u\n", lc->cmdsize);

    if (lc->cmd == LC_SEGMENT_64) {
      if (offset + sizeof(struct segment_command_64) <= data.length) {
        const struct segment_command_64 *seg =
            (const struct segment_command_64 *)lc;
        printf("  Segment Name: %s\n", seg->segname);
        printf("  VM Addr: 0x%llx\n", seg->vmaddr);
        printf("  VM Size: 0x%llx\n", seg->vmsize);
        printf("  File Off: 0x%llx\n", seg->fileoff);
        printf("  File Size: 0x%llx\n", seg->filesize);
        printf("  Num Sections: %u\n", seg->nsects);

        const struct section_64 *sect =
            (const struct section_64 *)(data.bytes + offset +
                                        sizeof(struct segment_command_64));
        for (uint32_t j = 0; j < seg->nsects; j++) {
          if ((uintptr_t)(sect + 1) > (uintptr_t)(data.bytes + data.length))
            break;
          printf("    Section %u:\n", j);
          printf("      Name: %s\n", sect->sectname);
          printf("      Segment: %s\n", sect->segname);
          printf("      Addr: 0x%llx\n", sect->addr);
          printf("      Size: 0x%llx\n", sect->size);
          printf("      Offset: 0x%x\n", sect->offset);
          printf("      Flags: 0x%x\n", sect->flags);

          if (strcmp(seg->segname, "__TEXT") == 0) {
            if (sect->offset + sect->size <= data.length) {
              const uint8_t *section_ptr =
                  (const uint8_t *)data.bytes + sect->offset;
              size_t section_size = (size_t)sect->size;

              if (strcmp(sect->sectname, "__text") == 0 ||
                  strcmp(sect->sectname, "__TEXT") == 0) {
                decode_ane_td(section_ptr, section_size);
                if (dump_hexdump) {
                  hex_dump(sect->sectname, section_ptr, section_size);
                }
              }
            }
          }

          sect++;
        }
      }
    } else if (lc->cmd == LC_SYMTAB) {
      if (offset + sizeof(struct symtab_command) <= data.length) {
        const struct symtab_command *sym = (const struct symtab_command *)lc;
        printf("  Symbol Table Offset: 0x%x\n", sym->symoff);
        printf("  Num Symbols: %u\n", sym->nsyms);
        printf("  String Table Offset: 0x%x\n", sym->stroff);

        if (sym->nsyms > 0 && sym->symoff < data.length) {
          uint32_t max_syms = dump_all_symbols ? sym->nsyms : 5;
          if (!dump_all_symbols && sym->nsyms > 5) {
            printf("    (Printing first 5 symbols - use -s to see all)\n");
          } else {
            printf("    (Printing %u symbols)\n", max_syms);
          }

          const struct nlist_64 *list =
              (const struct nlist_64 *)(data.bytes + sym->symoff);
          const char *strtab = (const char *)(data.bytes + sym->stroff);

          for (uint32_t k = 0; k < max_syms; k++) {
            if ((uintptr_t)(list + 1) > (uintptr_t)(data.bytes + data.length))
              break;
            const char *name = "";
            if (list->n_un.n_strx < sym->strsize) {
              name = strtab + list->n_un.n_strx;
            }
            printf("    [%u] %s @ 0x%llx\n", k, name, list->n_value);
            list++;
          }
        }
      }
    } else if (lc->cmd == LC_THREAD || lc->cmd == LC_UNIXTHREAD) {
      if (dump_threads) {
        uint32_t internal_offset = 8;
        uint32_t flavor_idx = 0;
        while (internal_offset + 8 <= lc->cmdsize) {
          const uint32_t *content =
              (const uint32_t *)((const uint8_t *)lc + internal_offset);
          uint32_t flavor = content[0];
          uint32_t count = content[1];
          printf("  Flavor Set %u: Flavor=%u Count=%u\n", flavor_idx++, flavor,
                 count);

          internal_offset += 8;
          const uint32_t *state = content + 2;
          printf("    State:\n");
          for (uint32_t k = 0; k < count; k++) {
            if (internal_offset + 4 > lc->cmdsize)
              break;
            if (k % 4 == 0)
              printf("      [%03u]:", k);
            printf(" 0x%08x", state[k]);
            if (k % 4 == 3 || k == count - 1)
              printf("\n");
            internal_offset += 4;
          }
        }
      } else {
      }
    } else if (lc->cmd == LC_NOTE) {
      if (lc->cmdsize >= sizeof(struct note_command)) {
        const struct note_command *nc = (const struct note_command *)lc;
        printf("  Data Owner: %.16s\n", nc->data_owner);
        printf("  Offset: 0x%llx\n", nc->offset);
        printf("  Size: 0x%llx\n", nc->size);

        if (nc->offset + nc->size <= data.length) {
          const char *note_data = (const char *)data.bytes + nc->offset;
          uint64_t check_len = nc->size < 256 ? nc->size : 256;
          BOOL printable = YES;
          for (uint64_t k = 0; k < check_len; k++) {
            char c = note_data[k];
            if (c != 0 && (c < 32 || c > 126)) {
              if (c != '\n' && c != '\r' && c != '\t') {
                printable = NO;
                break;
              }
            }
          }

          if (printable && nc->size > 0) {
            char *buf = malloc(nc->size + 1);
            if (buf) {
              memcpy(buf, note_data, nc->size);
              buf[nc->size] = '\0';
              printf("  Content:\n%s\n", buf);
              free(buf);
            }
          } else {
            printf("  (Binary Content or too large to verify text)\n");
          }
        }
      }
    } else if (lc->cmd == LC_ANE_MAPPED_REGION) {
      const uint32_t *raw = (const uint32_t *)lc;
      uint32_t count = lc->cmdsize / 4;
      printf("  (LC_ANE_MAPPED_REGION)\n");
      if (count > 6) {
        const char *str = (const char *)(raw + 6);
        const char *end_ptr = (const char *)lc + lc->cmdsize;
        if (str < end_ptr) {
          printf("    Region: 0x%08x Name: %s\n", raw[4], str);
        }
      }
    } else if (lc->cmd == LC_IDENT) {
      if (lc->cmdsize > 8) {
        uint32_t len = lc->cmdsize - 8;
        char *buf = malloc(len + 1);
        if (buf) {
          memcpy(buf, (const char *)lc + 8, len);
          buf[len] = '\0';
          printf("  Ident: %s\n", buf);
          free(buf);
        }
      } else {
        printf("  (Empty Ident)\n");
      }
    }

    offset += lc->cmdsize;
  }
}

int main(int argc, char *const argv[]) {
  @autoreleasepool {
    int ch;
    BOOL dump_all = NO;
    BOOL dump_threads = NO;
    BOOL dump_hexdump = NO;

    while ((ch = getopt(argc, argv, "stx")) != -1) {
      switch (ch) {
      case 's':
        dump_all = YES;
        break;
      case 't':
        dump_threads = YES;
        break;
      case 'x':
        dump_hexdump = YES;
        break;
      case '?':
      default:
        printf("Usage: %s [-s] [-t] [-x] <path_to_hwx>\n", getprogname());
        return 1;
      }
    }
    argc -= optind;
    argv += optind;

    if (argc < 1) {
      printf("Usage: %s [-s] [-t] [-x] <path_to_hwx>\n", getprogname());
      return 1;
    }

    NSString *path = [NSString stringWithUTF8String:argv[0]];
    NSData *data = [NSData dataWithContentsOfFile:path];

    if (!data) {
      printf("Error reading file: %s\n", argv[0]);
      return 1;
    }

    print_macho_headers(data, dump_all, dump_threads, dump_hexdump);
  }
  return 0;
}
