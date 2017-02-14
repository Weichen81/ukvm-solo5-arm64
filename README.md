A script to initialize a development environment for ukvm-solo5-arm64:
1. Run "./ukvm_init.sh" to setup ukvm development environments.
2. After init script, please run "source SETENV.sh" to add
   mirage variables into system environment.

Note:
1. Currently, the patches for ARM64 are just used to make the compilers
happy. They could not work properly on real ARM64 platform.
2. Because the ARM64 compiler flags of ocaml-freestanding has not been
set correctly. When you try to build the sample applications in mirage-skeletion,
you will get some soft-float library link issue.
 
