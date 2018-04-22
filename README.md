# ayfie-reinstaller
Disk jokey style tool that let one install, manage and alternate among verious different versions of the ayfie Inspector

$ ./ayfie_reinstaller.sh -h

Usage: ./ayfie_reinstaller.sh <options>

Options:
  -b                    bounce (or start) ayfie (for default install dir only)
  -d <data dir>         Default: ./data (corresponds to <install dir>/data)
  -e <.env file path>   The .env source location. Default: file auto generated
  -h                    This help
  -i <install dir>      Default: ./<version number>
  -m <GB of RAM>        Default: 64
  -o                    Do installation only, don't start up ayfie
  -p <port>             Default: 20000 + version number
  -r                    Stop and remove ayfie (for default install dir only)
  -s                    Stop ayfie (for default install directory only)
  -v <version>          Mandatory: 1.8.3, 1.9.0, 1.10.3, etc.

