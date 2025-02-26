/*
 * Virtio GPU Device
 *
 * Copyright Red Hat, Inc. 2013-2014
 *
 * Authors:
 *     Dave Airlie <airlied@redhat.com>
 *     Gerd Hoffmann <kraxel@redhat.com>
 *
 * This header is BSD licensed so anyone can use the definitions
 * to implement compatible drivers/servers:
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of IBM nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL IBM OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef __VIRTIO_GPU_H__
#define __VIRTIO_GPU_H__

#include <stdint.h>

/*
 * VIRTIO_GPU_CMD_CTX_*
 * VIRTIO_GPU_CMD_*_3D
 */
#define VIRTIO_GPU_F_VIRGL               0

/*
 * VIRTIO_GPU_CMD_GET_EDID
 */
#define VIRTIO_GPU_F_EDID                1
/*
 * VIRTIO_GPU_CMD_RESOURCE_ASSIGN_UUID
 */
#define VIRTIO_GPU_F_RESOURCE_UUID       2

/*
 * VIRTIO_GPU_CMD_RESOURCE_CREATE_BLOB
 */
#define VIRTIO_GPU_F_RESOURCE_BLOB       3
/*
 * VIRTIO_GPU_CMD_CREATE_CONTEXT with
 * context_init and multiple timelines
 */
#define VIRTIO_GPU_F_CONTEXT_INIT        4

typedef enum {
	VIRTIO_GPU_UNDEFINED = 0,

	/* 2d commands */
	VIRTIO_GPU_CMD_GET_DISPLAY_INFO = 0x0100,
	VIRTIO_GPU_CMD_RESOURCE_CREATE_2D,
	VIRTIO_GPU_CMD_RESOURCE_UNREF,
	VIRTIO_GPU_CMD_SET_SCANOUT,
	VIRTIO_GPU_CMD_RESOURCE_FLUSH,
	VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D,
	VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING,
	VIRTIO_GPU_CMD_RESOURCE_DETACH_BACKING,
	VIRTIO_GPU_CMD_GET_CAPSET_INFO,
	VIRTIO_GPU_CMD_GET_CAPSET,
	VIRTIO_GPU_CMD_GET_EDID,
	VIRTIO_GPU_CMD_RESOURCE_ASSIGN_UUID,
	VIRTIO_GPU_CMD_RESOURCE_CREATE_BLOB,
	VIRTIO_GPU_CMD_SET_SCANOUT_BLOB,

	/* 3d commands */
	VIRTIO_GPU_CMD_CTX_CREATE = 0x0200,
	VIRTIO_GPU_CMD_CTX_DESTROY,
	VIRTIO_GPU_CMD_CTX_ATTACH_RESOURCE,
	VIRTIO_GPU_CMD_CTX_DETACH_RESOURCE,
	VIRTIO_GPU_CMD_RESOURCE_CREATE_3D,
	VIRTIO_GPU_CMD_TRANSFER_TO_HOST_3D,
	VIRTIO_GPU_CMD_TRANSFER_FROM_HOST_3D,
	VIRTIO_GPU_CMD_SUBMIT_3D,
	VIRTIO_GPU_CMD_RESOURCE_MAP_BLOB,
	VIRTIO_GPU_CMD_RESOURCE_UNMAP_BLOB,

	/* cursor commands */
	VIRTIO_GPU_CMD_UPDATE_CURSOR = 0x0300,
	VIRTIO_GPU_CMD_MOVE_CURSOR,

	/* success responses */
	VIRTIO_GPU_RESP_OK_NODATA = 0x1100,
	VIRTIO_GPU_RESP_OK_DISPLAY_INFO,
	VIRTIO_GPU_RESP_OK_CAPSET_INFO,
	VIRTIO_GPU_RESP_OK_CAPSET,
	VIRTIO_GPU_RESP_OK_EDID,
	VIRTIO_GPU_RESP_OK_RESOURCE_UUID,
	VIRTIO_GPU_RESP_OK_MAP_INFO,

	/* error responses */
	VIRTIO_GPU_RESP_ERR_UNSPEC = 0x1200,
	VIRTIO_GPU_RESP_ERR_OUT_OF_MEMORY,
	VIRTIO_GPU_RESP_ERR_INVALID_SCANOUT_ID,
	VIRTIO_GPU_RESP_ERR_INVALID_RESOURCE_ID,
	VIRTIO_GPU_RESP_ERR_INVALID_CONTEXT_ID,
	VIRTIO_GPU_RESP_ERR_INVALID_PARAMETER,
} virtio_gpu_ctrl_type_t;

#define VIRTIO_GPU_FLAG_FENCE         (1 << 0)
/*
 * If the following flag is set, then ring_idx contains the index
 * of the command ring that needs to used when creating the fence
 */
#define VIRTIO_GPU_FLAG_INFO_RING_IDX (1 << 1)

typedef struct {
	uint32_t type;
	uint32_t flags;
	uint64_t fence_id;
	uint32_t ctx_id;
	uint8_t ring_idx;
	uint8_t padding[3];
} virtio_gpu_ctrl_hdr_t;

/* data passed in the cursor vq */

typedef struct {
	uint32_t scanout_id;
	uint32_t x;
	uint32_t y;
	uint32_t padding;
} virtio_gpu_cursor_pos_t;

/* VIRTIO_GPU_CMD_UPDATE_CURSOR, VIRTIO_GPU_CMD_MOVE_CURSOR */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	virtio_gpu_cursor_pos_t pos;  /* update & move */
	uint32_t resource_id;         /* update only */
	uint32_t hot_x;               /* update only */
	uint32_t hot_y;               /* update only */
	uint32_t padding;
} virtio_gpu_update_cursor_t;

/* data passed in the control vq, 2d related */

typedef struct {
	uint32_t x;
	uint32_t y;
	uint32_t width;
	uint32_t height;
} virtio_gpu_rect_t;

/* VIRTIO_GPU_CMD_RESOURCE_UNREF */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	uint32_t resource_id;
	uint32_t padding;
} virtio_gpu_resource_unref_t;

/* VIRTIO_GPU_CMD_RESOURCE_CREATE_2D: create a 2d resource with a format */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	uint32_t resource_id;
	uint32_t format;
	uint32_t width;
	uint32_t height;
} virtio_gpu_resource_create_2d_t;

/* VIRTIO_GPU_CMD_SET_SCANOUT */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	virtio_gpu_rect_t r;
	uint32_t scanout_id;
	uint32_t resource_id;
} virtio_gpu_set_scanout_t;

/* VIRTIO_GPU_CMD_RESOURCE_FLUSH */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	virtio_gpu_rect_t r;
	uint32_t resource_id;
	uint32_t padding;
} virtio_gpu_resource_flush_t;

/* VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D: simple transfer to_host */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	virtio_gpu_rect_t r;
	uint64_t offset;
	uint32_t resource_id;
	uint32_t padding;
} virtio_gpu_transfer_to_host_2d_t;

typedef struct {
	uint64_t addr;
	uint32_t length;
	uint32_t padding;
} virtio_gpu_mem_entry_t;

/* VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	uint32_t resource_id;
	uint32_t nr_entries;
} virtio_gpu_resource_attach_backing_t;

/* VIRTIO_GPU_CMD_RESOURCE_DETACH_BACKING */
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	uint32_t resource_id;
	uint32_t padding;
} virtio_gpu_resource_detach_backing_t;

/* VIRTIO_GPU_RESP_OK_DISPLAY_INFO */
#define VIRTIO_GPU_MAX_SCANOUTS 16
typedef struct {
	virtio_gpu_ctrl_hdr_t hdr;
	struct virtio_gpu_display_one {
		virtio_gpu_rect_t r;
		uint32_t enabled;
		uint32_t flags;
	} pmodes[VIRTIO_GPU_MAX_SCANOUTS];
} virtio_gpu_resp_display_info_t;

#define VIRTIO_GPU_EVENT_DISPLAY (1 << 0)

typedef struct {
	uint32_t events_read;
	uint32_t events_clear;
	uint32_t num_scanouts;
	uint32_t num_capsets;
} virtio_gpu_config_t;

/* simple formats for fbcon/X use */
typedef enum {
	VIRTIO_GPU_FORMAT_B8G8R8A8_UNORM  = 1,
	VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM  = 2,
	VIRTIO_GPU_FORMAT_A8R8G8B8_UNORM  = 3,
	VIRTIO_GPU_FORMAT_X8R8G8B8_UNORM  = 4,

	VIRTIO_GPU_FORMAT_R8G8B8A8_UNORM  = 67,
	VIRTIO_GPU_FORMAT_X8B8G8R8_UNORM  = 68,

	VIRTIO_GPU_FORMAT_A8B8G8R8_UNORM  = 121,
	VIRTIO_GPU_FORMAT_R8G8B8X8_UNORM  = 134,
} virtio_gpu_formats_t;

#endif /* !__VIRTIO_GPU_H__ */
