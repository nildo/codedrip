#ifndef DISSEMINATION_H
#define DISSEMINATION_H

enum {
  AM_DISSEMINATION_MESSAGE = 0x60,
  AM_SERIAL_MESSAGE = 0x70,
  TIMER_PERIOD_MILLI = 250,
  MAX_COMBINATIONS = 2,
  MAX_STORE = 10,
  MAX_CSTORE = 5,
  SUPR = 50,
  COMB = 30,
  ORIGIN_NODE = 116,
  NUM_MSGS = 3,
};

typedef nx_struct content {
  nx_uint8_t ids[MAX_COMBINATIONS];
  nx_uint16_t content;
} content_t;

typedef nx_struct dissemination_message {
  nx_uint16_t nodeid;
  content_t content;
} dissemination_message_t;

typedef nx_struct serial_message {
  nx_uint16_t nodeid;
  nx_uint16_t sent;
  nx_uint16_t counter;
} serial_message_t;

#endif
