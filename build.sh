#!/usr/bin/env bash

set -euo pipefail



setup() {

  xtra_flags=""

  if [[ "$EXPORT_TARGET" == "android" ]]; then

    echo "::group::Installing Swappy Android"

    python ./misc/scripts/install_swappy_android.py

    echo "::endgroup::"

  fi

  if [[ "$EXPORT_TARGET" == "windows" ]]; then

    echo "::group::Installing Direct3D 12 driver"

    python ./misc/scripts/install_d3d12_sdk_windows.py

    xtra_flags+=" d3d12=yes"

    echo "::endgroup::"

  fi


  # echo "::group::Cloning Godot project"

  # git clone \
  #   --quiet \
  #   --no-progress \
  #   --depth=1 \
  #   --branch="$PROJECT_REF" \
  #   "https://github.com/$PROJECT_REPOSITORY.git" \
  #   "/godot-project/src-project/"

  # TODO: turn these two to args

  cp "$GITHUB_WORKSPACE/custom.py" "/godot-project/src-godot" || true
  cp "$GITHUB_WORKSPACE/custom.gdbuild" "/godot-project/src-godot" || true

  # cp "/godot-project/src-project/godot-project/custom.py" . || true
  # cp "/godot-project/src-project/godot-project/custom.gdbuild" . || true

  if [[ -f "custom.py" ]]; then
    echo "custom.py file detected..."
    xtra_flags+=" profile=custom.py"
  fi

  if [[ -f "custom.gdbuild" ]]; then
    echo "custom.gdbuild file detected..."
    xtra_flags+=" build_profile=custom.gdbuild"
  fi

  # echo "::endgroup::"

  echo "EXTRA_FLAGS=$xtra_flags" >> "$GITHUB_ENV"

}



build() {

  xtra_flags="$EXTRA_FLAGS"

  if [[ "$EXPORT_TARGET" == "windows" ]]; then

    echo "Updating POSIX..."

    xtra_flags+=" use_mingw=yes"

    sudo update-alternatives --set x86_64-w64-mingw32-gcc \
      /usr/bin/x86_64-w64-mingw32-gcc-posix

    sudo update-alternatives --set x86_64-w64-mingw32-g++ \
      /usr/bin/x86_64-w64-mingw32-g++-posix

  fi


  if [[ "$EXPORT_TARGET" == "android" ]]; then

    unset ANDROID_SDK_ROOT

    if [[ "$EXPORT_ARCH" == "arm32-arm64" ]]; then

      scons -j4 platform="$EXPORT_TARGET" arch=arm32 $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
      scons -j4 platform="$EXPORT_TARGET" arch=arm64 $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no generate_android_binaries=yes

      scons -j4 platform="$EXPORT_TARGET" arch=arm32 $xtra_flags target=template_debug
      scons -j4 platform="$EXPORT_TARGET" arch=arm64 $xtra_flags target=template_debug generate_android_binaries=yes

    else

      scons -j4 platform="$EXPORT_TARGET" arch="$EXPORT_ARCH" $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no
      scons -j4 platform="$EXPORT_TARGET" arch="$EXPORT_ARCH" $xtra_flags target=template_debug generate_android_binaries=yes

    fi

  else

    scons -j4 platform="$EXPORT_TARGET" arch="$EXPORT_ARCH" $xtra_flags target=template_release production=yes debug_symbols=no lto=full dev_build=no

  fi

  7zz a -t7z -mx=9 -m0=lzma2 -mfb=273 -md=256m -mmt=4 -ms=on "$GITHUB_WORKSPACE/$EXPORT_TARGET-$EXPORT_ARCH.7z" "./bin/*" -xr!obj -xr!build_deps

}


# case "$1" in
#   setup)
#     setup
#     ;;
#   build)
#     build
#     ;;
# esac

setup

build
