# Snail
[![License](http://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

:snail: _Make your shell interactive_

## Installation
Just download the source, then compile the build :)
```sh
git clone https://github.com/cryhot/snail.git $HOME/snail
make -C $HOME/snail
```
The code of [`SOURCEME.sh`](SOURCEME.sh) must be executed directly in the current shell (use `.` or `source`) in order to access the functionalities.

If you want permanent changes, just add this line to your `.bashrc` (admitting you used the directory `~/snail`) :
```sh
source $HOME/snail/SOURCEME.sh
```
**:warning: If you share your computer with other users, don't forget to remove write perms from the sourced file.**

> Some fonctionalities need special [ptrace permissions](https://www.kernel.org/doc/Documentation/security/Yama.txt). If `/proc/sys/kernel/yama/ptrace_scope` contains something other than `0`, make sure that the file `/etc/sysctl.d/10-ptrace.conf` contains the line :
>
>     kernel.yama.ptrace_scope = 0

## Usage

### Description

- **`mill [-p PERIOD|-i] [-q|-b|-B] [-M] [-T TIMEOUT] [-F FILE] [-C CONDITION] COMMAND...`**  
  run a command in loop; no subshell is created ([see more][man mill])  

- **`scale VAR [MIN] [MAX]`**  
  spawn a scale the user can move to set a numeric value to a variable  
  runs in the background ([see more][man scale])  

- **`++ VAR [MIN] [MAX]`**  
  increment a variable by one  
  if bounds are specified, switch to modular arithmetic ([see more][man ++])  

- **`-- VAR [MIN] [MAX]`**  
  decrement a variable by one  
  if bounds are specified, switch to modular arithmetic ([see more][man --])  

- **`track [-t|-T TIMEOUT] [-o|-a] [-g|-w] FILE...`**  
  pause the script until the file is modified ([see more][man track])  

- **`how [-p INDEX|-P|[COMMAND]...]`**  
  show a command exit status ([see more][man how])  

- **`mmake [OPTION]... [TARGET]...`**  
  basically `mill make` ([see more][man mmake])  

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

mill -F '*.java' 'javac *.java'
# Compile everything on time !

mill -F '*.java' 'snail; javac *.java'
# ...with a little helper

mill -F '*.java' 'javac *.java |& head -16; how -p0'
# more practical case

mill -b -T 300 '
echo "SERVER STARTED - $(date)" | tee -a server.log
./my_server |& tee -a server.log
echo "SERVER CRASHED - $(date)" | tee -a server.log
'
# keep the server running, even in case of crash
# (but with a cooldown of 5 minutes between two restarts)
# sometime, we want the command not to use a buffer...
# (and yes, the command is multiline)

mmake
# a lightweight syntax for a powerfull tool
```

-----
_French people love snails_



[man mill]:  https://github.com/cryhot/snail/wiki/man-mill  "man mill"
[man scale]: https://github.com/cryhot/snail/wiki/man-scale "man scale"
[man ++]:    https://github.com/cryhot/snail/wiki/man-++    "man ++"
[man --]:    https://github.com/cryhot/snail/wiki/man-‐‐    "man --"
[man track]: https://github.com/cryhot/snail/wiki/man-track "man track"
[man how]:   https://github.com/cryhot/snail/wiki/man-how   "man how"
[man mmake]: https://github.com/cryhot/snail/wiki/man-mmake "man mmake"
[man snail]: https://github.com/cryhot/snail/wiki/man-snail "man snail"
