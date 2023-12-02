#!/bin/bash

usage() {
    echo ""
}

if [ $# -eq 0 ]; then
    echo "Not enough arguments in the call."
    exit 1
fi

n=0
TARGET=linux
CLANG=false
BOOST=false

DCMAKE_BUILD_TYPE=Release


case "$1" in 
    "--TARGET" | "--TARGET=linux" | "--TARGET=macos")
        if [[ $1 == *"="* ]]; then
            cmd=$(echo $1 | cut -d'=' -f1)
            os=$(echo $1 | cut -d'=' -f2)

            TARGET=$os
            shift
        elif [[ $2 ]]; then
            TARGET="$2"
            shift 2
        fi
        ;;
    *)
        if [[ ${#@} -eq 0 ]]; then
            break
        fi

        for opt in --CLANG --DEBUG --BOOST --help; do
            for arg in $@; do
                if [[ "$opt" == "$arg" ]]; then 
                    ((n++))
                fi
            done
        done

        if [[ $n -eq 0 || ${#@} -ge 5 ]]; then
                echo "Unrecognized option, see usage."
                exit 1
        fi
        break
        ;;
esac

for arg in "$@"; do 
    if [[ "$arg" == "--CLANG" ]]; then 
        CLANG=true
    elif [[ "$arg" == "--DEBUG" ]]; then 
        DCMAKE_BUILD_TYPE=Debug
    elif [[ "$arg" == "--BOOST" ]]; then 
        BOOST=true
    elif [[ "$arg" == "--help" ]]; then 
        usage
    fi; 
done

if [[ $TARGET == "linux" ]]; then
    apt-get update && apt-get upgrade -y
    apt-get install -y make git zlib1g-dev libssl-dev gperf php-cli cmake g++
    git clone https://github.com/tdlib/td.git
    cd td
    rm -rf build
    mkdir build
    cd build
    if [ $CLANG ]; then
        CXXFLAGS="-stdlib=libc++" CC=/usr/bin/clang-14 CXX=/usr/bin/clang++-14 cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=../tdlib ..
    elif [ ! $CLANG ]; then
        cmake -DCMAKE_BUILD_TYPE=DCMAKE_BUILD_TYPE -DCMAKE_INSTALL_PREFIX:PATH=../tdlib ..
    fi

    if [ $BOOST ]; then
        cmake --build . --target install
        cd ..
    elif [ ! $BOOST ]; then
        cmake --build . --target prepare_cross_compiling
        cd ..
        php SplitSource.php
        cd build
        cmake --build . --target install
        cd ..
        php SplitSource.php --undo
    fi
    cd ..
    ls -l td/tdlib
    exit 0

elif [[ $TARGET == "macos" ]]; then
    xcode-select --install
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install gperf cmake openssl
    git clone https://github.com/tdlib/td.git
    cd td
    rm -rf build
    mkdir build
    cd build
    cmake -DCMAKE_BUILD_TYPE=Release -DOPENSSL_ROOT_DIR=/opt/homebrew/opt/openssl/ -DCMAKE_INSTALL_PREFIX:PATH=../tdlib ..
    cmake --build . --target install
    cd ..
    cd ..
    ls -l td/tdlib
    exit 0
fi

echo "This $TARGET is not available for building."
exit 1