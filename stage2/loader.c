#include "cpu/interrupts/idt.h"
#include "cpu/interrupts/irq.h"
#include "cpu/interrupts/isr.h"
#include "cpu/pic/pic.h"
#include "cpu/pit/pit.h"
#include "dev/keyboard.h"
#include "dev/serial.h"
#include "dev/vga.h"
#include "mem.h"
#include "utils.h"
#include <stdbool.h>
#include <stdint.h>

#define STACK_SIZE 4096

extern void enable_fpu();

typedef struct task {
  uint32_t *stack;
  int id;
  struct task *next;
  registers_t *state;
} task_t;

task_t *current = NULL;

void schedule() {
  if (current == NULL)
    return;
  current = current->next;
  serial_print("switching to: ");
  serial_print(int_to_str(current->id));
  serial_print("\n");
}

void pit_handler(registers_t *r) {
  memcpy(current->state, r, sizeof(registers_t));
  schedule();
  memcpy(r, current->state, sizeof(registers_t));
}

task_t *create_task(void (*entry)(), int id) {
  task_t *t = (task_t *)kmalloc(sizeof(task_t));

  uint32_t *stack = (uint32_t *)kmalloc(STACK_SIZE);
  memset(stack, 0, STACK_SIZE);

  registers_t *state =
      (registers_t *)((uint8_t *)stack);
  memset(state, 0, sizeof(registers_t));

  state->eip = (uint32_t)entry;
  state->cs = 0x08;
  state->eflags = 0x202;
  state->esp = (uint32_t)(stack);
  state->ss = 0x10;

  t->id = id;
  t->stack = stack;
  t->state = state;
  t->next = NULL;

  return t;
}

void task1() {
  asm("sti");
  while (1) {
    serial_print("task 1\n");
  }
}

void task2() {
  asm("sti");
  while (1) {
    serial_print("task 2\n");
  }
}

void task3() {
  asm("sti");
  while (1) {
    serial_print("task 3\n");
  }
}

void loader_start() {
  for (int i = 0; i < IRQs; i++) {
    pic_set_mask(i);
  }

  pic_remap();
  idt_init();
  install_exception_isrs();
  pit_init();
  install_irq(0, pit_handler);
  pic_clear_mask(0);
  enable_fpu();
  install_keyboard();

  memset(VIDEO_MEMORY, 0, 320 * 200);

  e820_entry_t *mem_map = (e820_entry_t *)0x9000;
  uint16_t entry_count = (*(uint16_t *)0x8E00);

  init_alloc(entry_count, mem_map);

  task_t *t1 = create_task(task1, 1);
  task_t *t2 = create_task(task2, 2);
  task_t *t3 = create_task(task3, 3);

  t1->next = t2;
  t2->next = t3;
  t3->next = t1;

  current = t1;

  asm("sti");

  while (1)
    ;
}
