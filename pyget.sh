#!/bin/bash
# This script downloads a specific version of Python from python.org.
# Positional Args (Optional)
# <[version...]> - Version(s) of Python to download
# Flag Args (Optional)
# -d|--directory <directory> - Directory to install Python to
# -l|--list - List available versions of Python

# Function for getting the size of the terminal
tty_size() {
    stty size 2>/dev/null | awk '{print $2, $1}'
}

# Function for printing text to the screen so it fits to the users terminal
# width, and wraps to the next line if it exceeds the terminal width.
out() {
    # Get the terminal width
    
    size=$(tty_size)
    cols=$(echo $size | cut -d' ' -f1)
    rows=$(echo $size | cut -d' ' -f2)
    
    # Get the length of the string
    len=$(echo -n -e "$@" | wc -c)
    
    # If the length of the string is less than the terminal width, print the
    # string to the screen
    if [[ $len -lt $cols ]]; then
        echo -e "$@"
    else
        # If the length of the string is greater than the terminal width, 
        # print the string to the screen, and wrap the string to the next line
        # if it exceeds the terminal width
        echo -n -e "$@"
        echo
    fi
}

# Set default values
CURRENT_DIR=$(pwd)
BASE_URL="https://www.python.org/ftp/python"
PYTHON_VERSIONS=$(curl -skL "https://www.python.org/ftp/python" | \
    sed -n 's!.*href="\([0-9]\+\.[0-9]\+\.[0-9]\+\)/".*!\1!p' | \
    sort -V)
DESTINATION_PATH=$CURRENT_DIR

print_versions() {
    out "$(echo "$PYTHON_VERSIONS" | wc -l) versions of Python available:"
    for version in $PYTHON_VERSIONS; do
        out "  $version"
    done
}

# Iterate through args and set variables
VERSIONS_SELECTED=()
while [[ $# -gt 0 ]]; do
    key="$1"
    
    case $key in
        -l|--list)
            print_versions
            exit 0
            ;;
        -d|--directory)
            DESTINATION_PATH="$2"
            shift # past argument
            shift # past value
            ;;
        -h|--help)
            out "Usage: pyget.sh [version...]"
            out "       pyget.sh [options]"
            out "Options:"
            out "  -d, --directory <directory> - Directory to install Python to"
            out "  -l, --list                  - List available versions of Python"
            out "  -h, --help                  - Display this help message"
            exit 0
            ;;
        [0-9]*.[0-9]*.[0-9]*)
            VERSIONS_SELECTED+=("$1") # save it in an array for later
            shift # past argument
            ;;
        -*|--*) # unsupported flags
            out "Error: Unknown argument $1"
            exit 1
            ;;
        *)    # unknown option
            shift # past argument
            ;;
    esac
done

# If the user does not pass any positional arguments, print the available
if [[ -z $VERSIONS_SELECTED ]]; then
    out "Error: No version of Python specified.\n"
    # Print the available versions of Python
    out "Please specify a version of Python to download or use the -l or --list flag to list available versions."
    exit 1
fi

# If the user passes version(s) as a positional argument, check if the version(s)
# are valid.
if [[ ! -z $@ ]]; then
    # Iterate through the versions passed as positional arguments
    for version in $@; do
        # If the version is valid, add it to the SELECTED_VERSIONS array
        if echo "$PYTHON_VERSIONS" | grep -q "^$version$"; then
            VERSIONS_SELECTED+=("$version")
        else
            # Else output invalid version and exit with error
            out "Invalid version of Python: $version"
            exit 1
        fi
    done
fi

out "Versions of Python to download:"
for version in "${VERSIONS_SELECTED[@]}"; do
    out "  $version"
done
echo ""

# TODO: Need to fix the prefix issue for the installation directory

# Set variable for installation directories
INSTALLATION_DIRS=()
# Iterate through the selected versions in the SELECTED_VERSIONS array
for version in "${VERSIONS_SELECTED[@]}"; do
    # Set variables
    PYTHON_URL="$BASE_URL/$version/Python-$version.tgz"
    PYTHON_TGZ=$(basename $PYTHON_URL)
    PYTHON_DIR=$(basename $PYTHON_TGZ .tgz)
    OUTPUT_DIR="$DESTINATION_PATH/$PYTHON_DIR"
    
    # Download Python
    echo "Downloading $PYTHON_URL..."
    curl -skL "$PYTHON_URL" -o "$PYTHON_TGZ"
    if [[ $? -ne 0 ]]; then
        echo "Failed to download $PYTHON_URL."
        exit 1
    fi
    
    # Extract Python
    echo "Extracting $PYTHON_TGZ..."
    tar -xzf "$PYTHON_TGZ" -C "$DESTINATION_PATH"
    if [[ $? -ne 0 ]]; then
        echo "Failed to extract $PYTHON_TGZ."
        exit 1
    fi
    
    # Remove Python tarball
    rm "$PYTHON_TGZ"
    
    PRIOR_PWD=$(pwd)
    
    # Change to Python directory
    cd "$OUTPUT_DIR"

    # Build Python
    echo "Configuring Python..."
    ./configure --enable-optimizations --prefix="$(readlink -f "$OUTPUT_DIR")"
    if [[ $? -ne 0 ]]; then
        echo "Failed to configure Python."
        exit 1
    fi

    echo "Building Python..."
    # Check if nproc is available and use it to build Python
    # with the number of available cores
    if command -v nproc &> /dev/null; then
        make -j $(nproc)
    else
        make
    fi
    if [[ $? -ne 0 ]]; then
        echo "Failed to build Python."
        exit 1
    fi

    # Install Python
    echo "Installing Python..."
    make install
    if [[ $? -ne 0 ]]; then
        echo "Failed to install Python."
        exit 1
    fi

    # Change to original directory
    cd "$PRIOR_PWD"
    
    # Add Python directory to installation directories
    INSTALLATION_DIRS+=("$OUTPUT_DIR")
done

# Print installation directories
out "Python versions installed to the following directories:"
for dir in "${INSTALLATION_DIRS[@]}"; do
    out "  $dir"
done

exit 0



# Check if the version of Python is valid, exception for when 
# pass it as a positional argument
if ! echo "$PYTHON_VERSIONS" | grep -q "^$PYTHON_VERSION$"; then
    echo "Invalid version of Python: $PYTHON_VERSION"
    exit 1
fi

# Set default directory to current directory
if [[ -z $PYTHON_DIR ]]; then
    PYTHON_DIR=$(pwd)
elif [[ ! -d $PYTHON_DIR ]]; then
    echo "Directory $PYTHON_DIR does not exist."
    exit 1
fi

# Set variables
PYTHON_URL="$BASE_URL/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
PYTHON_TGZ=$(basename $PYTHON_URL)
PYTHON_DIR=$(basename $PYTHON_TGZ .tgz)

# Download Python
echo "Downloading $PYTHON_URL..."
curl -skL "$PYTHON_URL" -o "$PYTHON_TGZ"
if [[ $? -ne 0 ]]; then
    echo "Failed to download $PYTHON_URL."
    exit 1
fi


echo "Python $PYTHON_VERSION installed to $PYTHON_DIR."
echo ""
echo "To set this version of Python as the default, run:"
echo "   echo \"export PATH=$PYTHON_DIR/bin:\$PATH\" >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "To use this version of Python in the current shell, run:"
echo "   export PATH=$PYTHON_DIR/bin:\$PATH"
echo ""
echo "To use this version of Python in a script, add the following line to the top of the script:"
echo "   #!/usr/bin/env $PYTHON_DIR/bin/python"
echo ""
echo "To use this version of Python in a virtual environment, run:"
echo "   $PYTHON_DIR -m venv <environment_path>"
echo ""

exit 0
