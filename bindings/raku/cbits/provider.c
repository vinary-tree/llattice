#include "vinary_tree_interop.h"

#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#define LLATTICE_RAKU_API __declspec(dllexport)
#else
#define LLATTICE_RAKU_API
#endif

typedef void (*LlatticeRakuDrop)(void *host_context);
typedef VtStatus (*LlatticeRakuBinary)(void *host_context,
                                       void *other_host_context,
                                       const VtResource *other,
                                       VtResource *out_value);
typedef VtStatus (*LlatticeRakuEqual)(void *host_context,
                                      void *other_host_context,
                                      const VtResource *other,
                                      uint8_t *out_equal);
typedef VtStatus (*LlatticeRakuBytes)(void *host_context,
                                      uint8_t *out_bytes,
                                      size_t capacity,
                                      size_t *out_written,
                                      size_t *out_required);
typedef VtStatus (*LlatticeRakuMany)(void *host_context,
                                     const VtResource *others,
                                     size_t count,
                                     VtResource *out_value);

typedef struct LlatticeRakuCallbacks {
    LlatticeRakuDrop drop;
    LlatticeRakuBinary join;
    LlatticeRakuBinary meet;
    LlatticeRakuEqual equal;
    LlatticeRakuBytes stable_bytes;
    LlatticeRakuBytes diagnostic;
    LlatticeRakuMany join_many;
    LlatticeRakuMany meet_many;
} LlatticeRakuCallbacks;

static LlatticeRakuCallbacks CALLBACKS;
static atomic_bool CALLBACKS_CONFIGURED;
static atomic_flag CALLBACKS_LOCK = ATOMIC_FLAG_INIT;

typedef struct LlatticeRakuProvider {
    atomic_size_t references;
    void *host_context;
    LlatticeRakuDrop drop;
    LlatticeRakuBinary join;
    LlatticeRakuBinary meet;
    LlatticeRakuEqual equal;
    LlatticeRakuBytes stable_bytes;
    LlatticeRakuBytes diagnostic;
    LlatticeRakuMany join_many;
    LlatticeRakuMany meet_many;
    VtLatticeVTable lattice;
} LlatticeRakuProvider;

static const VtResourceVTable RESOURCE_VTABLE;

static void provider_retain(void *raw_context) {
    LlatticeRakuProvider *context = raw_context;
    (void)atomic_fetch_add_explicit(&context->references, 1,
                                    memory_order_relaxed);
}

static void provider_release(void *raw_context) {
    LlatticeRakuProvider *context = raw_context;
    if (atomic_fetch_sub_explicit(&context->references, 1,
                                  memory_order_acq_rel) == 1) {
        context->drop(context->host_context);
        free(context);
    }
}

static VtStatus provider_query(void *raw_context,
                               const VtInterfaceId *interface_id,
                               uint32_t minimum_version,
                               const void **out_vtable) {
    if (raw_context == NULL || interface_id == NULL || out_vtable == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    if (memcmp(interface_id, &VT_LATTICE_INTERFACE_ID,
               sizeof(*interface_id)) != 0 ||
        minimum_version > VT_LATTICE_INTERFACE_VERSION) {
        return VT_STATUS_UNSUPPORTED;
    }
    *out_vtable = &context->lattice;
    return VT_STATUS_OK;
}

static VtStatus provider_join(void *raw_context, const VtResource *other,
                              VtResource *out_value) {
    if (raw_context == NULL || other == NULL || out_value == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    void *other_host_context = NULL;
    if (other != NULL && other->vtable == &RESOURCE_VTABLE &&
        other->context != NULL) {
        LlatticeRakuProvider *other_context = other->context;
        other_host_context = other_context->host_context;
    }
    return context->join(context->host_context, other_host_context, other,
                         out_value);
}

static VtStatus provider_meet(void *raw_context, const VtResource *other,
                              VtResource *out_value) {
    if (raw_context == NULL || other == NULL || out_value == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    void *other_host_context = NULL;
    if (other != NULL && other->vtable == &RESOURCE_VTABLE &&
        other->context != NULL) {
        LlatticeRakuProvider *other_context = other->context;
        other_host_context = other_context->host_context;
    }
    return context->meet(context->host_context, other_host_context, other,
                         out_value);
}

static VtStatus provider_equal(void *raw_context, const VtResource *other,
                               uint8_t *out_equal) {
    if (raw_context == NULL || other == NULL || out_equal == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    void *other_host_context = NULL;
    if (other != NULL && other->vtable == &RESOURCE_VTABLE &&
        other->context != NULL) {
        LlatticeRakuProvider *other_context = other->context;
        other_host_context = other_context->host_context;
    }
    return context->equal(context->host_context, other_host_context, other,
                          out_equal);
}

static VtStatus provider_stable_bytes(void *raw_context, uint8_t *out_bytes,
                                      size_t capacity, size_t *out_written,
                                      size_t *out_required) {
    if (raw_context == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    return context->stable_bytes(context->host_context, out_bytes, capacity,
                                 out_written, out_required);
}

static VtStatus provider_diagnostic(void *raw_context, uint8_t *out_bytes,
                                    size_t capacity, size_t *out_written,
                                    size_t *out_required) {
    if (raw_context == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    return context->diagnostic(context->host_context, out_bytes, capacity,
                               out_written, out_required);
}

static VtStatus provider_join_many(void *raw_context,
                                   const VtResource *others, size_t count,
                                   VtResource *out_value) {
    if (raw_context == NULL || (count != 0 && others == NULL) ||
        out_value == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    return context->join_many(context->host_context, others, count, out_value);
}

static VtStatus provider_meet_many(void *raw_context,
                                   const VtResource *others, size_t count,
                                   VtResource *out_value) {
    if (raw_context == NULL || (count != 0 && others == NULL) ||
        out_value == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    LlatticeRakuProvider *context = raw_context;
    return context->meet_many(context->host_context, others, count, out_value);
}

static const VtResourceVTable RESOURCE_VTABLE = {
    sizeof(VtResourceVTable),
    VT_ABI_VERSION,
    0,
    provider_retain,
    provider_release,
    provider_query,
};

LLATTICE_RAKU_API VtStatus llattice_raku_provider_configure(
    LlatticeRakuDrop drop,
    LlatticeRakuBinary join,
    LlatticeRakuBinary meet,
    LlatticeRakuEqual equal,
    LlatticeRakuBytes stable_bytes,
    LlatticeRakuBytes diagnostic,
    LlatticeRakuMany join_many,
    LlatticeRakuMany meet_many) {
    if (drop == NULL || join == NULL || meet == NULL || equal == NULL ||
        stable_bytes == NULL || diagnostic == NULL || join_many == NULL ||
        meet_many == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    while (atomic_flag_test_and_set_explicit(&CALLBACKS_LOCK,
                                              memory_order_acquire)) {
    }
    VtStatus status = VT_STATUS_OK;
    if (atomic_load_explicit(&CALLBACKS_CONFIGURED, memory_order_relaxed)) {
        if (CALLBACKS.drop != drop || CALLBACKS.join != join ||
            CALLBACKS.meet != meet || CALLBACKS.equal != equal ||
            CALLBACKS.stable_bytes != stable_bytes ||
            CALLBACKS.diagnostic != diagnostic ||
            CALLBACKS.join_many != join_many ||
            CALLBACKS.meet_many != meet_many) {
            status = VT_STATUS_BATCH_IN_USE;
        }
    } else {
        CALLBACKS = (LlatticeRakuCallbacks){
            drop,       join,       meet,      equal,
            stable_bytes, diagnostic, join_many, meet_many,
        };
        atomic_store_explicit(&CALLBACKS_CONFIGURED, true,
                              memory_order_release);
    }
    atomic_flag_clear_explicit(&CALLBACKS_LOCK, memory_order_release);
    return status;
}

LLATTICE_RAKU_API VtStatus llattice_raku_provider_create(
    const VtInterfaceId *domain_id,
    uint64_t flags,
    void *host_context,
    VtResource *out_resource) {
    if (domain_id == NULL || host_context == NULL || out_resource == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    if (!atomic_load_explicit(&CALLBACKS_CONFIGURED, memory_order_acquire)) {
        return VT_STATUS_PROVIDER_ERROR;
    }
    LlatticeRakuProvider *context = calloc(1, sizeof(*context));
    if (context == NULL) {
        return VT_STATUS_IO_ERROR;
    }
    atomic_init(&context->references, 1);
    context->host_context = host_context;
    context->drop = CALLBACKS.drop;
    context->join = CALLBACKS.join;
    context->meet = CALLBACKS.meet;
    context->equal = CALLBACKS.equal;
    context->stable_bytes = CALLBACKS.stable_bytes;
    context->diagnostic = CALLBACKS.diagnostic;
    context->join_many = CALLBACKS.join_many;
    context->meet_many = CALLBACKS.meet_many;
    context->lattice = (VtLatticeVTable){
        sizeof(VtLatticeVTable),
        VT_LATTICE_INTERFACE_VERSION,
        0,
        flags,
        *domain_id,
        provider_join,
        provider_meet,
        provider_equal,
        provider_stable_bytes,
        provider_diagnostic,
        provider_join_many,
        provider_meet_many,
    };
    out_resource->context = context;
    out_resource->vtable = &RESOURCE_VTABLE;
    return VT_STATUS_OK;
}

LLATTICE_RAKU_API VtStatus
llattice_raku_provider_host_context(const VtResource *resource,
                                    void **out_host_context) {
    if (resource == NULL || out_host_context == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    if (resource->context == NULL || resource->vtable != &RESOURCE_VTABLE) {
        return VT_STATUS_UNSUPPORTED;
    }
    LlatticeRakuProvider *context = resource->context;
    *out_host_context = context->host_context;
    return VT_STATUS_OK;
}

LLATTICE_RAKU_API VtStatus
llattice_raku_provider_host_context_at(const VtResource *resources,
                                       size_t index,
                                       void **out_host_context) {
    if (resources == NULL) {
        return VT_STATUS_NULL_POINTER;
    }
    return llattice_raku_provider_host_context(&resources[index],
                                                out_host_context);
}
