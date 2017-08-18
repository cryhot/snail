CC = gcc
CFLAGS = -Wall

TARGETS = seekfd rewindfd

all: $(TARGETS)

check: $(wildcard *.sh)
	shellcheck $^

$(TARGETS): %: %.c
	$(CC) $(CFLAGS) $^ -o $@

clean:

mrproper: clean
	rm -f $(TARGETS)

.PHONY: all check clean mrproper
