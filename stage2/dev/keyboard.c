#include "keyboard.h"
#include "dev/serial.h"
#include "utils.h"

#pragma GCC diagnostic ignored "-Wunused-parameter"
void keyboard_handler(registers_t *r) {
  uint8_t scancode = inb(0x60);
  serial_print("keyboard: ");
  serial_print(itoa(scancode));
  serial_print("\n");
}