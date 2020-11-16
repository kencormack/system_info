# Getting the latest lynis deb package

The version of "lynis" in the raspbian repos is VERY old.  The instructions that follow, for installing the latest community version, were taken from the following link:

  [https://packages.cisofy.com/community/#debian-ubuntu](https://packages.cisofy.com/community/#debian-ubuntu)

===========================================

## Import key
Download the key from a central keyserver:
```
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C80E383C3DE9F082E01391A0366C67DE91CA5D5F
```

Or manually import it:
```
  sudo wget -O - https://packages.cisofy.com/keys/cisofy-software-public.key | sudo apt-key add -
```

## Add software repository
The software repository uses preferably HTTPS for secure transport. Install the 'https' method for APT, if it was not available yet.
```
  sudo apt install apt-transport-https
```

Using your software in English? Then configure APT to skip downloading translations. This saves bandwidth and prevents additional load on the repository servers.
```
  echo 'Acquire::Languages "none";' | sudo tee /etc/apt/apt.conf.d/99disable-translations
```

## Add the repository:
```
  echo "deb https://packages.cisofy.com/community/lynis/deb/ stable main" | sudo tee /etc/apt/sources.list.d/cisofy-lynis.list
```

## Install Lynis
Refresh the local package database with the new repository data and install Lynis:
```
  sudo apt update
```

Got an error after running this command? Check if you filled in the 'codename' correctly and the line is correct. Those small details that may prevent it from working.
```
  sudo apt install lynis
```

## Confirm Lynis version
```
  lynis show version
```

Is your version not the latest? Run "sudo apt-cache policy lynis" to see where your package came from.
```
  sudo apt-cache policy lynis
```

## Consider pinning
If you keep receiving an old version from your distribution, 'pin' the Lynis package. Create the file /etc/apt/preferences.d/lynis with the following contents:
```
  Package: lynis
  Pin: origin packages.cisofy.com
  Pin-Priority: 600
```
