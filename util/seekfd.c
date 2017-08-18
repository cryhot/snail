#define _FILE_OFFSET_BITS 64
#include <string.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

// CREDITS: https://stackoverflow.com/a/3848405
int main(int argc, char* argv[])
{
    /* Arguments: fd [offset [whence]]
     * where
     * fd: file descriptor to seek
     * offset: number of bytes from position specified in whence
     * whence: one of
     *  SEEK_SET (==0): from start of file
     *  SEEK_CUR (==1): from current position
     *  SEEK_END (==2): from end of file
     */
    int fd;
    long long scan_offset = 0;
    off_t offset = 0;
    int whence = SEEK_SET;
    int errsv; int rv;
    if (argc == 1) {
        fprintf(stderr, "usage: seekfd fd [offset [whence]]\n");
        exit(1);
    }
    if (argc >= 2) {
        if (sscanf(argv[1], "%d", &fd) == EOF) {
            errsv = errno;
            fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
            exit(1);
        }
    }
    if (argc >= 3) {
        rv = sscanf(argv[2], "%lld", &scan_offset);
        if (rv == EOF) {
            errsv = errno;
            fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
            exit(1);
        }
        offset = (off_t) scan_offset;
    }
    if (argc >= 4) {
        if (sscanf(argv[3], "%d", &whence) == EOF) {
            errsv = errno;
            fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
            exit(1);
        }
    }

    if (lseek(fd, offset, whence) == (off_t) -1) {
        errsv = errno;
        fprintf(stderr, "%s: %s\n", argv[0], strerror(errsv));
        exit(2);
    }

    return 0;
}
