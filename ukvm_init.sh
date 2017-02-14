#!/bin/sh
INIT_DIR=${PWD}
UKVM_DIR=${INIT_DIR}/ukvm-devel
DEPS_DIR=${INIT_DIR}/depends
UKVM_TGT=mirage-solo5-dev

export OPAMJOBS=8

live_or_die()
{
    echo "<<<========================== ******* ==========================>>>"
    if [ $1 -ne 0 ]
    then
        echo "$2 failed!"
        echo
        exit 1
    else
        echo "$2 successfully!"
        echo
    fi
}


install_system_package()
{
    apt-get install -y $1
    live_or_die $? "Install system package $1"
}

install_opam_package()
{
    opam install -y $1
    live_or_die $? "Install OPAM package $1"
}

# Install necessary system packages
install_system_package opam
install_system_package debianutils
install_system_package m4
install_system_package ncurses-dev
install_system_package pkg-config
install_system_package time

# Initialize opam for current user
rm -rf ~/.opam
opam init -a
live_or_die $? "Initialize opam for current user"

# Update system environment variables
eval `opam config env`

# To avoid issues related to non-system installations of `ocamlfind`
# add the following lines to ~/.ocamlinit
cat > ~/.ocamlinit <<_ACEOF
let () =
  try Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ()
;;
_ACEOF

# Start with a fresh OPAM switch for the Mirage/Solo5 target
opam switch --alias-of 4.03.0 ${UKVM_TGT}
live_or_die $? "Start with a fresh OPAM switch for the Mirage/Solo5 target"

# To use the latest development version of MirageOS
opam repo add mirage-dev git://github.com/mirage/mirage-dev

# Install depext plugin for opam
opam install -y depext
live_or_die $? "Install depext plugin for OPAM"

# Install the MirageOS library operating system
opam depext -i -y mirage
live_or_die $? "Install the MirageOS library operating system"

# Install OPAM dependent packages
OPAM_DEPS="mirage-logs mirage-block-lwt \
           mirage-channel-lwt mirage-clock-freestanding \
           mirage-console-lwt mirage-fs-lwt mirage-types-lwt \
           ocaml-src ocb-stubblr parse-argv alcotest tcpip"

for package in ${OPAM_DEPS}
do
    opam install -y ${package}
    live_or_die $? "Install OPAM package ${package}"
done

# Update system environment variables
eval `opam config env`

# Create a working directory
mkdir -p ${UKVM_DIR}
live_or_die $? "Create a working directory"

# Create dependent packages directory
mkdir -p ${DEPS_DIR}
live_or_die $? "Create dependent packages directory"

############################ solo5-kernel #####################################
# Enter the working directory
cd ${UKVM_DIR}

# Clone the Solo5-kernel repository
git clone https://github.com/Solo5/solo5.git
live_or_die $? "Clone the Solo5-kernel repository"

# Apply a temp ARM64 support patch of solo5-kernel
cd solo5
git reset --hard 50b73b82ac7cdc0183e77e337e0f96712b9546b1
git am ${INIT_DIR}/0001-Add-arm64-support-for-Solo5.patch
live_or_die $? "Apply a temp ARM64 support patch of solo5-kernel"

# Build and install solo5-kernel-ukvm package
./configure.sh
make opam-ukvm-install PREFIX=~/.opam/${UKVM_TGT}
live_or_die $? "Build and install solo5-kernel-ukvm package"

######################### ocaml-freestanding ##################################
# Enter the working directory
cd ${UKVM_DIR}

# Clone the ocaml-freestanding package
git clone https://github.com/mirage/ocaml-freestanding.git ocaml-freestanding
live_or_die $? "Clone the ocaml-freestanding package"

# Apply a temp ARM64 support patch of ocaml-freestanding
cd ocaml-freestanding
git reset --hard 52db3c02c00c2ad01f94b52ad9e1d8988e3bf2f5
git am ${INIT_DIR}/0001-Add-arm64-support-for-ocaml-freestanding.patch
live_or_die $? "Apply a temp ARM64 support patch of ocaml-freestanding"

# Configure ocaml-freestanding
./configure.sh
live_or_die $? "Configure ocaml-freestanding"

# Build ocaml-freestanding
make
live_or_die $? "Build ocaml-freestanding"

# Install ocaml-freestanding
make install PREFIX=$(opam config var prefix)
live_or_die $? "Install ocaml-freestanding"

############################# mirage-solo5 ####################################
# Enter the working directory
cd ${UKVM_DIR}

# Clone the Mirage OS platform bindings for Solo5 repository
git clone https://github.com/mirage/mirage-solo5.git
live_or_die $? "Clone the Mirage OS platform bindings for Solo5 repository"

# Apply a temp ARM64 support patch of mirage-solo5
cd mirage-solo5
git reset --hard f6f4a046b2e5ba62216c111590815dd2ad3b676c
git am ${INIT_DIR}/0001-Add-arm64-support-for-mirage-solo5.patch

# Generate a Makefile for mirage-solo5
cat > Makefile <<_ACEOF
all:
	ocaml pkg/pkg.ml build --pkg-name mirage-solo5

clean:
	ocaml pkg/pkg.ml clean --pkg-name mirage-solo5

_ACEOF

# Build mirage-solo5
make
live_or_die $? "Build mirage-solo5"

# Install mirage-solo5
opam-installer mirage-solo5.install --prefix=~/.opam/${UKVM_TGT}
live_or_die $? "Install mirage-solo5"

######################## mirage-solo5 Dependencies ############################
# Clone, build and install the Mirage/Solo5 dependent packages
M5_DEPS="mirage-bootvar-solo5;509ce62e4d41e30085e78d2eac12a633fe1f3833 \
         mirage-block-solo5;09a0a8a76c35634d29a0bb69cd54bacf580ef6ca \
         mirage-console-solo5;e4837c0a09f3f120f626b6201ef6392776181fa5 \
         mirage-net-solo5;90c76738b4d4ede527f5abf76fd460bfe53101b6"

for package in ${M5_DEPS}
do
    cd ${DEPS_DIR}
    PACK_NAME=${package%;*}
    PACK_VER=${package#*;}
    git clone https://github.com/mirage/${PACK_NAME}.git
    live_or_die $? "Clone package ${PACK_NAME}"

    # Build and Install the package
    cd ${PACK_NAME}
    git reset --hard ${PACK_VER}
    ocaml pkg/pkg.ml build -n ${PACK_NAME} -q
    live_or_die $? "Building ${PACK_NAME}"
    opam-installer ${PACK_NAME}.install --prefix=~/.opam/${UKVM_TGT}
    live_or_die $? "Installing package ${PACK_NAME}"
done

###############################################################################
cd ${UKVM_DIR}

# Clone the mirage-dev example applications repository
git clone -b mirage-dev https://github.com/mirage/mirage-skeleton
