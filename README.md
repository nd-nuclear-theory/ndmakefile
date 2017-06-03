# ndmakefile

To use within a project, first add as a submodule

   git submodule add ../ndmakefile config/ndmakefile
   git submodule init

then symlink to the makefile from the top level directory of the
repository

   ln -s config/ndmakefile/makefile