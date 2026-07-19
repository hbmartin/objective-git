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

    # Each slice is a "<platform>:<arch>" pair. An XCFramework can carry a
    # device arm64 slice and a simulator arm64 slice side by side (a lipo'd
    # fat archive could not hold two slices of the same architecture).
    IOS_SLICES="${IOS_SLICES:-iphoneos:arm64 iphonesimulator:arm64}"

    # Setup a shared area for our build artifacts
    INSTALL_PATH="${ROOT_PATH}/External/build"
    mkdir -p "${INSTALL_PATH}"
    mkdir -p "${INSTALL_PATH}/log"
    mkdir -p "${INSTALL_PATH}/include"
}

function build_all_slices ()
{
    setup_build_environment

    local setup=$1
    local build_slice=$2
    local finish_build=$3

    # run the prepare function
    eval $setup

    echo "Building slices: ${IOS_SLICES}"

    for SLICE in ${IOS_SLICES}
    do
        PLATFORM="${SLICE%%:*}"
        ARCH="${SLICE#*:}"

        case "${PLATFORM}" in
            iphoneos)
                CLANG_TARGET="${ARCH}-apple-ios${IPHONEOS_DEPLOYMENT_TARGET}"
                ;;
            iphonesimulator)
                CLANG_TARGET="${ARCH}-apple-ios${IPHONEOS_DEPLOYMENT_TARGET}-simulator"
                ;;
            *)
                echo "error: unknown platform '${PLATFORM}' in slice '${SLICE}'" >&2
                exit 1
                ;;
        esac

        SDKVERSION=$(ios_sdk_version)

        SDKNAME="${PLATFORM}${SDKVERSION}"
        SDKROOT="$(ios_sdk_path ${SDKNAME})"

        LOG="${INSTALL_PATH}/log/${LIBRARY_NAME}-${PLATFORM}-${ARCH}.log"
        [ -f "${LOG}" ] && rm "${LOG}"

        echo "Building ${LIBRARY_NAME} for ${SDKNAME} ${ARCH}"
        echo "Build log can be found in ${LOG}"
        echo "Please stand by..."

        ARCH_INSTALL_PATH="${INSTALL_PATH}/${SDKNAME}-${ARCH}.sdk"
        mkdir -p "${ARCH_INSTALL_PATH}"

        # run the per slice build command
        eval $build_slice
    done

    # finish the build (create the xcframework)
    eval $finish_build
}

# create_xcframework <name> <library> [<library> ...]
# Combines one static library per slice into External/build/<name>.xcframework.
function create_xcframework ()
{
    local name=$1
    shift

    local output="${INSTALL_PATH}/${name}.xcframework"
    local args=()
    local library

    for library in "$@"
    do
        args+=(-library "${library}")
    done

    # xcodebuild refuses to overwrite an existing bundle
    rm -rf "${output}"

    /usr/bin/xcrun xcodebuild -create-xcframework "${args[@]}" -output "${output}"
}
