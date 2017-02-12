# Snail
[![License](http://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

:snail: _Make your shell interactive_

## Installation
Just download the source :)  
The code of [`snail.sh`](snail.sh) must be executed directly in the current shell (use `.` or `source`) in order to access the functionalities.

If you want permanent changes, just add this line to your `.bashrc` (admitting you used the repertory `~/snail`) :
```sh
    . ~/snail/snail.sh
```
**:warning: If you share your computer with other users, don't forget to remove write perms from the sourced file.**

> Some fonctionalities need special [ptrace permissions](https://www.kernel.org/doc/Documentation/security/Yama.txt). If `/proc/sys/kernel/yama/ptrace_scope` contains something other than `0`, make sure that the file `/etc/sysctl.d/10-ptrace.conf` contains the line :
>
>     kernel.yama.ptrace_scope = 0

## Usage

### Description

- `mill [-p PERIOD] COMMAND`  
  run a command in loop  

- `scale VAR [MIN] [MAX]`  
  spawn a scale the user can move to set a numeric value to a variable  
  runs in the background

- `++ VAR [MAX] [MIN]`  
  increment a variable by one  
  if one bound is specified, the other one is set to zero by default, and the variable will iterate within the boundaries  
  an unset variable will be set to the least bound if the last one is defined  

- `-- VAR [MAX] [MIN]`  
  decrement a variable by one, in a way similar to `++`  
  an unset variable will be set to the greatest bound if the last one is defined  

### Examples

```sh
mill date
# Ok. The date refresh.

mill ls -ld /dev/sd*
# Mhh. I can see every single usb drive connected RIGHT NOW.

scale A
mill 'echo $A'
# Cool ! An interactive popup ! And I can still type commands !

B=0
mill 'echo $B; ++ B; [ $B -lt 10 ] || B=0'
# I love cyclic variables.

mill '++ C 9; echo $C'
# Exactly the same thing (9 included).

mill -p 1 python3 myscript.py
# Wonderfull ! The script I'm working on is executed in real time !

scale A 0 10
mill -p 1 'python3 myscript.py $A'
# Even better !
```

-----
_French people love snails_
