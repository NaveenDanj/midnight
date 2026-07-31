// input.c

#include "input.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *midnight_input_read_line(void)
{
    size_t capacity = 128;
    size_t length = 0;

    char *buffer = malloc(capacity);

    if (!buffer)
        return NULL;

    int c;

    while ((c = getchar()) != '\n' && c != EOF)
    {
        if (length + 1 >= capacity)
        {
            capacity *= 2;

            char *tmp = realloc(buffer, capacity);

            if (!tmp)
            {
                free(buffer);
                return NULL;
            }

            buffer = tmp;
        }

        buffer[length++] = (char)c;
    }

    buffer[length] = '\0';

    return buffer;
}

int midnight_input_read_int(void)
{
    char *line = midnight_input_read_line();

    if (!line)
        return 0;

    int value = atoi(line);

    free(line);

    return value;
}

double midnight_input_read_float(void)
{
    char *line = midnight_input_read_line();

    if (!line)
        return 0.0;

    double value = atof(line);

    free(line);

    return value;
}

bool midnight_input_read_bool(void)
{
    char *line = midnight_input_read_line();

    if (!line)
        return false;

    bool value =
        strcmp(line, "true") == 0 ||
        strcmp(line, "1") == 0;

    free(line);

    return value;
}