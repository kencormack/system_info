# DEBUG AND PROFILE LOGS IN THE SYSTEM_INFO SCRIPT
## Facilitating debug and profile logs, using file descriptors, traps, and other bash built-ins

![Image](https://raw.githubusercontent.com/kencormack/system_info/master/scr-debug.jpg)

# About

This file will attempt to explain the method I chose to use, to
implement a debugging log feature, in the system_info script.
Likewise, a means of profiling the script's performance has been
added.  Each feature is described below.

# THE DEBUGGING LOG...

This feature is intended for use during testing & development.
It's use by the user will yield no ill effects, and the output
contained in the resulting debugging log may be of limited (if
any) value to the user.  But for those thinking of their own
scripts, or who would modify system_info for their own needs,
the debug log feature demonstrated here could be of some help.

## How it is used

Creating a debug log is done by redirecting file descriptor 3
3 to a logfile of your choosing, when launching system_info
from the commandline.  Basic output redirection should be
nothing new to anyone who has spent a reasonable amount of
time using any UNIX or Linux shell, so I won't go into detail
regarding the basics of output redirection.
```
$ system_info* 3> debug.log
```

Why "3"?  Because linux normally has three built-in file
descriptors already spoken for, by default.  They are:

- File Descriptor 0: stdin  (keyboard, "< filename", etc.)
- File Descriptor 1: stdout (standard output)
- File Descriptor 2: stderr (standard error)

This script adds, for the duration of it's execution, file
descriptor 3, as an I/O channel we can send debugging data to.
You can think of it as:

- File descriptor 3: debug

Normal screen output will be unaffected, and the script will
still generate it's normal report file.  But behind the scenes
it is also writing debugging information.  This always-generated
information either goes to the bit-bucket (/dev/null) when NO
redirection of fd3 is specified on the commandline, OR is sent
TO the user-specified logfile.  This info is entirely seperate
from the unaffected report file, and should not be confused
with the normal system_info report.  There's no overlap or cross
contamination of data, between the two streams of output.

## How it is implemented
## Step 1 - Inheritance

Set up the inheritance needed to gather what we need, within
functions.

Ensure that ERR traps are inherited by functions, command
substitutions, and subshell environments.
```
set -o errtrace
```

Ensure that DEBUG and RETURN traps are inherited by functions,
command substitutions, and subshell environments.  (The -E
causes errors within functions to bubble up.)
```
set -E -o functrace
```

## Step 2 - Create the file descriptor

If it doesn't already exist, create the file descriptor.
```
[ -e /proc/self/fd/3 ] || exec 3> /dev/null
```

## Step 3 - The DEBUG, ERR, and RETURN traps

Next, we define the traps that leverage the file descriptor.
The "errtrace" and "functrace" options we enabled above, allow
these traps to operate as intended within functions, as well.

The DEBUG trap...

This trap writes each line to be executed, just before it is
executed, to the debug log.
```
trap 'echo -e "line#: ${LINENO}...\t${BASH_COMMAND}" >&3' DEBUG
```

The ERR trap...

This trap will log all non-0 return codes.  To prevent some
commands from tripping an ERR trap by returning a non-0 return
code, I'm imediately following those commands with "|| :"
("or true").  An example would be a grep that doesn't find it's
search string (return code 1).  In other words, not all non-0
return codes are "errors" per se, but the trap will spot and
report them.  These can then be investigated to determine if
an actual error has occurred.
```
trap 'echo -e "NON-0: LINE ${LINENO}: RETURN CODE: ${?}\t${BASH_COMMAND}" >&3' ERR
```

The RETURN trap...

This trap logs the completion of each function, upon return.
```
trap 'echo -e "leave: ${FUNCNAME} -> back to ${FUNCNAME[1]}\n" >&3' RETURN
```

## Step 4 - Logging entry into a function

Because the RETURN trap, above, logs only the return FROM a
function, and not the entry INTO a function, I have added the
following to every function of the script.  It logs the full
chain of nested functions that have taken me to that function.
```
echo -e "\nenter: ${FUNCNAME[*]}" >&3
```

## Step 5 - Closing the file descriptor

After the inspections are performed, and the script is ready to
come to an end, we close the file descriptor.  (This command
is also used in the fnABORT function, described next.)
```
exec 3>&- 2> /dev/null
```

## Step 6 - Trapping an unexpected abort

A trap is used, to call a function named "fnABORT", in case the
script terminates prematurely due to any of the signals listed.
One of the commands it includes is to close the file descriptor.
In the event the script fails to reach it's end normally, the
fnABORT function will ensure the file descriptor gets closed.
```
trap fnABORT SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
```

## Step 7 - Detecting redirection

The following detects whether file descriptor 3 has been
redirected to a file.  This is performed after the "exec" that
sets up the file descriptor.
```
DEBUG_LOG="$(${SUDO} readlink /proc/self/fd/3 2>/dev/null)"
```

If no redirection has been applied by the user, "${DEBUG_LOG}"
will be "/dev/null".  But if the user has redirected fd 3 to a
file, then "${DEBUG_LOG}" will contain the name (with full
path), to the file.

In system_info, this is done in the function "fnFINISH_UP", with
the following test...
```
if [ "${DEBUG_LOG}" != "/dev/null" ]
then
  ...
fi
```

# THE PROFILING LOG...

In a manner similar to the debug log mechanism described above,
(but requiring less setup), the script also includes a means to
profile how long it takes for sections of the script to execute.

Using simple timestamped log entries, a rough idea of how long
any lines of code between "set -x" and "set +x" take to run can
be had.  Since I do not require subsecond precision, a simple
timestamp in the form of current "hh:mm:ss" is used on each line
of the profiling log.  The timestamp of a log entry being examined
is the time the command began executing.  Comparison to the
timestamp of the next subsequent line in the log will indicate
how long the line in question took, to complete.  The method used
for the timestamps is built into bash, and thus does not incur
any significant cost (as would forking an external "date" command).

The profiling log is created using file descriptor #4, and the
bash shell's "PS4" and "BASH_XTRACEFD" environment variables.
$PS4 is the shell prompt used to display any lines of code
executed when "set -x" is in effect.  $BASH_XTRACEFD tells bash
which file descriptor to send trace data to.

## How it is used

Creating a profile log is done by redirecting file descriptor 4
to a logfile of your choosing, when launching system_info, in
exactly the same manner as decribed for the debugging feature,
above.
```
$ system_info* 4> profile.log
```

Just like with the debugging data, normal screen output will be
unaffected, and the script will still generate it's normal report
file. But behind the scenes it is also writing profiling data.
This always-generated information either goes to the bit-bucket
(/dev/null) when NO redirection of fd4 is specified on the
commandline, OR is sent TO the user-specified logfile. Again,
this info is entirely seperate from the other data streams.

## How it is implemented

The following block of code sets up the filedescriptor, tells
bash which fd to use, sets PS4 to show a timestamp and the line
number of each line logged, and makes the profiling data available
to file descriptor 4.
```
#---------------
# For a rough profiling of this script
[ -e /proc/self/fd/4 ] || exec 4> /dev/null
echo "SYSTEM_INFO v${MY_VERSION} - PROFILING LOG" >&4
echo -e "==================================\n" >&4
BASH_XTRACEFD="4"
# Using PS4, "\011" is a tab, and "\t" is a current hh:mm:ss timestamp
# (I don't need subsecond accuracy here.)
PS4='+\011\t ${LINENO}\011'
# Enclose any section of code we want to profile with "set -x"... "set +x".
# Profiling data will be sent to the fd whenever "set -x" is in effect.
# For now, I'll turn it on here, and basically profile the whole script.
set -x
```

The following lines are present at both the end of the script, and
in the fnABORT function, to ensure that trace data is no longer
sent to the file descriptor, and that the file descriptor is closed.
```
set +x 2>/dev/null
exec 4>&- 2>/dev/null
```

# How I use these during testing

When working on the system_info script, I generally call upon both the
debugging and profiling features, to ensure that between the report's
usual output, and these additional logs, I have all the diagnostics I
need, to troubleshoot any problems.
```
system_info 3> pi-dev.debug.log 4> pi-dev.profile.log'
```

# In closing

This document may be a little rough at the moment, but it
includes all of the information needed to explain how the
debug and profiling log features were implemented.  The
bash documentation will give more information on every aspect
of what's being used here.
