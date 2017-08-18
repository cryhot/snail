#define _FILE_OFFSET_BITS 64
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char* argv[])
{
    /* Arguments: fd [offset]
     * where
     * fd: file descriptor to seek
     * offset: number of bytes from start of file
     */
    int fd;
    long long scan_offset = 0;
    off_t offset = 0;
    int errsv; int rv;
    if (argc <= 1) {
        fprintf(stderr, "usage: rewindfd fd [offset]\n");
        exit(1);
    }
    if (argc > 1) {
        if (sscanf(argv[1], "%d", &fd) == EOF) {
            errsv = errno;
            fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
            exit(1);
        }
    }
    if (argc > 2) {
        rv = sscanf(argv[2], "%lld", &scan_offset);
        if (rv == EOF) {
            errsv = errno;
            fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
            exit(1);
        }
        offset = (off_t) scan_offset;
    }

    if (lseek(fd, offset, SEEK_SET) == (off_t) -1) {
        errsv = errno;
        fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
        exit(2);
    }
    if (ftruncate(fd, offset) == (off_t) -1) {
        errsv = errno;
        fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
        exit(2);
    }

    return 0;
}
