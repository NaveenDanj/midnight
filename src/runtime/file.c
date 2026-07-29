#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

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

bool midnight_file_write(const char *path, const char *content)
{
    if (path == NULL || content == NULL)
    {
        return false;
    }

    FILE *file = fopen(path, "wb");
    if (file == NULL)
    {
        return false;
    }

    size_t content_length = strlen(content);
    size_t bytes_written = fwrite(content, 1, content_length, file);
    fclose(file);

    return bytes_written == content_length;
}

bool midnight_file_exists(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    FILE *file = fopen(path, "rb");
    if (file != NULL)
    {
        fclose(file);
        return true;
    }

    return false;
}

void midnight_file_free(char *buffer)
{
    free(buffer);
}

void midnight_test()
{
    printf("Hello from the Midnight runtime!\n");
}