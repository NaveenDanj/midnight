#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/stat.h>
#include <errno.h>

#ifdef _WIN32
#include <direct.h>
#define MIDNIGHT_MKDIR(path) _mkdir(path)
#else
#include <unistd.h>
#define MIDNIGHT_MKDIR(path) mkdir(path, 0755)
#endif

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

    char *buffer = malloc((size_t)size + 1);
    if (buffer == NULL)
    {
        fclose(file);
        return NULL;
    }

    size_t bytes = fread(buffer, 1, (size_t)size, file);
    fclose(file);

    if (bytes != (size_t)size)
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

    size_t len = strlen(content);
    bool ok = fwrite(content, 1, len, file) == len;

    fclose(file);
    return ok;
}

bool midnight_file_append(const char *path, const char *content)
{
    if (path == NULL || content == NULL)
    {
        return false;
    }

    FILE *file = fopen(path, "ab");
    if (file == NULL)
    {
        return false;
    }

    size_t len = strlen(content);
    bool ok = fwrite(content, 1, len, file) == len;

    fclose(file);
    return ok;
}

bool midnight_file_exists(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    FILE *file = fopen(path, "rb");

    if (file == NULL)
    {
        return false;
    }

    fclose(file);
    return true;
}

bool midnight_file_delete(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    return remove(path) == 0;
}

bool midnight_file_copy(const char *source, const char *destination)
{
    if (source == NULL || destination == NULL)
    {
        return false;
    }

    FILE *src = fopen(source, "rb");
    if (src == NULL)
    {
        return false;
    }

    FILE *dst = fopen(destination, "wb");
    if (dst == NULL)
    {
        fclose(src);
        return false;
    }

    char buffer[8192];
    size_t bytes;

    while ((bytes = fread(buffer, 1, sizeof(buffer), src)) > 0)
    {
        if (fwrite(buffer, 1, bytes, dst) != bytes)
        {
            fclose(src);
            fclose(dst);
            return false;
        }
    }

    fclose(src);
    fclose(dst);

    return true;
}

bool midnight_file_move(const char *source, const char *destination)
{
    if (source == NULL || destination == NULL)
    {
        return false;
    }

    return rename(source, destination) == 0;
}

bool midnight_file_create(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    FILE *file = fopen(path, "wb");

    if (file == NULL)
    {
        return false;
    }

    fclose(file);
    return true;
}

bool midnight_file_create_directory(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    return MIDNIGHT_MKDIR(path) == 0;
}

bool midnight_file_remove_directory(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

#ifdef _WIN32
    return _rmdir(path) == 0;
#else
    return rmdir(path) == 0;
#endif
}

bool midnight_file_is_directory(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    struct stat st;

    if (stat(path, &st) != 0)
    {
        return false;
    }

    return S_ISDIR(st.st_mode);
}

bool midnight_file_is_file(const char *path)
{
    if (path == NULL)
    {
        return false;
    }

    struct stat st;

    if (stat(path, &st) != 0)
    {
        return false;
    }

    return S_ISREG(st.st_mode);
}

long midnight_file_size(const char *path)
{
    if (path == NULL)
    {
        return -1;
    }

    struct stat st;

    if (stat(path, &st) != 0)
    {
        return -1;
    }

    return (long)st.st_size;
}

char *midnight_file_current_directory(void)
{
    char *buffer = malloc(4096);

    if (buffer == NULL)
    {
        return NULL;
    }

#ifdef _WIN32
    if (_getcwd(buffer, 4096) == NULL)
#else
    if (getcwd(buffer, 4096) == NULL)
#endif
    {
        free(buffer);
        return NULL;
    }

    return buffer;
}

char *midnight_file_absolute(const char *path)
{
    if (path == NULL)
    {
        return NULL;
    }

    char *buffer = malloc(4096);

    if (buffer == NULL)
    {
        return NULL;
    }

#ifdef _WIN32
    if (_fullpath(buffer, path, 4096) == NULL)
#else
    if (realpath(path, buffer) == NULL)
#endif
    {
        free(buffer);
        return NULL;
    }

    return buffer;
}

void midnight_file_free(char *buffer)
{
    free(buffer);
}