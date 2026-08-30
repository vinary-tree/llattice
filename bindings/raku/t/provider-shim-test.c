#include <stdint.h>
#include <string.h>

#include "../cbits/provider.c"

static size_t drop_count;
static size_t binary_count;
static size_t many_count;

static void test_drop(void *context) {
    (void)context;
    ++drop_count;
}

static VtStatus test_binary(void *context, void *other_context,
                            const VtResource *other, VtResource *out_value) {
    (void)context;
    (void)other_context;
    (void)other;
    (void)out_value;
    ++binary_count;
    return VT_STATUS_PROVIDER_ERROR;
}

static VtStatus test_equal(void *context, void *other_context,
                           const VtResource *other, uint8_t *out_equal) {
    (void)context;
    (void)other_context;
    (void)other;
    *out_equal = 1;
    return VT_STATUS_OK;
}

static VtStatus test_bytes(void *context, uint8_t *out_bytes, size_t capacity,
                           size_t *out_written, size_t *out_required) {
    (void)context;
    (void)out_bytes;
    (void)capacity;
    *out_written = 0;
    *out_required = 0;
    return VT_STATUS_OK;
}

static VtStatus test_many(void *context, const VtResource *others,
                          size_t count, VtResource *out_value) {
    (void)context;
    (void)others;
    (void)count;
    (void)out_value;
    ++many_count;
    return VT_STATUS_PROVIDER_ERROR;
}

int main(void) {
    VtInterfaceId domain = {{'l', 'l', '.', 't', 'e', 's', 't', '.', 'v', 'a',
                             'l', '.', '0', '0', '0', '1'}};
    VtResource resource = {0};
    int host_context = 42;
    if (llattice_raku_provider_configure(
            test_drop, test_binary, test_binary, test_equal, test_bytes,
            test_bytes, test_many, test_many) != VT_STATUS_OK) {
        return 1;
    }
    if (llattice_raku_provider_create(
            &domain, VT_LATTICE_FLAG_THREAD_BOUND, &host_context,
            &resource) != VT_STATUS_OK) {
        return 2;
    }

    const void *raw_lattice = NULL;
    if (resource.vtable->query_interface(
            resource.context, &VT_LATTICE_INTERFACE_ID,
            VT_LATTICE_INTERFACE_VERSION, &raw_lattice) != VT_STATUS_OK) {
        return 3;
    }
    const VtLatticeVTable *lattice = raw_lattice;
    if (lattice == NULL || lattice->domain_id.bytes[15] != '1') {
        return 4;
    }

    VtResource output = {0};
    if (lattice->join(resource.context, NULL, &output) !=
            VT_STATUS_NULL_POINTER ||
        binary_count != 0) {
        return 5;
    }
    if (lattice->join(resource.context, &resource, &output) !=
            VT_STATUS_PROVIDER_ERROR ||
        binary_count != 1) {
        return 6;
    }
    if (lattice->join_many(resource.context, NULL, 1, &output) !=
            VT_STATUS_NULL_POINTER ||
        many_count != 0) {
        return 7;
    }
    if (lattice->join_many(resource.context, NULL, 0, &output) !=
            VT_STATUS_PROVIDER_ERROR ||
        many_count != 1) {
        return 8;
    }

    resource.vtable->retain(resource.context);
    resource.vtable->release(resource.context);
    if (drop_count != 0) {
        return 9;
    }
    resource.vtable->release(resource.context);
    return drop_count == 1 ? 0 : 10;
}
