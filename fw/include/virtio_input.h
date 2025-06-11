#ifndef __VIRTIO_INPUT_H__
#define __VIRTIO_INPUT_H__

#include <stdint.h>

typedef struct {
  uint16_t type;
  uint16_t code;
  uint16_t value;
} virtio_input_event_t;

#endif /* !__VIRTIO_INPUT_H__ */
