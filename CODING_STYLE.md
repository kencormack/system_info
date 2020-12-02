# CODING STYLE & CONVENTIONS USED THROUGHOUT THIS SCRIPT

Not everyone will agree with the conventions below, and equally valid
arguments could be made to counter each of these practices.  But as
long as each "way" is syntactically valid, I stick with the practices
that have served me well for three decades.

- Variables are CAPITALIZED for faster recognition.

- Variables, once defined, are referenced within curly braces, and within
  double-quotes.
```
  eg: "${VARIABLE}"
```

- All function names are CAPITALIZED, with "fn" prefixes, for fast
  recognition.
```
  eg: fnFUNCTION
```

- I like spaces between commands, variables, operators and other elements.
```
  eg: this...
    "This is very easy to read."
  not...
    "Thisstrainsmyeyesandgivesmeaheadache."
```

- I prefer not chaining sequences of commands, seperated by semi-colons,
  on a single line.  Commands are (more or less) one per line.
```
  eg: this...
    comand
    comand
    comand
  not...
    command ; command ; command
  or worse...
    command;command;command
```

- If I have to chain very long sequence of pipelines, I will sometimes
  break things up over multiple lines, using backslashes to supress
  end-of-line, though there are several exceptions to this.
```
  eg: this...
    command \
    | command \
    | command \
    | command
  not...
    command | command | command | command
  or worse...
    command|command|command|command
```

- Although not very efficient, I prefer multiple echo statements be used,
  one per line, rather than a multi-line block of text within a single echo.
  This is again, for easier readability and comprehension.
```
  eg: this...
    echo "This is line 1"
    echo "This is line 2"
    echo "This is line 3"
  not...
    echo "This is line 1
    This is line 2
    This is line 3"
```

- Though I normally work on a wide screen (greater than 80 characters),
  I prefer to keep things within the confines of an 80x24 screen so that
  should I find myself working within that limitation, my code remains
  readable, without an excessive amount of wrapped text breaking things up.
  I note, however, that this script contains a few prominent long lines.

- I hate 8-char tabs for indentation.  They waste entirely too much screen
  real estate, and often greatly hinder the ability to keep things
  readable within the confines, again, of an 80-char screen.  Thus, I find
  2 spaces for each level of indentation sufficient.

- Related to chaining commands with semi-colons, I do not care at all for
  the convention of putting "then" on the same line as the "if", or "do"
  on the same line as the "while", and so on.  I prefer seperate lines.
```
  eg: this...
    if some condition
    then
      do something here
    else
      do something different here
    fi
  not...
    if some condition ; then
      do something here ; else
      do something different here ; fi
```

- I apply comments liberally throughout my code.  A.) They help others
  understand what my script is doing.  Others are free to call it
  pedantic, but if it helps new coders understand something the script
  is doing, then I feel ok, being verbose.  B.) They remind me of what's
  going on when I have to re-visit a script after a year of not looking
  at it.  C.) Too many times, links to info I need will go bye bye after
  a while.  Incorporating the info I need directly into comments ensures
  I don't lose that info.

- Three tools that I use regularly while maintaining this script:

  The "vim" editor, with syntax highlighting enabled.

  "shellcheck" to spot fat-fingered coding errors
  https://github.com/koalaman/shellcheck

  "beautysh" to keep things formatted as intended.
  https://github.com/lovesegfault/beautysh
