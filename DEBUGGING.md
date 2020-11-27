# Debugging, and the system_info script
## Facilitating a debug log, using a file descriptor, traps, and other bash built-ins

## About

This file will attempt to explain the method I chose to use, to
implement a debug/trace log feature, in the system_info script.

This feature is intended for use during testing & development.
It's use by the user will yield no ill effects, and the output
contained in the resulting debugging log may be of limited (if
any) value to the user.  However, any user choosing to modify
the script for their own purposes will likely find it's data
helpful to their efforts, if they understand how it was done.

## How it is used

Creating a debug log is done by redirecting file descriptor
#3 to a logfile of your choosing, when launching system_info
from the commandline.

```
$ system_info* 3> debug.log
```

Why "3"?  Because linux normally has three built-in file
descriptors already spoken for, by default.  They are:

File Descriptor 0: input
File Descriptor 1: stdout
File Descriptor 2: stderr

This script adds, for the duration of it's execution, file
descriptor 3, as an I/O channel we can send debugging data to.
You can think of it as:

File descriptor 3: debug 

Normal screen output will be unafected, and the script will
still generate it's normal report file.  But behind the scenes
it is also writing debugging information.  This always-present
information either goes to the bit-bucket (/dev/null) when NO
redirection of fd3 is specified on the commandline, OR is
sent TO the user-specified logfile.  This info is entirely
seperate from the unaffected report file, and should not be
confused with the normal system_info report.

## How it was implemented

This first trap executes a function called "fnABORT", any time
the script terminates due to any of the signals listed.  I note
this here, only because one of the statements it includes is
closure of the file descriptor, to be discussed below.

```
# Cleanup if we abort, or are killed for any reason.
trap fnABORT SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
```

Next, we have the following lines of note, with comments
describing what each line does.

```
# Ensure that ERR traps are inherited by functions, command substitutions,
# and subshell environments.
set -o errtrace

# Ensure that DEBUG and RETURN traps are inherited by functions, command substitutions,
# and subshell environments.  (The -E causes errors within functions to bubble up.)
set -E -o functrace
```

Here is where the magic occurs...

```
# Set up the file descriptor for debugging
[ -e /proc/self/fd/3 ] || exec 3> /dev/null
```

Next, we define the traps that leverage the file descriptor.
The "errtrace" and "functrace" options we enabled above, allow
these traps to operate as intended within functions, as well.

```
# This trap writes each line to be executed, just before it is executed, to the debug log
trap 'echo -e "line#: ${LINENO}...\t${BASH_COMMAND}" >&3' DEBUG

# This trap will log all non-0 return codes.
# To prevent some commands from tripping an ERR trap, by returning a non-0 return code,
# I'm imediately following those commands with "|| :" ("or true").
# An example would be a grep that doesn't find it's search string (return code 1).
# In other words, not all non-0 return codes are "errors" per se, but the trap will
# spot and report them.  These can then be investigated to determine if an actual error
# has occurred.
trap 'echo -e "NON-0: LINE ${LINENO}: RETURN CODE: ${?}\t${BASH_COMMAND}" >&3' ERR

# Log the completion of each function, upon return.
# It's a shame there is no corresponding logging of the entry into a function, only
# a return from a function.  This is why each function in this script includes an
# explicit command to add a log entry showing entry into the function.
trap 'echo -e "leave: ${FUNCNAME} -> back to ${FUNCNAME[1]}\n" >&3' RETURN
```

Once the stage is set, the script then does it's job, with a
call to "fnMAIN".  After the inspections are performed and
the script is ready to come to an end, we close the file
descriptor.

```
# Close the file descriptor
exec 3>&- 2> /dev/null
```

Because the RETURN trap logs only the return FROM a function, and
not the entry INTO a function, I have added the following to every
function of the script.  Written as it is, it logs the full chain
of nested functions that have taken me to that function.

```
# This line, included in every function, is part of the debugging/trace
# log stuff used in testing & development of this script.  See the file
# DEBBUGGING.md on the github page, for a full explaination of how I
# chose to implement a debug/trace log.
echo -e "\nenter: ${FUNCNAME[*]}" >&3
```

## In closing

This "DEBUGGING.md" document may be a little rough at the
moment, but it includes all of the information needed to
explain how the debug logging feature was implemented.
The bash documentation will give more information on every
aspect of what's being used here.