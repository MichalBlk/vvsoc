`default_nettype none

`include "evdev.svh"
`include "ps2.svh"

module kbd_evdev_converter
  import evdev_pkg::*;
  import ps2_pkg::*;
(
  input  logic [15:0] scancode,
  output logic [7:0]  evcode
);
  always_comb begin
    evcode = 'bx;

    unique0 case (scancode)
      SCANCODE_ESC:        evcode = KEY_ESC;
      SCANCODE_1:          evcode = KEY_1;
      SCANCODE_2:          evcode = KEY_2;
      SCANCODE_3:          evcode = KEY_3;
      SCANCODE_4:          evcode = KEY_4;
      SCANCODE_5:          evcode = KEY_5;
      SCANCODE_6:          evcode = KEY_6;
      SCANCODE_7:          evcode = KEY_7;
      SCANCODE_8:          evcode = KEY_8;
      SCANCODE_9:          evcode = KEY_9;
      SCANCODE_0:          evcode = KEY_0;
      SCANCODE_MINUS:      evcode = KEY_MINUS;
      SCANCODE_EQUAL:      evcode = KEY_EQUAL;
      SCANCODE_BACKSPACE:  evcode = KEY_BACKSPACE;
      SCANCODE_TAB:        evcode = KEY_TAB;
      SCANCODE_Q:          evcode = KEY_Q;
      SCANCODE_W:          evcode = KEY_W;
      SCANCODE_E:          evcode = KEY_E;
      SCANCODE_R:          evcode = KEY_R;
      SCANCODE_T:          evcode = KEY_T;
      SCANCODE_Y:          evcode = KEY_Y;
      SCANCODE_U:          evcode = KEY_U;
      SCANCODE_I:          evcode = KEY_I;
      SCANCODE_O:          evcode = KEY_O;
      SCANCODE_P:          evcode = KEY_P;
      SCANCODE_LEFTBRACE:  evcode = KEY_LEFTBRACE;
      SCANCODE_RIGHTBRACE: evcode = KEY_RIGHTBRACE;
      SCANCODE_ENTER:      evcode = KEY_ENTER;
      SCANCODE_LEFTCTRL:   evcode = KEY_LEFTCTRL;
      SCANCODE_A:          evcode = KEY_A;
      SCANCODE_S:          evcode = KEY_S;
      SCANCODE_D:          evcode = KEY_D;
      SCANCODE_F:          evcode = KEY_F;
      SCANCODE_G:          evcode = KEY_G;
      SCANCODE_H:          evcode = KEY_H;
      SCANCODE_J:          evcode = KEY_J;
      SCANCODE_K:          evcode = KEY_K;
      SCANCODE_L:          evcode = KEY_L;
      SCANCODE_SEMICOLON:  evcode = KEY_SEMICOLON;
      SCANCODE_APOSTROPHE: evcode = KEY_APOSTROPHE;
      SCANCODE_GRAVE:      evcode = KEY_GRAVE;
      SCANCODE_LEFTSHIFT:  evcode = KEY_LEFTSHIFT;
      SCANCODE_BACKSLASH:  evcode = KEY_BACKSLASH;
      SCANCODE_Z:          evcode = KEY_Z;
      SCANCODE_X:          evcode = KEY_X;
      SCANCODE_C:          evcode = KEY_C;
      SCANCODE_V:          evcode = KEY_V;
      SCANCODE_B:          evcode = KEY_B;
      SCANCODE_N:          evcode = KEY_N;
      SCANCODE_M:          evcode = KEY_M;
      SCANCODE_COMMA:      evcode = KEY_COMMA;
      SCANCODE_DOT:        evcode = KEY_DOT;
      SCANCODE_SLASH:      evcode = KEY_SLASH;
      SCANCODE_RIGHTSHIFT: evcode = KEY_RIGHTSHIFT;
      SCANCODE_KPASTERISK: evcode = KEY_KPASTERISK;
      SCANCODE_LEFTALT:    evcode = KEY_LEFTALT;
      SCANCODE_SPACE:      evcode = KEY_SPACE;
      SCANCODE_CAPSLOCK:   evcode = KEY_CAPSLOCK;
      SCANCODE_F1:         evcode = KEY_F1;
      SCANCODE_F2:         evcode = KEY_F2;
      SCANCODE_F3:         evcode = KEY_F3;
      SCANCODE_F4:         evcode = KEY_F4;
      SCANCODE_F5:         evcode = KEY_F5;
      SCANCODE_F6:         evcode = KEY_F6;
      SCANCODE_F7:         evcode = KEY_F7;
      SCANCODE_F8:         evcode = KEY_F8;
      SCANCODE_F9:         evcode = KEY_F9;
      SCANCODE_F10:        evcode = KEY_F10;
      SCANCODE_NUMLOCK:    evcode = KEY_NUMLOCK;
      SCANCODE_SCROLLLOCK: evcode = KEY_SCROLLLOCK;
      SCANCODE_KP7:        evcode = KEY_KP7;
      SCANCODE_KP8:        evcode = KEY_KP8;
      SCANCODE_KP9:        evcode = KEY_KP9;
      SCANCODE_KPMINUS:    evcode = KEY_KPMINUS;
      SCANCODE_KP4:        evcode = KEY_KP4;
      SCANCODE_KP5:        evcode = KEY_KP5;
      SCANCODE_KP6:        evcode = KEY_KP6;
      SCANCODE_KPPLUS:     evcode = KEY_KPPLUS;
      SCANCODE_KP1:        evcode = KEY_KP1;
      SCANCODE_KP2:        evcode = KEY_KP2;
      SCANCODE_KP3:        evcode = KEY_KP3;
      SCANCODE_KP0:        evcode = KEY_KP0;
      SCANCODE_KPDOT:      evcode = KEY_KPDOT;
      SCANCODE_F11:        evcode = KEY_F11;
      SCANCODE_F12:        evcode = KEY_F12;
      SCANCODE_KPENTER:    evcode = KEY_KPENTER;
      SCANCODE_RIGHTCTRL:  evcode = KEY_RIGHTCTRL;
      SCANCODE_KPSLASH:    evcode = KEY_KPSLASH;
      SCANCODE_RIGHTALT:   evcode = KEY_RIGHTALT;
      SCANCODE_HOME:       evcode = KEY_HOME;
      SCANCODE_UP:         evcode = KEY_UP;
      SCANCODE_PAGEUP:     evcode = KEY_PAGEUP;
      SCANCODE_LEFT:       evcode = KEY_LEFT;
      SCANCODE_RIGHT:      evcode = KEY_RIGHT;
      SCANCODE_END:        evcode = KEY_END;
      SCANCODE_DOWN:       evcode = KEY_DOWN;
      SCANCODE_PAGEDOWN:   evcode = KEY_PAGEDOWN;
      SCANCODE_INSERT:     evcode = KEY_INSERT;
      SCANCODE_DELETE:     evcode = KEY_DELETE;
      SCANCODE_LEFTMETA:   evcode = KEY_LEFTMETA;
      SCANCODE_RIGHTMETA:  evcode = KEY_RIGHTMETA;
      SCANCODE_MENU:       evcode = KEY_MENU;
    endcase
  end
endmodule
