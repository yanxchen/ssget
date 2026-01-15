# ssget for Linux/Mac

This is a command-line version of `ssget` for Linux/macOS, designed to download matrices from the SuiteSparse Matrix Collection. It is not the MATLAB/Java version of `ssget`—see [SuiteSparse/ssget](https://github.com/DrTimothyAldenDavis/SuiteSparse/tree/dev/ssget).

Features:
- Fast matrix search using a CSV index
- Supports multiple file formats
- Batch downloading

## Installation
You can install `ssget` using the automated installer script:
```bash
# Download the installer
$ curl -OL https://raw.githubusercontent.com/yanxchen/ssget/main/install-ssget.sh

# Install to the specific path with --prefix (defaults to current directory)
# e.g. install to $HOME/ssget
$ bash install-ssget.sh --prefix=$HOME/ssget

# (Optional) Add to PATH
$ export PATH=$PATH:/path/to/ssget

# Use the tool
$ ssget --help
```

## Usage

### Options
| Short | Long      | Description                                              |
|-------|-----------|----------------------------------------------------------|
| -i    | --info    | Display matrix metadata and estimated file size          |
| -b    | --batch   | Download matrices listed in a specified text file        |
| -c    | --clean   | Unpack .tar.gz files and remove the archive              |
| -t    | --type    | Choose format: mtx (default), mat, or rb                 |
| -h    | --help    | Show help message                                        |

### Examples

#### 1. View matrix metadata
Display detailed information (dimensions, nonzeros, condition number) without downloading the full archive:
```bash
$ ssget -i nos6

Name:             nos6
Group:            HB
Num Rows:         675
Num Cols:         675
Nonzeros:         3,255
Kind:             2D/3D problem
Symmetric:        Yes
Condition Number: 7.650487e+06
Download Size:    7.46 KB (mtx compressed)
Est. Actual Size: ~31.79 KB (uncompressed)

```

#### 2. Download (and extract)
Download, extract the archive, move files to the current directory, and delete the original .tar.gz file:
```bash
# only download .tar.gz matrix file
$ ssget nos6
# download and extract
$ ssget -c nos6
```

#### 3. Download batch
Create a file (e.g., `matrices.txt`) listing one matrix name per line:
```plain
nos6
parabolic_fem
```

Then run:
```bash
$ ssget -c -b matrices.txt
```
This will download and extract all matrices listed in `matrices.txt`.
