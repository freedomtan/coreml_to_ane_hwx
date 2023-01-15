#include <unistd.h>

#if __cplusplus
extern "C" {
#endif

extern void* espresso_create_context(uint64_t, uint64_t);
extern void* espresso_create_context_auto();
extern uint64_t espresso_get_default_storage_type(void* context);
extern void* espresso_create_plan(void* context, uint64_t storage_type);
extern int espresso_plan_add_network(void* plan, char* path, uint64_t p3,
                                     uint64_t p4[2]);

extern uint64_t espresso_get_input_blob_name(uint64_t, uint64_t, uint64_t);
extern uint64_t espresso_get_output_blob_name(uint64_t, uint64_t, uint64_t);
extern int64_t espresso_network_query_blob_dimensions(uint64_t, uint64_t, char*,
                                                      uint64_t);
#if __cplusplus
}
#endif
