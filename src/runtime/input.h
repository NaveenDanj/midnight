// input.h

#ifndef MIDNIGHT_INPUT_H
#define MIDNIGHT_INPUT_H

#include <stdbool.h>

char *midnight_input_read_line(void);
int midnight_input_read_int(void);
double midnight_input_read_float(void);
bool midnight_input_read_bool(void);

#endif