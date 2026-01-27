#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <unistd.h>

#define HWX_MAGIC 0xbeefface
#define LC_ANE_MAPPED_REGION 0x40

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

void print_macho_headers(NSData *data, BOOL dump_all_symbols,
                         BOOL dump_threads) {
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

    while ((ch = getopt(argc, argv, "st")) != -1) {
      switch (ch) {
      case 's':
        dump_all = YES;
        break;
      case 't':
        dump_threads = YES;
        break;
      case '?':
      default:
        printf("Usage: %s [-s] [-t] <path_to_hwx>\n", getprogname());
        return 1;
      }
    }
    argc -= optind;
    argv += optind;

    if (argc < 1) {
      printf("Usage: %s [-s] [-t] <path_to_hwx>\n", getprogname());
      return 1;
    }

    NSString *path = [NSString stringWithUTF8String:argv[0]];
    NSData *data = [NSData dataWithContentsOfFile:path];

    if (!data) {
      printf("Error reading file: %s\n", argv[0]);
      return 1;
    }

    print_macho_headers(data, dump_all, dump_threads);
  }
  return 0;
}
