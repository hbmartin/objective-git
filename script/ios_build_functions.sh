#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SCRIPT_DIR}/xcode_functions.sh"

function setup_build_environment ()
{
    # augment path to help it find cmake installed in /usr/local/bin,
    # e.g. via brew. Xcode's Run Script phase doesn't seem to honor
    # ~/.MacOSX/environment.plist
    PATH="/usr/local/bin:/opt/boxen/homebrew/bin:$PATH"

    pushd "$SCRIPT_DIR/.." > /dev/null
    ROOT_PATH="$PWD"
    popd > /dev/null

    CLANG="/usr/bin/xcrun clang"
    CC="${CLANG}"
    CPP="${CLANG} -E"

    # We need to clear this so that cmake doesn't have a conniption
    MACOSX_DEPLOYMENT_TARGET=""

    # If IPHONEOS_DEPLOYMENT_TARGET has not been specified
    # setup reasonable defaults to allow running of a build script
    # directly (ie not from an Xcode proj)
    if [ -z "${IPHONEOS_DEPLOYMENT_TARGET}" ]
    then
        IPHONEOS_DEPLOYMENT_TARGET="12.0"
    fi

    # A legacy universal archive can contain only one slice per CPU
    # architecture, so it cannot combine arm64 device and simulator slices.
    # Keep an Intel simulator slice alongside the modern arm64 device slice.
    IOS_ARCHS="${IOS_ARCHS:-x86_64 arm64}"

    # Setup a shared area for our build artifacts
    INSTALL_PATH="${ROOT_PATH}/External/build"
    mkdir -p "${INSTALL_PATH}"
    mkdir -p "${INSTALL_PATH}/log"
    mkdir -p "${INSTALL_PATH}/include"
    mkdir -p "${INSTALL_PATH}/lib/pkgconfig"
}

function build_all_archs ()
{
    setup_build_environment

    local setup=$1
    local build_arch=$2
    local finish_build=$3

    # run the prepare function
    eval $setup

    echo "Building for ${IOS_ARCHS}"

    for ARCH in ${IOS_ARCHS}
    do
        if [ "${ARCH}" == "x86_64" ]
        then
            PLATFORM="iphonesimulator"
        else
            PLATFORM="iphoneos"
        fi

        SDKVERSION=$(ios_sdk_version)

        SDKNAME="${PLATFORM}${SDKVERSION}"
        SDKROOT="$(ios_sdk_path ${SDKNAME})"

        LOG="${INSTALL_PATH}/log/${LIBRARY_NAME}-${ARCH}.log"
        [ -f "${LOG}" ] && rm "${LOG}"

        echo "Building ${LIBRARY_NAME} for ${SDKNAME} ${ARCH}"
        echo "Build log can be found in ${LOG}"
        echo "Please stand by..."

        ARCH_INSTALL_PATH="${INSTALL_PATH}/${SDKNAME}-${ARCH}.sdk"
        mkdir -p "${ARCH_INSTALL_PATH}"

        # run the per arch build command
        eval $build_arch
    done

    # finish the build (usually lipo)
    eval $finish_build
}
