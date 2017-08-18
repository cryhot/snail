
all:
	$(MAKE) -C util/

check: $(wildcard *.sh) $(wildcard util/*.sh)
	shellcheck $^

clean:
	$(MAKE) -C util/ clean

mrproper: clean
	$(MAKE) -C util/ mrproper


.PHONY: all check clean mrproper
