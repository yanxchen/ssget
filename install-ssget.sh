#!/bin/bash
# ssget Installer Script

# Default installation directory
PREFIX=$(pwd)
CSV_URL="https://raw.githubusercontent.com/DrTimothyAldenDavis/SuiteSparse/dev/ssget/files/ssstats.csv"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --prefix=*) PREFIX="${1#*=}"; shift ;;
        --prefix) PREFIX="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

INSTALL_DIR="$PREFIX"
DATA_DIR="$INSTALL_DIR/.ssget_data"
BIN_PATH="$INSTALL_DIR/ssget"
CSV_PATH="$DATA_DIR/ssstats.csv"

echo "[*] Installing ssget to: $INSTALL_DIR"

# Create directories
mkdir -p "$DATA_DIR"

# Download the metadata index
echo "[*] Downloading SuiteSparse index CSV file (ssstats.csv)..."
echo "    from: $CSV_URL"
curl -L -o "$CSV_PATH" "$CSV_URL"

if [ $? -ne 0 ]; then
    echo "[-] Error: Failed to download metadata index."
    exit 1
fi

# Create the ssget script
echo "[*] Creating ssget executable..."
cat << 'EOF' > "$BIN_PATH"
#!/bin/bash

# --- CONFIGURATION (Set by installer) ---
CSV_PATH="REPLACE_ME_CSV_PATH"
BASE_URL="https://sparse.tamu.edu"
# ----------------------------------------

TYPE="mtx"
CLEAN=false
INFO_MODE=false
TARGET_NAME=""
BATCH_FILE=""

usage() {
    echo "ssget - SuiteSparse Matrix Collection Downloader"
    echo ""
    echo "Basic usage: ssget [OPTIONS] <MatrixName | -b File>"
    echo ""
    echo "Options:"
    echo "  -i, --info <name>    Print detailed info (single matrix only)"
    echo "  -b, --batch <file>   Download multiple matrices listed in a text file"
    echo "  -c, --clean          Extract files and delete the archive folder"
    echo "  -t, --type <type>    File format: mtx (Matrix Market, default)"
    echo "                                    mat (MATLAB)"
    echo "                                    rb  (Rutherford-Boeing)"
    echo "  -h, --help           Show this help message"
    echo ""
    exit 0
}

format_bytes() {
    awk -v b="$1" 'BEGIN {
        if (b <= 0) { print "Unknown"; exit; }
        split("B KB MB GB TB", unit);
        i = 1;
        while (b >= 1024 && i < 5) {
            b /= 1024;
            i++;
        }
        if (i == 1) printf "%d %s", b, unit[i];
        else printf "%.2f %s", b, unit[i];
    }'
}

download_matrix() {
    local t_name=$1
    local match=$(grep -i ",$t_name," "$CSV_PATH" | head -n 1)
    
    if [ -z "$match" ]; then
        echo "[-] Error: Matrix '$t_name' not found in index. Skipping..."
        return
    fi

    local group=$(echo "$match" | awk -F, '{print $1}')
    local name=$(echo "$match" | awk -F, '{print $2}')
    local dl_url=""
    local ext=""

    case "$TYPE" in
        mtx) dl_url="${BASE_URL}/MM/${group}/${name}.tar.gz"; ext=".tar.gz" ;;
        mat) dl_url="${BASE_URL}/mat/${group}/${name}.mat"; ext=".mat" ;;
        rb)  dl_url="${BASE_URL}/RB/${group}/${name}.tar.gz"; ext=".tar.gz" ;;
    esac

    local filename="${name}${ext}"
    echo "[+] Matrix: $name (Group: $group)"
    echo "    Downloading $dl_url ..."
    curl -# -L -o "$filename" "$dl_url"

    if [ "$CLEAN" = true ] && [[ "$filename" == *".tar.gz" ]]; then
        echo "    Unpacking and cleaning up archive..."
        tar -xzf "$filename"
        if [ -d "$name" ]; then
            mv "$name"/* . 2>/dev/null
            rmdir "$name"
            rm "$filename"
            echo "    Done. File(s) moved to current directory."
        fi
    fi
    echo "------------------------------------------------"
}

if [[ "$#" -eq 0 ]]; then usage; fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--info) INFO_MODE=true; shift; TARGET_NAME="$1"; shift ;;
        -b|--batch) shift; BATCH_FILE="$1"; shift ;;
        -c|--clean) CLEAN=true; shift ;;
        -t|--type) TYPE="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) TARGET_NAME="$1"; shift ;;
    esac
done

if [[ ! -f "$CSV_PATH" ]]; then
    echo "Error: Local index file '$CSV_PATH' not found."
    exit 1
fi

if [ "$INFO_MODE" = true ]; then
    if [ -z "$TARGET_NAME" ]; then echo "Error: Specify a matrix name."; exit 1; fi
    MATCH=$(grep -i ",$TARGET_NAME," "$CSV_PATH" | head -n 1)
    if [ -z "$MATCH" ]; then echo "Error: Not found."; exit 1; fi

    GROUP=$(echo "$MATCH" | awk -F, '{print $1}')
    NAME=$(echo "$MATCH" | awk -F, '{print $2}')
    ROWS=$(echo "$MATCH" | awk -F, '{print $3}')
    COLS=$(echo "$MATCH" | awk -F, '{print $4}')
    NNZ=$(echo "$MATCH" | awk -F, '{print $5}')
    KIND=$(echo "$MATCH" | awk -F, '{print $12}' | tr -d '"')

    case "$TYPE" in
        mtx) URL="${BASE_URL}/MM/${GROUP}/${NAME}.tar.gz" ;;
        mat) URL="${BASE_URL}/mat/${GROUP}/${NAME}.mat" ;;
        rb)  URL="${BASE_URL}/RB/${GROUP}/${NAME}.tar.gz" ;;
    esac

    HEADERS=$(curl -sIL "$URL")
    SIZE_BYTES=$(echo "$HEADERS" | grep -i "^Content-Length:" | tail -n 1 | awk '{print $2}' | tr -d '\r' | tr -d ' ')
    DOWNLOAD_SIZE=$(format_bytes "$SIZE_BYTES")
    EST_UNCOMPRESSED_BYTES=$(awk -v nz="$NNZ" 'BEGIN { print nz * 10 }')
    UNCOMPRESSED_SIZE=$(format_bytes "$EST_UNCOMPRESSED_BYTES")

    HTML=$(curl -s -L "${BASE_URL}/${GROUP}/${NAME}")
    CLEAN_TEXT=$(echo "$HTML" | sed 's/<[^>]*>/ /g' | tr '\n' ' ' | tr -s ' ')
    COND=$(echo "$CLEAN_TEXT" | perl -ne 'print $1 if /Condition [Nn]umber\s+([\d\.e\+\-]+)/i')
    SYMMETRIC=$(echo "$CLEAN_TEXT" | perl -ne 'print $1 if /Symmetric\s+(Yes|No)/i')
    
    echo ""
    echo "Name:             $NAME"
    echo "Group:            $GROUP"
    echo "Num Rows:         $(printf "%'d" "$ROWS")"
    echo "Num Cols:         $(printf "%'d" "$COLS")"
    echo "Nonzeros:         $(printf "%'d" "$NNZ")"
    echo "Kind:             $KIND"
    echo "Symmetric:        ${SYMMETRIC:-No}"
    [ -n "$COND" ] && echo "Condition Number: $COND"
    echo "Download Size:    $DOWNLOAD_SIZE ($TYPE compressed)"
    echo "Est. Actual Size: ~$UNCOMPRESSED_SIZE (uncompressed)"
    echo ""
    exit 0
fi

if [ -n "$BATCH_FILE" ]; then
    if [ ! -f "$BATCH_FILE" ]; then echo "Error: Batch file not found."; exit 1; fi
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        download_matrix "$line"
    done < "$BATCH_FILE"
else
    download_matrix "$TARGET_NAME"
fi
EOF

 # Update the CSV_PATH in the generated script (cross-platform sed)
if sed --version >/dev/null 2>&1; then
    # GNU sed (Linux)
    sed -i "s|REPLACE_ME_CSV_PATH|$CSV_PATH|g" "$BIN_PATH"
else
    # BSD sed (macOS)
    sed -i '' "s|REPLACE_ME_CSV_PATH|$CSV_PATH|g" "$BIN_PATH"
fi
chmod +x "$BIN_PATH"

echo "[+] Success! You can now run: $BIN_PATH"
echo "[+] Optional: Add $INSTALL_DIR to your PATH environment variable:"
echo "              export PATH=\"\$PATH:$INSTALL_DIR\""