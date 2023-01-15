#include "espresso_dims.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char* argv[]) {
  printf("network file: %s\n", argv[1]);
  void* ctx = espresso_create_context_auto();
  void* plan = espresso_create_plan(ctx, 0LL);

  uint64_t vals[2];
  uint64_t storage_type = espresso_get_default_storage_type(ctx);
  int ret = espresso_plan_add_network(plan, argv[1], storage_type, vals);
  if (ret) printf("failed to add %s to espresso plan\n", argv[1]);

  uint64_t ret64;
  uint64_t d[4];

  int count = 0;
  while (true) {
    ret64 = espresso_get_input_blob_name(vals[0], vals[1], count);
    if (ret64 != 0) {
      char* network_name = (char*)ret64;
      ret64 = espresso_network_query_blob_dimensions(
          vals[0], vals[1], network_name, (uint64_t)(d));
      if (ret64 == 0) {
        printf("  input (%d) = %s (%llu, %llu, %llu, %llu)\n", count,
               network_name, d[0], d[1], d[2], d[3]);
        count++;
      }
    } else {
      break;
    }
  }

  count = 0;
  while (true) {
    ret64 = espresso_get_output_blob_name(vals[0], vals[1], count);
    if (ret64 != 0) {
      char* network_name = (char*)ret64;
      ret64 = espresso_network_query_blob_dimensions(
          vals[0], vals[1], network_name, (uint64_t)(d));
      if (ret64 == 0) {
        printf("  output (%d) = %s (%llu, %llu, %llu, %llu)\n", count,
               network_name, d[0], d[1], d[2], d[3]);
      }
      count++;
    } else {
      break;
    }
  }
}
