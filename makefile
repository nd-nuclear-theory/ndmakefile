################################################################
#
# makefile for C++ or hybrid C++/FORTRAN projects
#
# Language: GNU make
#
# Mark A. Caprio
# Department of Physics
# University of Notre Dame
#
# 2/24/11 (mac): Created.
# 3/10/11 (mac): Initial development completed.
# 4/25/11 (mac): Addition of search_dirs_include and search_dirs_lib
#   configuration variables.  Addition of optional environment variable
#   HYBRID_MAKE_DIR for config.mk location.
# 5/02/11 (tdyt): Launch prepare_install_directory script during install.
# 11/5/11 (mac): Add installation script hook install_script.
# 7/4/13 (mac): Dereference symlinks when creating distribution tarball.
# 9/16/16 (mac):
#   - Add defaults for config.mk variables.
#   - Add "make install_lib" to optionally also install libraries.
# 6/3/17 (mac):
#   - Add support for standalone module compilation (MAKEFILE_STANDALONE).
#   - Rename environment variable for fallback config directory
#     (MAKEFILE_CONFIG_DIR).
#   - Enable override of install_dir_bin.
#   - DEPRECATED: list-mpi-objects-cpp and list-mpi-programs-cpp
# 7/12/17 (pjf): Add support for producing shared object (.so) files.
# 7/18/17 (mac): Force creation of installation directories.
# 11/28/17 (pjf): Add macros for including version information in executables.
# 12/10/17 (mac): Separate out test programs in target programs-test.
#
################################################################

################################################################
#
# config.mk -- describes the external library and compiler configuration
#
# This file contains the information which is likely to be different
# for each machine on which the project is built.
#
# Variables to set up in config.mk:
#
#   search_prefix -- list of one or more directory trees into which
#     external libraries have been installed, e.g., $HOME/local,
#     instead of or in addition to the compiler's default paths (e.g.,
#     /usr/local)
#
#   search_dirs_include -- additional directory to search for include
#     files *only* (useful if a source library is installed with a
#     nonconventional tree structure)
#
#   search_dirs_lib -- additional directory to search for library
#     files *only* (useful if a source library is installed with a
#     nonconventional tree structure)
#
#   fortran_libs -- the libraries required for a C++ project to
#     properly link when including FORTRAN objects
#
#   fortran_flags -- linking flags required for a C++ project to
#     include FORTRAN objects
#
#   shared_ldflags -- linking flags required for producing a shared
#     object (.so) file.
#
# These are all initialized to a null string, so config.mk can
# append to them (with +=) if preferred.
#
# The config file would also normally define the compile commands to
# use (FC and CXX) and any machine specific flags for these compilers.
#
################################################################
#
# project.mk -- defines the contents of the project
#
# This file contains the information on the overall structure of the
# project and compiler/linking configuration for the whole project
# (but is machine independent).
#
# --------
#
# Variables to define in project.mk:
#
# project_name: project name, e.g., for use in the tar file name
#   when make produces a source tar distribution
#
# modules: list of "modules", i.e., subdirectories each of which
#   a module.mk include file
#
# extras (optional): list of extra files or directories to be bundled in the
#   source tar distribution (e.g., README.md)
#
# install_prefix (optional): install prefix, e.g., binaries are installed to
#   <install_prefix>/bin (default: ".")
#
# install_dir_bin (optional): to override binary install directory name
#   (default: <install_prefix>/bin)
#
# install_script (optional): script to be run during "make install", after binaries
#   have been installed to binary directory
#
# --------
#
# $(eval $(vcs-git)) -- should be included if the project is under source control
#   using Git; sets VCS_REVISION preprocessor macro
#
# $(eval $(vcs-SVN)) -- should be included if the project is under source control
#   using SVN; sets VCS_REVISION preprocessor macro
#
# --------
#
# This file would also normally define various compiler and linker
# flags common to the whole project.
#
################################################################
#
# module.mk (for each project "module", i.e., subdirectory):
#
# --------
#
# File should begin with $(eval $(begin-module))
#
# --------
#
# Variables defining the compilation units in this module (and other
# date files to be generated):
#
# module_units_h -- units consisting of file.h only
# module_units_cpp-h -- units consisting of file.cpp + file.h
#   for compilation to file.o and inclusion in library
# module_units_f -- units consisting of file.f only
# module_programs_cpp -- programs consisting of file.cpp to be compiled and linked
# module_programs_cpp_test -- test programs consisting of file.cpp to be compiled and linked
# module_programs_f -- programs consisting of file.f to be compiled and linked
# module_generated -- generated files created by rules defined in module.mk files
#
# These variables also determine the *source* files to be included in the source tar.
#
# --------
#
# $(eval $(library)) -- should be included if the object files are to
#   be assembled into a library archive (named after the module
#   directory)
#
# $(eval $(shared-library)) -- should be included if the object files are to
#   be assembled into a shared object file (named after the module
#   directory)
#
# --------
#
# This file would also normally define any dependencies and target-specific
# variable assignments.
#
# Notes:
# (1) All filenames must be relative to the top of the source tree,
#   i.e., SU3NCSM/src.
# (2) The current directory for this module can be referenced
#   as $(current-dir), in the target and prerequisite names.
# (3) Predefined prerequisites:
#    All object files from units_cpp-h are already dependent on both
#      their .cpp and .h file.
#    All object files from units_f are already dependent on
#      their .f file.
#
# EX: $(current-dir)/myunit.o : $(current-dir)/anotherunit.h libraries/somelibrary/somelibrary.h
#    Note $(current-dir)/myunit.h already assumed by makefile.
#
# (4) However, $(current-dir) should not appear in the rule to build the target
#    since evaluation of the rules is delayed, and $(current-dir) will not longer
#    hold the correct directory name at run time.
#
# EX: $(current-dir)/data-file :  $(current-dir)/data-generator
#     [TAB] cd $(dir $@); ./data-generator
#    Note we have used $(dir $@) rather than the (inappropriate) $(current-dir)
#    to recover the module's directory in the build command.
#
# --------
#
# File should end with $(eval $(end-module))
#
################################################################
#
# Environment variables
#
# MAKEFILE_CONFIG_DIR (optional) -- If set, config.mk will be sought
# in this directory instead of the current working directory.
#
# MAKEFILE_STANDALONE (optional) -- Define for special case in which
# this makefile is being used for standalone compilation of a module
# ("modules += ."), to avoid errors such as circular dependencies.
#
################################################################

################################################################
################################################################
#
# project configuration
#
################################################################
################################################################

################################################################
# version control system setup
################################################################

#$(eval $(vcs-git))
#  Extract Git commit information and store in vcs_revision
#  Note: eval needed for multi-line macro at top level of file
define vcs-git
  vcs_revision := $(shell git describe --tags --always --dirty)
endef

#$(eval $(vcs-svn))
#  Extract SVN revision information and store in vcs_revision
#  Note: eval needed for multi-line macro at top level of file
define vcs-svn
  vcs_revision := $(shell svnversion -n .)
endef

################################################################
# load config.mk
################################################################

search_prefix :=
search_dirs_include :=
search_dirs_lib :=
fortran_libs :=
fortran_flags :=
shared_ldflags :=
install_prefix := .

MAKEFILE_CONFIG_DIR ?= .
include $(MAKEFILE_CONFIG_DIR)/config.mk

################################################################
# load project.mk
################################################################

extras :=
include project.mk

################################################################
# declare default target
################################################################

.PHONY: splash
splash:

################################################################
# pass VCS info to compiler
################################################################
ifdef vcs_revision
  CPPFLAGS += -D'VCS_REVISION="$(vcs_revision)"'
endif

################################################################
################################################################
#
# macro definitions
#
################################################################
################################################################

################################################################
# string and path utilities
################################################################

#($call last-word,list)
#  returns last word of list
define last-word
$(word $(words $1),$1)
endef

#($call strip-trailing-slash,list)
#  strips any trailing slash from each word of list
#  after Mecklenburg p. 68
define strip-trailing-slash
$(patsubst %/,%,$1)
endef

#($call sandwich,prefix,list,suffix)
#  adds both prefix and suffix to each entry in list
define sandwich
$(patsubst %,$(1)%$(3),$(2))
endef

#$(current-dir)
#  returns subdirectory from which project makefile was invoked
#  relative to make directory
#  after Mecklenburg p. 142
define current-dir
$(strip $(call strip-trailing-slash,$(dir $(call last-word,$(MAKEFILE_LIST)))))
endef

#$(get-exe-ext)
#  returns system-specific executable extension
#  assuming COMSPEC is defined only under MS Windows
ifdef COMSPEC
  get-exe-ext := .exe
else
  get-exe-ext :=
endif

################################################################
# accumulation
################################################################

#$(eval $(begin-module))
#  Clear all module "local" variables
#  Note: eval needed for multi-line macro at top level of file
define begin-module
  module_units_h :=
  module_units_cpp-h :=
  module_units_f :=
  module_programs_cpp :=
  module_programs_cpp_test :=
  module_programs_f :=
  module_generated :=
endef

#$(eval $(library-name))
#
#  Helper function generates current library name, depending whether
#  module is standalone or part of larger project.  This is just a
#  workaround for the failure of ifdef inside "define library":
#
#    ifdef MAKEFILE_STANDALONE
#      $(eval module_library := lib$(project_name))
#    else
#      $(eval module_library := lib$(notdir $(current-dir)))
#    endif

ifdef MAKEFILE_STANDALONE
define library-name
    lib$(project_name)
endef
else
define library-name
    lib$(notdir $(current-dir))
endef
endif

#$(eval $(library))
#  creates definitions so that local module forms a library
#  and defines dependency on object files
define library
  $(eval module_library := $(library-name))
  $(eval module_library_ar_name := $(call sandwich,$(current-dir)/,$(module_library),.a))
  $(eval module_library_units := $(module_units_cpp-h) $(module_units_f))
  $(eval module_library_objects := $(call sandwich,$(current-dir)/,$(module_library_units),.o))
  libraries += $(addprefix $(current-dir)/,$(module_library))
  library_journal += $(module_library) - $(module_library_units) ...
  $(foreach obj,$(module_library_objects),$(eval $(module_library_ar_name): $(obj)) )
endef

define shared-library
  $(eval module_library_so_name := $(call sandwich,$(current-dir)/,$(module_library),.so))
  shared_libraries += $(addprefix $(current-dir)/,$(module_library))
  $(foreach obj,$(module_library_objects),$(eval $(module_library_so_name): $(obj)) )
endef

#$(eval $(end-module))
#   accumulate local unit information into global lists
#  Note: eval needed for multi-line macro at top level of file
define end-module
  units_h += $(addprefix $(current-dir)/,$(module_units_h))
  units_cpp-h += $(addprefix $(current-dir)/,$(module_units_cpp-h))
  units_f += $(addprefix $(current-dir)/,$(module_units_f))
  programs_cpp += $(addprefix $(current-dir)/,$(module_programs_cpp))
  programs_cpp_test += $(addprefix $(current-dir)/,$(module_programs_cpp_test))
  programs_f += $(addprefix $(current-dir)/,$(module_programs_f))
  generated += $(addprefix $(current-dir)/,$(module_generated))
endef

# Debugging note: The dependency declaration
#   $(module_library_ar_name): $(module_library_objects)
# yields virtual memory overflow errors (GNU make 3.80 Cygwin) for long
# lists of object files (more than ~5).  This is due to a known bug in GNU
# make 3.80, fixed in 3.81:
#   http://stackoverflow.com/questions/2428506/workaround-for-gnu-make-3-80-eval-bug
#   When $(eval) evaluates a line that is over 193 characters, Make
#   crashes with a "Virtual Memory Exhausted" error.
# The workaround applied here is to add the dependencies one by on in a foreach
# *without* enclosing the foreach in an eval.


################################################################
# include search path setup
################################################################

# define basic directories
#
# assumes tree:
# <project_base>/
# <project_base>/libraries
# ...
project_base := $(dir $(PWD))
src_library_dir := ./libraries

# search path for external library include files
#   from config.mk
CPPFLAGS += $(call sandwich,-I,$(search_prefix),/include)
vpath %.h $(call sandwich,,$(search_prefix),/include)
CPPFLAGS += $(call sandwich,-I,$(search_dirs_include),)
vpath %.h $(call sandwich,,$(search_dirs_include),)

# search path for internal library include files
CPPFLAGS += -I$(src_library_dir)
vpath %.h $(src_library_dir)

################################################################
# library search path setup
################################################################

# search path for required external libraries
#   from config.mk
LDFLAGS += $(call sandwich,-L,$(search_prefix),/lib)
LDFLAGS += $(call sandwich,-L,$(search_dirs_lib),)

# search path for internal library archive files
#   which will be specified using libxxxx.a rather than -lxxxx syntax
vpath %.a $(src_library_dir)

################################################################
# FORTRAN linking setup
################################################################

# linking options for linking to FORTRAN
#   from config.mk
LDLIBS += $(fortran_libs)
LDFLAGS += $(fortran_flags)

################################################################
################################################################
#
# module processing
#
################################################################
################################################################

################################################################
# accumulator list declarations
################################################################

# units_h -- units consisting of file.h only
units_h :=

# units_cpp-h -- units consisting of file.cpp + file.h
#   for compilation to file.o and inclusion in library
units_cpp-h :=

# units_f -- units consisting of file.f only
units_f :=

# libraries -- libraries consisting of file.a to be used in program linking
libraries :=

# shared_libraries -- shared libraries consisting of file.so to be linked
shared_libraries :=

# programs_cpp -- programs consisting of file.cpp to be compiled and linked
programs_cpp :=

# programs_cpp_test -- test programs consisting of file.cpp to be compiled and linked
programs_cpp_test :=

# programs_f -- programs consisting of file.f to be compiled and linked
programs_f :=

# generated -- generated files created by rules defined in module.mk files
generated :=

# diagnostic accumulators
library_journal :=
debug_output :=

################################################################
# iteration over modules
################################################################

module_files := $(addsuffix /module.mk,$(modules))
include $(module_files)

################################################################
# deduced filenames
################################################################

cpp_ext := .cpp
h_ext := .h
f_ext := .F
o_ext := .o
archive_ext := .a
so_ext := .so
binary_ext := $(get-exe-ext)

sources_cpp := $(addsuffix $(cpp_ext),$(units_cpp-h) $(programs_cpp) $(programs_cpp_test))
sources_h := $(addsuffix $(h_ext),$(units_cpp-h) $(units_h))
sources_f := $(addsuffix $(f_ext),$(units_f) $(programs_f))
sources := $(sources_cpp) $(sources_h) $(sources_f)

makefiles := $(MAKEFILE_LIST)

objects := $(addsuffix $(o_ext),$(units_cpp-h) $(units_f) $(programs_cpp) $(programs_f))
objects_test := $(addsuffix $(o_ext),$(programs_cpp_test))

archives := $(addsuffix $(archive_ext),$(libraries))
shared_objects := $(addsuffix $(so_ext),$(shared_libraries))

programs := $(programs_cpp) $(programs_f)
programs_test := $(programs_cpp_test)

executables := $(addsuffix $(binary_ext),$(programs))
executables_test := $(addsuffix $(binary_ext),$(programs-test))

################################################################
################################################################
#
# targets
#
################################################################
################################################################

################################################################
# rules and dependencies
################################################################

# make all executables dependent upon all project libraries
#   Note: There is then no need to add the libraries to LDLIBS,
#   since they will appear in the dependencies argument to the linker.
ifneq "$(strip $(programs))" ""
$(programs): $(archives)
endif

ifneq "$(strip $(programs_test))" ""
$(programs_test): $(archives)
endif

# make all units_cpp-h object files dependent on the header file
#   using static pattern rule
ifneq "$(strip $(units_cpp-h))" ""
$(addsuffix .o,$(units_cpp-h)): %.o: %.h
endif

# object library rule
ARFLAGS = r
%.a:
	$(RM) $@
	$(AR) $(ARFLAGS) $@ $^

%.so: #$(archives)
	$(RM) $@
	$(LD) $(LDFLAGS) $(shared_ldflags) -shared $^ $(LOADLIBES) $(LDLIBS) -o $@

################################################################
# linker
################################################################

# link C++ programs using C++ compiler
ifneq "$(strip $(programs_cpp))" ""
$(programs_cpp): CC := $(CXX)
$(programs_cpp_test): CC := $(CXX)
endif

# link FORTRAN programs using FORTRAN compiler
ifneq "$(strip $(programs_f))" ""
$(programs_f): CC=$(FC)
endif

################################################################
# special handling of MPI codes (DEPRECATED)
################################################################

# compile and link MPI C++ programs using MPICXX wrapper
#
#   Functions $(list-mpi-programs-cpp) and $(list-mpi-objects-cpp) for
#   deciding which files need MPI for this project must be defined in
#   project.mk:
#
#     list-mpi-programs-cpp (optional): *function* which determines
#       which program files should be compiled or linked with MPI;
#       will be evaluated *after* all module.mk files have been read
#
#     list-mpi-objects-cpp (optional): *function* which determines
#       which C++ object files should be compiled with MPI; will be
#       evaluated *after* all module.mk files have been read
#
#     MPICXX (optional): the MPI C++ command, if your project uses MPI
#
#   EX:
#
#     list-mpi-programs-cpp = $(filter %MPI,$(programs_cpp))
#     list-mpi-objects-cpp = $(addsuffix $(o_ext),$(list-mpi-programs-cpp))
#
#   Note the use of *delayed* assignment (=), since programs_cpp has
#   not been populated yet when project.mk is included.

ifneq "$(strip $(list-mpi-programs-cpp))" ""
$(list-mpi-objects-cpp): CXX := $(MPICXX)
$(list-mpi-programs-cpp): CXX := $(MPICXX)
$(list-mpi-programs-cpp): CC := $(MPICXX)
endif

################################################################
# shorthand library/program/generated targets
################################################################
# allow target to be specified without qualifying path
#   e.g., "make libfoo" instead of "make libraries/foo/libfoo.a"
#
# Disable with MAKEFILE_STANDALONE flag if this makefile is being used
# for standalone compilation of a module ("modules += ."), since then
# it leads to circular dependencies.

ifndef MAKEFILE_STANDALONE

$(foreach target,$(libraries),$(eval .PHONY : $(notdir $(target))) )
$(foreach target,$(libraries),$(eval $(notdir $(target)) : $(addsuffix .a,$(target)) ))
$(foreach target,$(shared_libraries),$(eval $(notdir $(target)) : $(addsuffix .so,$(target)) ))

$(foreach target,$(programs),$(eval .PHONY : $(notdir $(target))) )
$(foreach target,$(programs),$(eval $(notdir $(target)) : $(target)) )

$(foreach target,$(programs_text),$(eval .PHONY : $(notdir $(target))) )
$(foreach target,$(programs_test),$(eval $(notdir $(target)) : $(target)) )

$(foreach target,$(generated),$(eval .PHONY : $(notdir $(target))) )
$(foreach target,$(generated),$(eval $(notdir $(target)) : $(target)) )

endif

################################################################
# diagnostic output target
################################################################

splash:
	@echo "makefile -- hybrid C++/FORTRAN project"
	@echo
	@echo "M. A. Caprio"
	@echo "University of Notre Dame"
	@echo
	@echo $(project_name) make information
	@echo
	@echo "Working directory:" $(PWD)
	@echo "Install prefix: " $(install_prefix)
	@echo
	@echo "Modules:" $(modules)
	@echo
	@echo "Libraries:" $(notdir $(libraries))
	@echo
	@echo $(library_journal)
	@echo
	@echo "Programs:" $(notdir $(programs))
	@echo
	@echo "Programs (test):" $(notdir $(programs_test))
	@echo
	@echo "Generated:" $(notdir $(generated))
	@echo
	@echo $(debug_output)
	@echo "To build the project, run \"make all\"."
	@echo "Or for further instructions, run \"make help\"."

################################################################
# help target
################################################################

.PHONY: help
help:
	@echo
	@echo "makefile -- hybrid C++/FORTRAN project                     "
	@echo "								  "
	@echo "M. A. Caprio                                               "
	@echo "University of Notre Dame	                                  "
	@echo "								  "
	@echo "Syntax:							  "
	@echo "  make <target>						  "
	@echo "								  "
	@echo "Targets:                                                   "
	@echo "  (none) -- a summary of the project is displayed          "
	@echo "  all  -- all libraries, programs, and generated files 	  "
	@echo "  libraries -- just the libraries                          "
	@echo "  programs -- just the programs                            "
	@echo "  programs-test -- just the test programs                  "
	@echo "  generated -- just the generated files (e.g., data files) "
	@echo "  distrib [tag=<version>] -- make source tarball		  "
	@echo "    Default tag is YYMMDD date.				  "
	@echo "  clean -- delete binaries and generated files		  "
	@echo "								  "
	@echo "  <library> -- shorthand for full path to library	  "
	@echo "    EX: Use shorthand target libmylib for xxxx/xxxx/libmylib.a. "
	@echo "  <program> -- shorthand for full path to program	  "
	@echo "    EX: Use shorthand target myprog for xxxx/xxxx/myprog.  "

# ending message

.PHONY: finished
finished:
# Displayed since otherwise it is confusing...  Otherwise, if make all
# is invoked with all targets already made, successful termination
# would leave us with the help message `To build the project, run
# "make all"', which looks like a failure, rather than an indication
# that the project was actually already successfully built.
	@echo "								  "
	@echo "Full-project build completed.                              "

################################################################
# general targets
################################################################

# Note: "all" excludes test codes
.PHONY: all
all: splash libraries programs generated finished

.PHONY: libraries
libraries: $(archives) $(shared_objects)

.PHONY: programs
programs: $(programs)

.PHONY: programs-test
programs-test: $(programs_test)

.PHONY: generated
generated: $(generated)

################################################################
# install
################################################################

install_dir_bin ?= $(install_prefix)/bin  # use ?= to allow project-specific override
install_dir_include := $(install_prefix)/include
install_dir_lib := $(install_prefix)/lib
MKDIR := mkdir -p

.PHONY: install-bin
install-bin: programs
	@echo Installing binaries to $(install_dir_bin)...
	$(MKDIR) $(install_dir_bin)
	install -D $(executables) --target-directory=$(install_dir_bin)

.PHONY: install-include
install-include: ${sources_h}
	@echo Installing includes to $(install_dir_include)...
	@echo WARNING: not yet supported
	$(MKDIR) $(install_dir_include)
	# TODO
##	install -D ${sources_h} --target-directory=$(install_dir_lib)
##	@ $(foreach source,$(sources_h),echo $(source); )

.PHONY: install-lib
install-lib: libraries
	@echo Installing libraries to $(install_dir_lib)...
	$(MKDIR) $(install_dir_lib)
	install -D $(archives) --target-directory=$(install_dir_lib) --mode=u=rw,go=r

.PHONY: install
##install: install_bin install_include install_lib
install: install-bin
	$(install_script)


################################################################
# source tarball
################################################################

# construct last name of current directory (e.g., "src")
pwd_tail := $(notdir $(CURDIR))

# construct tar filename

tag ?= $(shell date +%y%m%d)
tarball = $(project_name)-$(tag).tgz

# construct list of items to include in distribution
tar_constituents = $(sources) $(makefiles) $(extras)

# Rule for tarball
# To put in source directory instead of parent: $(pwd_tail)/$(tarball)

.PHONY: distrib
distrib:
	@ echo Making source tarball $(tarball)...
	@ cd ..; tar --dereference -zcvf $(tarball) $(addprefix $(pwd_tail)/,$(tar_constituents))
	@ ls -Fla ../$(tarball)

# Make alias "distribution"
.PHONY: distribution
distribution: distrib

################################################################
# cleanup
################################################################

.PHONY: clean
clean:
	$(RM) $(objects) $(objects_test) $(archives) $(shared_objects) $(executables) $(executables_test) $(generated)

.PHONY: distclean
distclean: clean
