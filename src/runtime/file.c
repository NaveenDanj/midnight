#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *midnight_file_read(const char *path)
{
    if (path == NULL)
    {
        return NULL;
    }

    FILE *file = fopen(path, "rb");
    if (file == NULL)
    {
        return NULL;
    }

    // Move to the end of the file
    if (fseek(file, 0, SEEK_END) != 0)
    {
        fclose(file);
        return NULL;
    }

    long size = ftell(file);
    if (size < 0)
    {
        fclose(file);
        return NULL;
    }

    rewind(file);

    char *buffer = (char *)malloc((size_t)size + 1);
    if (buffer == NULL)
    {
        fclose(file);
        return NULL;
    }

    size_t bytes_read = fread(buffer, 1, (size_t)size, file);
    fclose(file);

    if (bytes_read != (size_t)size)
    {
        free(buffer);
        return NULL;
    }

    buffer[size] = '\0';

    return buffer;
}

void midnight_file_free(char *buffer)
{
    free(buffer);
}

void midnight_test()
{
    printf("Hello from the Midnight runtime!\n");
}