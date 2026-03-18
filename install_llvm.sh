#!/bin/bash

set -euo pipefail

# LLVM 17+ requires GCC 12 or later to build.
# ./install_llvm.sh "$HOME/Projects/llvm-22" 22 1
# ./install_llvm.sh "$HOME/Projects/llvm-22" 22 1 Debug
# ./install_llvm.sh "$HOME/Projects/llvm-22" 22 1 Release
# ./install_llvm.sh "$HOME/Projects/llvm-22" 22 1 RelWithDebInfo
# CC=gcc-13 CXX=g++-13 ./install_llvm.sh "$HOME/Projects/llvm-22" 22 1

NPROC=$(nproc)
NUM_THREADS="${NUM_THREADS:-$(( NPROC > 1 ? NPROC - 1 : 1 ))}"
if ! [[ "$NUM_THREADS" =~ ^[0-9]+$ ]] || [[ "$NUM_THREADS" -lt 1 ]]; then
    NUM_THREADS=1
fi

append_cmake_list_item() {
    local var_name="$1"
    local item="$2"
    local current_value="${!var_name:-}"
    local entry

    IFS=';' read -r -a entries <<< "$current_value"
    for entry in "${entries[@]}"; do
        if [[ "$entry" == "$item" ]]; then
            return 0
        fi
    done

    if [[ -n "$current_value" ]]; then
        printf -v "$var_name" '%s;%s' "$current_value" "$item"
    else
        printf -v "$var_name" '%s' "$item"
    fi
}

pick_first_tool() {
    local tool
    for tool in "$@"; do
        if command -v "$tool" >/dev/null 2>&1; then
            command -v "$tool"
            return 0
        fi
    done
    return 1
}

pick_first_executable() {
    local candidate
    for candidate in "$@"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

ensure_versioned_llvm_tool_symlink() {
    local bindir="$1"
    local tool_name="$2"
    local major_version="$3"
    local base_tool="$bindir/$tool_name"
    local versioned_tool="$bindir/${tool_name}-${major_version}"

    if [[ -e "$base_tool" && ! -e "$versioned_tool" ]]; then
        ln -sfn "$tool_name" "$versioned_tool"
    fi
}

run_sanitized_env() {
    env -u C_INCLUDE_PATH \
        -u CPLUS_INCLUDE_PATH \
        -u CPATH \
        -u LIBRARY_PATH \
        -u LD_LIBRARY_PATH \
        "$@"
}

normalize_build_type() {
    local requested="${1:-}"

    case "${requested,,}" in
        "")
            printf '%s\n' "RelWithDebInfo"
            ;;
        0|release)
            printf '%s\n' "Release"
            ;;
        1|debug)
            printf '%s\n' "Debug"
            ;;
        relwithdebinfo|rel-with-deb-info)
            printf '%s\n' "RelWithDebInfo"
            ;;
        minsizerel|min-size-rel)
            printf '%s\n' "MinSizeRel"
            ;;
        *)
            echo "Unsupported LLVM build type '$requested'. Use Release, Debug, RelWithDebInfo, or MinSizeRel." >&2
            return 1
            ;;
    esac
}

cache_entry_equals() {
    local cache_path="$1"
    local cache_key="$2"
    local expected_value="$3"

    awk -v key="$cache_key" -v expected="$expected_value" '
        {
            split($0, parts, "=")
            if (length(parts) < 2) {
                next
            }
            value = substr($0, index($0, "=") + 1)
            split(parts[1], header, ":")
            if (header[1] == key && value == expected) {
                found = 1
                exit 0
            }
        }
        END {
            exit(found ? 0 : 1)
        }
    ' "$cache_path"
}

llvm_cache_matches_requested_config() {
    local cache_path="$1"
    local expected

    [[ -f "$cache_path" ]] || return 1

    local expected_lines=(
        "CMAKE_BUILD_TYPE=$BUILD_TYPE"
        "CMAKE_INSTALL_PREFIX=$LLVM_PATH"
        "LLVM_ENABLE_ASSERTIONS=$LLVM_ASSERTIONS"
        "LLVM_BUILD_LLVM_DYLIB=ON"
        "LLVM_ENABLE_RTTI=ON"
        "LLVM_ENABLE_PROJECTS=$LLVM_PROJECTS"
        "LLVM_ENABLE_RUNTIMES=$LLVM_RUNTIMES"
        "LLVM_LINK_LLVM_DYLIB=ON"
        "CLANG_LINK_CLANG_DYLIB=ON"
        "LLVM_TOOL_CLANG_BUILD=TRUE"
        "LLVM_TOOL_FLANG_BUILD=TRUE"
    )

    if [[ $ENABLE_GPU_OFFLOAD -eq 1 ]]; then
        expected_lines+=(
            "LLVM_TARGETS_TO_BUILD=$LLVM_TARGETS"
            "LLVM_RUNTIME_TARGETS=$LLVM_RUNTIME_TARGETS"
            "LIBOMPTARGET_ENABLE_DEBUG=$LIBOMPTARGET_DEBUG"
        )
    fi

    for expected in "${expected_lines[@]}"; do
        local expected_key="${expected%%=*}"
        local expected_value="${expected#*=}"
        if ! cache_entry_equals "$cache_path" "$expected_key" "$expected_value"; then
            return 1
        fi
    done

    return 0
}

if [[ -z "${1:-}" ]]; then
    LLVM_ROOT="$HOME/llvm"
else
    LLVM_ROOT="$1"
fi

if [[ -z "${2:-}" ]]; then
    LLVM_BRANCH=""
else
    LLVM_BRANCH="release/$2.x"
fi

ENABLE_GPU_OFFLOAD=0
if [[ -n "${3:-}" ]]; then
    ENABLE_GPU_OFFLOAD=1
fi

BUILD_TYPE=$(normalize_build_type "${4:-}")
LLVM_ASSERTIONS=OFF
if [[ "$BUILD_TYPE" == "Debug" ]]; then
    LLVM_ASSERTIONS=ON
fi
LIBOMPTARGET_DEBUG=OFF

CC_BIN=${CC:-}
CXX_BIN=${CXX:-}
FC_BIN=${FC:-}

if [[ -z "$CC_BIN" ]]; then
    # Prefer Clang 22 so the produced LLVM/Clang binaries match the downstream
    # REX toolchain expectations, including float128-related APFloat symbols.
    CC_BIN=$(pick_first_executable /usr/bin/clang-22 /usr/bin/clang /usr/bin/gcc-13 /usr/bin/gcc-14 /usr/bin/gcc || \
        pick_first_tool clang-22 clang gcc-13 gcc-14 gcc)
fi

if [[ -z "$CXX_BIN" ]]; then
    CXX_BIN=$(pick_first_executable /usr/bin/clang++-22 /usr/bin/clang++ /usr/bin/g++-13 /usr/bin/g++-14 /usr/bin/g++ || \
        pick_first_tool clang++-22 clang++ g++-13 g++-14 g++)
fi

if [[ -z "$FC_BIN" ]] && command -v gfortran-13 >/dev/null 2>&1; then
    FC_BIN=$(command -v gfortran-13)
fi
if [[ -z "$FC_BIN" ]] && command -v gfortran-14 >/dev/null 2>&1; then
    FC_BIN=$(command -v gfortran-14)
fi
if [[ -z "$FC_BIN" ]] && command -v gfortran >/dev/null 2>&1; then
    FC_BIN=$(command -v gfortran)
fi

GNU_TRIPLE=$(run_sanitized_env "$CC_BIN" -dumpmachine)

export LLVM_SRC="$LLVM_ROOT/llvm_src"
export LLVM_BUILD="$LLVM_ROOT/llvm_build"
export LLVM_PATH="$LLVM_ROOT/llvm_install"

mkdir -p "$LLVM_SRC" "$LLVM_BUILD" "$LLVM_PATH"

if [[ -d "$LLVM_SRC/.git" ]]; then
    git -C "$LLVM_SRC" fetch --all --tags --prune
    if [[ -n "$LLVM_BRANCH" ]]; then
        git -C "$LLVM_SRC" checkout "$LLVM_BRANCH"
        git -C "$LLVM_SRC" pull --ff-only
    fi
elif [[ -e "$LLVM_SRC/CMakeLists.txt" || -e "$LLVM_SRC/llvm/CMakeLists.txt" ]]; then
    echo "Using existing LLVM source tree in $LLVM_SRC"
else
    if [[ -n "$LLVM_BRANCH" ]]; then
        git clone --branch "$LLVM_BRANCH" https://github.com/llvm/llvm-project "$LLVM_SRC"
    else
        git clone https://github.com/llvm/llvm-project "$LLVM_SRC"
    fi
fi

if [[ -f "$LLVM_SRC/llvm/cmake/config.guess" ]]; then
    LLVM_TARGET_TRIPLE=$(sh "$LLVM_SRC/llvm/cmake/config.guess")
else
    LLVM_TARGET_TRIPLE="$GNU_TRIPLE"
fi

LLVM_PROJECTS=${LLVM_PROJECTS:-clang;clang-tools-extra;lld}
LLVM_RUNTIMES=${LLVM_RUNTIMES:-compiler-rt;libunwind;libcxx;libcxxabi;openmp}
append_cmake_list_item LLVM_PROJECTS flang
append_cmake_list_item LLVM_RUNTIMES flang-rt
LLVM_TARGETS="host"
LLVM_RUNTIME_TARGETS="default"
LLVM_BINUTILS_INCDIR=""
LLVM_BUILD_GOLD_PLUGIN=OFF

for candidate in /usr/include /usr/include/bfd /usr/include/binutils; do
    if [[ -f "$candidate/plugin-api.h" ]]; then
        LLVM_BINUTILS_INCDIR="$candidate"
        LLVM_BUILD_GOLD_PLUGIN=ON
        break
    fi
done

cmake_args=(
    -G Ninja
    -S "$LLVM_SRC/llvm"
    -B "$LLVM_BUILD"
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
    -DCMAKE_C_COMPILER="$CC_BIN"
    -DCMAKE_CXX_COMPILER="$CXX_BIN"
    -DCMAKE_C_COMPILER_TARGET="$LLVM_TARGET_TRIPLE"
    -DCMAKE_CXX_COMPILER_TARGET="$LLVM_TARGET_TRIPLE"
    -DCMAKE_INSTALL_PREFIX="$LLVM_PATH"
    -DLLVM_BUILD_DOCS=OFF
    -DLLVM_BUILD_LLVM_DYLIB=ON
    -DLLVM_DEFAULT_TARGET_TRIPLE="$LLVM_TARGET_TRIPLE"
    -DLLVM_ENABLE_ASSERTIONS="$LLVM_ASSERTIONS"
    -DLLVM_ENABLE_RTTI=ON
    -DLLVM_ENABLE_PROJECTS="$LLVM_PROJECTS"
    -DLLVM_ENABLE_RUNTIMES="$LLVM_RUNTIMES"
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON
    -DLLVM_INCLUDE_TESTS=OFF
    -DCLANG_INCLUDE_TESTS=OFF
    -DCLANG_LINK_CLANG_DYLIB=ON
    -DFLANG_ENABLE_FLANG_RT=ON
    -DLLVM_BUILD_TESTS=OFF
    -DLLVM_INCLUDE_BENCHMARKS=OFF
    -DLLVM_LINK_LLVM_DYLIB=ON
    -DLLVM_TOOL_GOLD_BUILD="$LLVM_BUILD_GOLD_PLUGIN"
    -DOPENMP_ENABLE_LIBOMP_PROFILING=ON
    -DOPENMP_ENABLE_LIBOMPTARGET=ON
)

if [[ -n "$FC_BIN" ]]; then
    cmake_args+=(-DCMAKE_Fortran_COMPILER="$FC_BIN")
fi

if command -v mold >/dev/null 2>&1; then
    cmake_args+=(-DLLVM_USE_LINKER=mold)
fi

cmake_args+=(-DLLVM_BINUTILS_INCDIR="$LLVM_BINUTILS_INCDIR")

if [[ $ENABLE_GPU_OFFLOAD -eq 1 ]]; then
    LLVM_RUNTIMES="$LLVM_RUNTIMES;offload"
    LLVM_TARGETS="$LLVM_TARGETS;NVPTX"
    LLVM_RUNTIME_TARGETS="$LLVM_RUNTIME_TARGETS;nvptx64-nvidia-cuda"
    LIBOMPTARGET_DEBUG=ON
    cmake_args+=(
        -DLLVM_ENABLE_RUNTIMES="$LLVM_RUNTIMES"
        -DLLVM_TARGETS_TO_BUILD="$LLVM_TARGETS"
        -DLLVM_RUNTIME_TARGETS="$LLVM_RUNTIME_TARGETS"
        -DRUNTIMES_nvptx64-nvidia-cuda_LLVM_ENABLE_RUNTIMES="compiler-rt;openmp"
        -DLIBOMPTARGET_ENABLE_DEBUG="$LIBOMPTARGET_DEBUG"
        -DLIBOMPTARGET_BUILD_DEVICERTL_BCLIB=ON
    )
fi

cache_path="$LLVM_BUILD/CMakeCache.txt"
if [[ -f "$cache_path" ]] && ! llvm_cache_matches_requested_config "$cache_path"; then
    echo "Existing LLVM build cache does not match the requested configuration. Removing $LLVM_BUILD"
    rm -rf "$LLVM_BUILD"
    mkdir -p "$LLVM_BUILD"
fi

echo "Configuring LLVM:"
printf '  %q\n' env -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u CPATH -u LIBRARY_PATH -u LD_LIBRARY_PATH cmake "${cmake_args[@]}"

run_sanitized_env cmake "${cmake_args[@]}"

if ! llvm_cache_matches_requested_config "$cache_path"; then
    echo "Configured LLVM cache did not retain the requested options. Reconfiguring from a clean build directory."
    rm -rf "$LLVM_BUILD"
    mkdir -p "$LLVM_BUILD"

    run_sanitized_env cmake "${cmake_args[@]}"

    if ! llvm_cache_matches_requested_config "$cache_path"; then
        echo "LLVM configure completed, but $cache_path does not match the requested configuration" >&2
        exit 1
    fi
fi

run_sanitized_env ninja -C "$LLVM_BUILD" -j"$NUM_THREADS" -l"$NUM_THREADS"

run_sanitized_env ninja -C "$LLVM_BUILD" install -j"$NUM_THREADS"

if [[ -x "$LLVM_PATH/bin/flang" ]]; then
    flang_resource_dir=$(run_sanitized_env "$LLVM_PATH/bin/flang" -print-resource-dir)
    flang_target_triple=$(run_sanitized_env "$LLVM_PATH/bin/flang" -print-target-triple)
    expected_flang_rt_dir="$flang_resource_dir/lib/$flang_target_triple"
    actual_flang_rt_archive=$(find "$flang_resource_dir/lib" -maxdepth 2 -type f -name 'libflang_rt.runtime.a' | sed -n '1p')

    if [[ -z "$actual_flang_rt_archive" ]]; then
        echo "LLVM install completed, but libflang_rt.runtime.a was not found under $flang_resource_dir/lib" >&2
        exit 1
    fi

    actual_flang_rt_dir=$(dirname "$actual_flang_rt_archive")
    if [[ "$actual_flang_rt_dir" != "$expected_flang_rt_dir" ]]; then
        mkdir -p "$expected_flang_rt_dir"
        for runtime_lib in "$actual_flang_rt_dir"/libflang_rt.*; do
            [[ -e "$runtime_lib" ]] || continue
            ln -sfn "$runtime_lib" "$expected_flang_rt_dir/$(basename "$runtime_lib")"
        done
    fi
fi

if [[ -x "$LLVM_PATH/bin/llvm-config" ]]; then
    installed_llvm_major=$(
        run_sanitized_env "$LLVM_PATH/bin/llvm-config" --version |
        sed -nE 's/^([0-9]+).*/\1/p'
    )
    if [[ -n "$installed_llvm_major" ]]; then
        ensure_versioned_llvm_tool_symlink "$LLVM_PATH/bin" clang "$installed_llvm_major"
        ensure_versioned_llvm_tool_symlink "$LLVM_PATH/bin" "clang++" "$installed_llvm_major"
        ensure_versioned_llvm_tool_symlink "$LLVM_PATH/bin" flang "$installed_llvm_major"
        ensure_versioned_llvm_tool_symlink "$LLVM_PATH/bin" llvm-config "$installed_llvm_major"
    fi
fi

clang_cpp_dylib="$LLVM_PATH/lib/libclang-cpp.so"
if [[ ! -e "$clang_cpp_dylib" ]]; then
    clang_cpp_dylib=$(find "$LLVM_PATH/lib" -maxdepth 1 \( -type f -o -type l \) -name 'libclang-cpp.so*' | LC_ALL=C sort | sed -n '1p' || true)
fi
if [[ -n "$clang_cpp_dylib" ]]; then
    for required_symbol in \
        'typeinfo for clang::ASTConsumer' \
        'typeinfo for clang::PPCallbacks' \
        'typeinfo for clang::CommentHandler'; do
        if ! grep -Fq "$required_symbol" < <(nm -D -C "$clang_cpp_dylib"); then
            echo "LLVM install completed, but $clang_cpp_dylib is missing required RTTI export '$required_symbol'" >&2
            exit 1
        fi
    done
fi

llvm_dylib="$LLVM_PATH/lib/libLLVM.so"
if [[ ! -e "$llvm_dylib" ]]; then
    llvm_dylib=$(find "$LLVM_PATH/lib" -maxdepth 1 \( -type f -o -type l \) -name 'libLLVM.so*' | LC_ALL=C sort | sed -n '1p' || true)
fi
if [[ -n "$llvm_dylib" ]] && [[ -x "$LLVM_PATH/bin/clang++" ]]; then
    if grep -q '__FLOAT128__' < <(run_sanitized_env "$LLVM_PATH/bin/clang++" -dM -E -x c++ /dev/null); then
        if ! grep -Fq 'llvm::APFloat::convertToQuad() const' < <(nm -D -C "$llvm_dylib"); then
            echo "LLVM install completed, but $llvm_dylib is missing llvm::APFloat::convertToQuad() const" >&2
            exit 1
        fi
    fi
fi

if [[ $ENABLE_GPU_OFFLOAD -eq 1 ]]; then
    libomptarget_path=$(find "$LLVM_PATH" \( -type f -o -type l \) -name 'libomptarget.so*' | sed -n '1p')
    if [[ -z "$libomptarget_path" ]]; then
        echo "LLVM install completed, but libomptarget.so was not found under $LLVM_PATH" >&2
        exit 1
    fi

    required_patterns=(
        'libomptarget-nvptx.bc'
        'libompdevice.a'
    )
    for pattern in "${required_patterns[@]}"; do
        if [[ -z "$(find "$LLVM_PATH" \( -type f -o -type l \) -name "$pattern" | sed -n '1p')" ]]; then
            echo "LLVM install completed, but required GPU offload artifact '$pattern' was not found under $LLVM_PATH" >&2
            exit 1
        fi
    done

    if [[ -x "$LLVM_PATH/bin/nvptx-arch" ]] && [[ -x "$LLVM_PATH/bin/clang" ]]; then
        offload_arch=$(run_sanitized_env "$LLVM_PATH/bin/nvptx-arch" 2>/dev/null | sed -n '1p' || true)
        if [[ -n "$offload_arch" ]]; then
            smoke_dir=$(mktemp -d)
            trap 'rm -rf "$smoke_dir"' EXIT

            cat > "$smoke_dir/omp_target_smoke.c" <<'EOF'
#include <omp.h>

int main(void) {
  int value = 0;
  int on_device = 0;
  #pragma omp target map(tofrom: value, on_device)
  {
    value = 1;
    on_device = !omp_is_initial_device();
  }
  return (value == 1 && on_device) ? 0 : 1;
}
EOF

            host_runtime_dir=$(dirname "$libomptarget_path")
            smoke_ld_library_path="$host_runtime_dir"
            if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
                smoke_ld_library_path="$smoke_ld_library_path:$LD_LIBRARY_PATH"
            fi

            if ! env LD_LIBRARY_PATH="$smoke_ld_library_path" \
                    OMP_TARGET_OFFLOAD=MANDATORY \
                    "$LLVM_PATH/bin/clang" -fopenmp --offload-arch="$offload_arch" \
                    "$smoke_dir/omp_target_smoke.c" -o "$smoke_dir/omp_target_smoke" \
                || ! env LD_LIBRARY_PATH="$smoke_ld_library_path" \
                    OMP_TARGET_OFFLOAD=MANDATORY \
                    "$smoke_dir/omp_target_smoke"; then
                echo "LLVM install completed, but the installed clang/libomptarget failed a GPU offload smoke test" >&2
                exit 1
            fi

            rm -rf "$smoke_dir"
            trap - EXIT
        fi
    fi
fi
