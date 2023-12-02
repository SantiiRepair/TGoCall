#!/bin/bash

usage() {
    echo ""
}

if [ $# -eq 0 ]; then
    echo "Not enough arguments in the call."
    exit 1
fi

TARGET=linux
CLANG=false
BOOST=false

DCMAKE_BUILD_TYPE=Release

while true; do
    case "$1" in 
        --TARGET | --TARGET= | --TARGET=$2)
            TARGET="$2"
            shift 2
            ;;
        *)
            n=0
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
done

for arg in "$@"; do 
    if [[ "$arg" == "--CLANG" ]]; then 
        CLANG=true
    elif [[ "$arg" == "--DEBUG" ]]; then 
        DCMAKE_BUILD_TYPE=Debug
    elif [[ "$arg" == "--BOOST" ]]; then 
        BOOST=true
    elif [[ "$arg" == "-h" || "$arg" == "--help" ]]; then 
        usage
    fi; 
done

if [ $TARGET = "linux" ]; then
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
fi