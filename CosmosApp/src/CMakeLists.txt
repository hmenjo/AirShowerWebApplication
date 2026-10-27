### CMake project file for Example
cmake_minimum_required (VERSION 3.5)

### set SHOWERMCTOP
set (SHOWERMCTOP $ENV{SHOWERMCTOP})
if (NOT SHOWERMCTOP)
  message(FATAL_ERROR "$SHOWERMCTOP is not defined")
endif (NOT SHOWERMCTOP)

### set COSMOSTOP AND COSMOSINC
set (COSMOSTOP $ENV{COSMOSTOP})
if (NOT COSMOSTOP)
  message(FATAL_ERROR "$COSMOSTOP is not defined")
endif (NOT COSMOSTOP)
set (COSMOSINC ${COSMOSTOP}/cosmos)

### set LIBLOFT AND LIBLOFTINC
set (LIBLOFT $ENV{LIBLOFT})
if (NOT LIBLOFT)
  message(FATAL_ERROR "$LIBLOFT is not defined")
endif (NOT LIBLOFT)
set (LIBLOFTINC ${LIBLOFT}/Header)

set (CMAKE_MODULE_PATH "${SHOWERMCTOP}/CMakeModules" ${CMAKE_MODULE_PATH})

### set default compiler as intel compiler for MPI if exist
if(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_Fortran_COMPILER NAMES mpiifort DOC "Fortran compiler")
  if(CMAKE_Fortran_COMPILER)
    message(STATUS "Intel Fortran Compiler ${CMAKE_Fortran_COMPILER} is found")
  endif(CMAKE_Fortran_COMPILER)
endif(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)
if(NOT CMAKE_C_COMPILER AND NOT CMAKE_C_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_C_COMPILER NAMES mpiicc DOC "C compiler")
  if(CMAKE_C_COMPILER)
    message(STATUS "Intel C Compiler ${CMAKE_C_COMPILER} is found")
  endif(CMAKE_C_COMPILER)
endif(NOT CMAKE_C_COMPILER AND NOT CMAKE_C_COMPILER_INIT)
if(NOT CMAKE_CXX_COMPILER AND NOT CMAKE_CXX_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_CXX_COMPILER NAMES mpiicpc DOC "CXX compiler")
  if(CMAKE_CXX_COMPILER)
    message(STATUS "Intel CXX Compiler ${CMAKE_CXX_COMPILER} is found")
  endif(CMAKE_CXX_COMPILER)
endif(NOT CMAKE_CXX_COMPILER AND NOT CMAKE_CXX_COMPILER_INIT)

### set default compiler as intel compiler if exist
if(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_Fortran_COMPILER NAMES ifort DOC "Fortran compiler")
  if(CMAKE_Fortran_COMPILER)
    message(STATUS "Intel Fortran Compiler ${CMAKE_Fortran_COMPILER} is found")
  endif(CMAKE_Fortran_COMPILER)
endif(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)
if(NOT CMAKE_C_COMPILER AND NOT CMAKE_C_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_C_COMPILER NAMES icc DOC "C compiler")
  if(CMAKE_C_COMPILER)
    message(STATUS "Intel C Compiler ${CMAKE_C_COMPILER} is found")
  endif(CMAKE_C_COMPILER)
endif(NOT CMAKE_C_COMPILER AND NOT CMAKE_C_COMPILER_INIT)
if(NOT CMAKE_CXX_COMPILER AND NOT CMAKE_CXX_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_CXX_COMPILER NAMES icpc DOC "CXX compiler")
  if(CMAKE_CXX_COMPILER)
    message(STATUS "Intel CXX Compiler ${CMAKE_CXX_COMPILER} is found")
  endif(CMAKE_CXX_COMPILER)
endif(NOT CMAKE_CXX_COMPILER AND NOT CMAKE_CXX_COMPILER_INIT)

### set default compiler as llvm Fortran compiler if exist
if(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)
  FIND_PROGRAM(CMAKE_Fortran_COMPILER NAMES flang DOC "Fortran compiler")
  if(CMAKE_Fortran_COMPILER)
    message(STATUS "LLVM Fortran Compiler ${CMAKE_Fortran_COMPILER} is found")
    FIND_PROGRAM(CMAKE_C_COMPILER NAMES clang DOC "C compiler")
    if(CMAKE_C_COMPILER)
      message(STATUS "LLVM C Compiler ${CMAKE_C_COMPILER} is found")
    endif(CMAKE_C_COMPILER)
    FIND_PROGRAM(CMAKE_CXX_COMPILER NAMES clang++ DOC "CXX compiler")
    if(CMAKE_CXX_COMPILER)
      message(STATUS "LLVM CXX Compiler ${CMAKE_CXX_COMPILER} is found")
    endif(CMAKE_CXX_COMPILER)
  endif(CMAKE_Fortran_COMPILER)
endif(NOT CMAKE_Fortran_COMPILER AND NOT CMAKE_Fortran_COMPILER_INIT)


### set project name
project (Example)
enable_language (Fortran)
enable_language (C)


### make sure that the default is a RELEASE
if (NOT CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE RELEASE CACHE STRING
    "Choose the type of build, options are: None Debug Release."
    FORCE)
endif (NOT CMAKE_BUILD_TYPE)


### default installation
get_filename_component (default_prefix ".." ABSOLUTE)
set (CMAKE_INSTALL_PREFIX ${default_prefix} CACHE STRING
  "Choose the installation directory; by default it installs in the COSMOS directory."
  FORCE)


### FFLAGS depend on the compiler
get_filename_component (Fortran_COMPILER_NAME ${CMAKE_Fortran_COMPILER} NAME)


### set compile option
set (Fortran_FLAGS_COMMON "${CMAKE_FORTRAN_FLAGS} -cpp")
set (Fortran_FLAGS_GFORT "${Fortran_FLAGS_COMMON} -fno-align-commons -fdec-structure")
set (Fortran_FLAGS_INTEL "${Fortran_FLAGS_COMMON} -traceback -warn noalign -diag-disable=remark -align dcommons")
set (Fortran_FLAGS_MPI   "${Fortran_FLAGS_COMMON} -traceback -warn noalign -diag-disable=remark -align array64byte")
set (Fortran_FLAGS_LLVM  "${Fortran_FLAGS_COMMON}")

if (Fortran_COMPILER_NAME MATCHES "gfortran.*")
  # gfortran
  set (ARCH LinuxGfort)
  set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_GFORT} -O3 -D${ARCH}")
  set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_GFORT} -O0 -D${ARCH} -g -fcheck=all")
  set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -D${ARCH}")
  set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -D${ARCH} -g -fcheck=all")
elseif (Fortran_COMPILER_NAME MATCHES "flang.*")
  set (ARCH LLVM)
  set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_LLVM} -O3 -DLinuxGfort -D${ARCH}")
  set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_LLVM} -O0 -DLinuxGfort -D${ARCH} -g -fsanitize=address,memory,undefined,safe-stack")
  set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -DLinuxGfort -D${ARCH}")
  set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -DLinuxGfort -D${ARCH} -g")
elseif (Fortran_COMPILER_NAME MATCHES "mpiifort.*")
  # mpiifort
  set (ARCH MPIIFC64)
  set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_MPI} -O3 -D${ARCH} -DDOMPI")
  set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_MPI} -O0 -D${ARCH} -DDOMPI -g ")
  set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -D${ARCH}")
  set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -D${ARCH} -g")
elseif (Fortran_COMPILER_NAME MATCHES "ifort.*")
  # ifort
  find_program(MPIEXEC mpiexec_mpt)
  if (MPIEXEC)
    set (ARCH MPTIFC64)
    set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_INTEL} -O3 -D${ARCH} -DDOMPI")
    set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_INTEL} -O0 -D${ARCH} -DDOMPI -g ")
    set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -D${ARCH}")
    set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -D${ARCH} -g")
  else (MPIEXEC)
    set (ARCH PCLinuxIFC64)
    set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_INTEL} -O3 -D${ARCH}")
    set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_INTEL} -O0 -D${ARCH} -g -check all")
    set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -D${ARCH}")
    set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -D${ARCH} -g")
  endif (MPIEXEC)
elseif (Fortran_COMPILER_NAME MATCHES "ifx.*")
  set(ARCH LinuxIFX)
  set (CMAKE_Fortran_FLAGS_RELEASE "${Fortran_FLAGS_INTEL} -O3 -D${ARCH}")
  set (CMAKE_Fortran_FLAGS_DEBUG   "${Fortran_FLAGS_INTEL} -O0 -D${ARCH} -g -check all")
  set (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O3 -D${ARCH}")
  set (CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS} -O0 -D${ARCH} -g")
else (Fortran_COMPILER_NAME MATCHES "gfortran.*")
  message ("CMAKE_Fortran_COMPILER full path: " ${CMAKE_Fortran_COMPILER})
  message ("Fortran compiler: " ${Fortran_COMPILER_NAME})
  message ("No optimized Fortran compiler flags are known, we just try -O2...")
  set (CMAKE_Fortran_FLAGS_RELEASE "${CMAKE_FORTRAN_FLAGS} -O2")
  set (CMAKE_Fortran_FLAGS_DEBUG   "${CMAKE_FORTRAN_FLAGS} -O0 -g")
endif (Fortran_COMPILER_NAME MATCHES "gfortran.*")

if (APPLE)
  include(GetXcodeVersion)
  GET_XCODE_VERSION()
  message(STATUS "Xcode ver. ${XCODE_VERSION} found.")
  if (${XCODE_VERSION} GREATER 14.9)
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -ld_classic")
  endif()
endif(APPLE)

### dump variables
message (STATUS "Fortran compiler: " ${CMAKE_Fortran_COMPILER})
message (STATUS "C compiler: " ${CMAKE_C_COMPILER})
message (STATUS "C++ compiler: " ${CMAKE_CXX_COMPILER})
message (STATUS "$SHOWERMCTOP is ${SHOWERMCTOP}")
message (STATUS "$LIBLOFT is ${LIBLOFT}")
message (STATUS "$COSMOSTOP is ${COSMOSTOP}")
message (STATUS "$ARCH is ${ARCH}")


set(CMAKE_INCLUDE_CURRENT_DIR ON) 
include_directories(${LIBLOFTINC})
include_directories(${LIBLOFTINC}/BlockData)
include_directories(${COSMOSINC})

### HDF5: one file per event, compound datasets for interactions and obs planes
find_package(PkgConfig REQUIRED)
pkg_check_modules(HDF5_FORTRAN REQUIRED hdf5_fortran)
pkg_check_modules(HDF5_HL REQUIRED hdf5_hl)

set (CMAKE_Fortran_MODULE_DIRECTORY "${SHOWERMCTOP}/lib/${ARCH}")
set (CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${SHOWERMCTOP}/lib/${ARCH}")
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY "${SHOWERMCTOP}/lib/${ARCH}")
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")
set (LIBSHOWERMC showermc)
link_directories("${SHOWERMCTOP}/lib/${ARCH}")

# cmovePtcl copies one projectile track onto every product, so the
# product index cannot be stored from chookNEPInt. Number each child
# in cpush. The library cpush is renamed cpshx in this object; cosmosX
# sources are left unchanged.
set(CSTACK_SRC "${SHOWERMCTOP}/lib/${ARCH}/libshowermc.a")
set(CSTACK_PATCHED "${CMAKE_BINARY_DIR}/cstack_secindex.o")
add_custom_command(
  OUTPUT "${CSTACK_PATCHED}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_BINARY_DIR}/cstack_extract"
  COMMAND ${CMAKE_COMMAND} -E chdir "${CMAKE_BINARY_DIR}/cstack_extract"
          ar x "${CSTACK_SRC}" cstack.f.o
  COMMAND python3 -c
"import pathlib,sys; src,dst=map(pathlib.Path,sys.argv[1:]); data=src.read_bytes(); old,new=b'_cpush_',b'_cpshx_'; n=data.count(old); assert n==1, n; dst.write_bytes(data.replace(old,new,1))"
          "${CMAKE_BINARY_DIR}/cstack_extract/cstack.f.o" "${CSTACK_PATCHED}"
  DEPENDS "${CSTACK_SRC}"
  VERBATIM
)
add_custom_target(cstack_secindex DEPENDS "${CSTACK_PATCHED}")

add_executable(cosmos${ARCH} chook_hdf5.f90 chook.f)
add_dependencies(cosmos${ARCH} cstack_secindex)
target_include_directories(cosmos${ARCH} PRIVATE ${HDF5_FORTRAN_INCLUDE_DIRS})
target_link_directories(cosmos${ARCH} PRIVATE
  ${HDF5_FORTRAN_LIBRARY_DIRS} ${HDF5_HL_LIBRARY_DIRS})
target_link_libraries(cosmos${ARCH} "${CSTACK_PATCHED}" ${LIBSHOWERMC}
  ${HDF5_FORTRAN_LIBRARIES} ${HDF5_HL_LIBRARIES})
if(HDF5_FORTRAN_LIBRARY_DIRS)
  set_target_properties(cosmos${ARCH} PROPERTIES
    BUILD_RPATH "${HDF5_FORTRAN_LIBRARY_DIRS}"
    INSTALL_RPATH "${HDF5_FORTRAN_LIBRARY_DIRS}")
endif()
