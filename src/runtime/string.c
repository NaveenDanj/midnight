#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

char *midnight_string_concat(const char *str1, const char *str2)
{
    size_t len1 = strlen(str1);
    size_t len2 = strlen(str2);

    char *result = (char *)malloc(len1 + len2 + 1);
    if (result == NULL)
    {
        return NULL;
    }
    strcpy(result, str1);
    strcat(result, str2);
    return result;
}

int midnight_string_compare(const char *str1, const char *str2)
{
    return strcmp(str1, str2);
}

void midnight_print_string(const char *str)
{
    printf("%s\n", str);
}