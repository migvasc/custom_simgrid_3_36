##
## The Cmake definitions for the use of Java
##   This file is loaded only if the Java option is activated
##

find_package(Java 1.8 COMPONENTS Runtime Development)
if (NOT ${Java_FOUND})
  message(FATAL_ERROR "Java not found (need at least Java 8). Please install the JDK, or disable the 'enable_java' option.")
endif()
message(STATUS "[Java] Compiler: ${Java_JAVAC_EXECUTABLE}; Runtime: ${Java_JAVA_EXECUTABLE}; Version: ${Java_VERSION_STRING}")

find_package(SWIG)
if (NOT ${SWIG_FOUND})
  message(FATAL_ERROR "SWIG not found. Please install it, or disable the 'enable_java' option.")
endif()
cmake_policy(SET CMP0078 NEW)
cmake_policy(SET CMP0086 NEW)
include(UseSWIG)

find_package(JNI)
if (NOT ${JNI_FOUND})
  message(FATAL_ERROR "JNI not found. Please install it, or disable the 'enable_java' option.")
endif()
message(STATUS "[Java] JNI include dirs: ${JNI_INCLUDE_DIRS}")

set(Java_FOUND 1)
#include(${CMAKE_SOURCE_DIR}/tools/cmake/UseJava-patched.cmake)
include(UseJava)

# Generate the bindings with SWIG
#################################
SET_SOURCE_FILES_PROPERTIES(src/bindings/swig/simgrid-java.i PROPERTIES CPLUSPLUS 1)
SET_SOURCE_FILES_PROPERTIES(src/bindings/swig/simgrid-java.i PROPERTIES SWIG_FLAGS "-package;org.simgrid.s4u")
swig_add_library(simgrid-java
                 TYPE SHARED
                 LANGUAGE java
                 OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/src/org/simgrid/s4u
                 SOURCES src/bindings/swig/simgrid-java.i ${SIMGRID_JAVA_C_SOURCES})
swig_link_libraries(simgrid-java simgrid)
set(SWIG_USE_SWIG_DEPENDENCIES TRUE)
set_property(TARGET simgrid-java
             APPEND PROPERTY INCLUDE_DIRECTORIES ${JNI_INCLUDE_DIRS})

# Rules to build libsimgrid-java
################################

set_target_properties(simgrid-java PROPERTIES VERSION ${libsimgrid-java_version})
set_target_properties(simgrid-java PROPERTIES SKIP_BUILD_RPATH ON)
set_property(TARGET simgrid-java
             APPEND PROPERTY INCLUDE_DIRECTORIES "${INTERNAL_INCLUDES}")             

target_link_libraries(simgrid-java simgrid)
add_dependencies(tests simgrid-java)

get_target_property(COMMON_INCLUDES simgrid-java INCLUDE_DIRECTORIES)
if (COMMON_INCLUDES)
  set_target_properties(simgrid-java PROPERTIES  INCLUDE_DIRECTORIES "${COMMON_INCLUDES};${JNI_INCLUDE_DIRS}")
else()
  set_target_properties(simgrid-java PROPERTIES  INCLUDE_DIRECTORIES "${JNI_INCLUDE_DIRS}")
endif()

get_target_property(CHECK_INCLUDES simgrid-java INCLUDE_DIRECTORIES)
message(STATUS "[Java] simgrid-java includes: ${CHECK_INCLUDES}")

# Rules to build simgrid.jar
############################

## Files to include in simgrid.jar
## 
set(SIMGRID_JAR "${CMAKE_BINARY_DIR}/simgrid.jar")
set(MANIFEST_IN_FILE "${CMAKE_HOME_DIRECTORY}/src/bindings/java/MANIFEST.in")
set(MANIFEST_FILE "${CMAKE_BINARY_DIR}/src/bindings/java/MANIFEST.MF")

set(LIBSIMGRID_SO       libsimgrid${CMAKE_SHARED_LIBRARY_SUFFIX})
set(LIBSIMGRID_JAVA_SO  ${CMAKE_SHARED_LIBRARY_PREFIX}simgrid-java${CMAKE_SHARED_LIBRARY_SUFFIX})

## Build simgrid.jar. We cannot use add_jar to compile most of our sources as they are generated. They are added later
##
add_jar(simgrid_jar
        SOURCES ${SIMGRID_JAVA_JAVA_SOURCES}
        OUTPUT_NAME simgrid)

# Add the classes of the generated sources later, as they do not exist at configure time when add_jar computes its arguments
ADD_CUSTOM_COMMAND(TARGET simgrid_jar 
        POST_BUILD
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND mkdir -p org/simgrid/s4u
        COMMAND ${Java_JAVAC_EXECUTABLE} src/org/simgrid/s4u/*java -s org/simgrid/s4u 
        COMMAND ${CMAKE_COMMAND} -E copy src/org/simgrid/s4u/*class org/simgrid/s4u
        COMMAND ${JAVA_ARCHIVE} -uvf ${SIMGRID_JAR} org
)

if(enable_lib_in_jar)
  add_dependencies(simgrid_jar simgrid-java)
  add_dependencies(simgrid_jar simgrid)
endif()

if (enable_documentation)
  add_custom_command(
    TARGET simgrid_jar POST_BUILD
    COMMENT "Add the documentation into simgrid.jar..."
    DEPENDS ${MANIFEST_IN_FILE}
            ${CMAKE_HOME_DIRECTORY}/COPYING
            ${CMAKE_HOME_DIRECTORY}/ChangeLog
            ${CMAKE_HOME_DIRECTORY}/NEWS
            ${CMAKE_HOME_DIRECTORY}/LICENSE-LGPL-2.1

    COMMAND ${CMAKE_COMMAND} -E copy ${MANIFEST_IN_FILE} ${MANIFEST_FILE}
    COMMAND ${CMAKE_COMMAND} -E echo "Specification-Version: \\\"${SIMGRID_VERSION_MAJOR}.${SIMGRID_VERSION_MINOR}.${SIMGRID_VERSION_PATCH}\\\"" >> ${MANIFEST_FILE}
    COMMAND ${CMAKE_COMMAND} -E echo "Implementation-Version: \\\"${GIT_VERSION}\\\"" >> ${MANIFEST_FILE}

    COMMAND ${Java_JAVADOC_EXECUTABLE} -quiet -d doc/javadoc -sourcepath ${CMAKE_HOME_DIRECTORY}/src/bindings/java/ org.simgrid.msg org.simgrid.trace

    COMMAND ${JAVA_ARCHIVE} -uvmf ${MANIFEST_FILE} ${SIMGRID_JAR} doc/javadoc
    COMMAND ${JAVA_ARCHIVE} -uvf  ${SIMGRID_JAR} -C ${CMAKE_HOME_DIRECTORY} COPYING -C ${CMAKE_HOME_DIRECTORY} ChangeLog -C ${CMAKE_HOME_DIRECTORY} LICENSE-LGPL-2.1 -C ${CMAKE_HOME_DIRECTORY} NEWS
  )
endif()

###
### Pack the java libraries into the jarfile if asked to do so
###

if(enable_lib_in_jar)
  set(SG_SYSTEM_NAME ${CMAKE_SYSTEM_NAME})

  if(${SG_SYSTEM_NAME} MATCHES "kFreeBSD")
    set(SG_SYSTEM_NAME GNU/kFreeBSD)
  endif()

  set(JAVA_NATIVE_PATH NATIVE/${SG_SYSTEM_NAME}/${CMAKE_SYSTEM_PROCESSOR})
  if( (${CMAKE_SYSTEM_PROCESSOR} MATCHES "^i[3-6]86$") OR
      (${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64") OR
      (${CMAKE_SYSTEM_PROCESSOR} MATCHES "AMD64") )
    if(CMAKE_SIZEOF_VOID_P EQUAL 4) # 32 bits
      set(JAVA_NATIVE_PATH NATIVE/${SG_SYSTEM_NAME}/x86)
    else()
      set(JAVA_NATIVE_PATH NATIVE/${SG_SYSTEM_NAME}/amd64)
    endif()
  endif()
  if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "armv7l")
    set(JAVA_NATIVE_PATH NATIVE/${SG_SYSTEM_NAME}/arm) # Default arm (soft-float ABI)
  endif()

  add_custom_command(
    TARGET simgrid_jar POST_BUILD
    COMMENT "Add the native libs into simgrid.jar..."
    DEPENDS simgrid simgrid-java ${JAVALIBS}

    COMMAND ${CMAKE_COMMAND} -E make_directory   ${JAVA_NATIVE_PATH}

    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_SO}      ${JAVA_NATIVE_PATH}/${LIBSIMGRID_SO}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different ${CMAKE_BINARY_DIR}/lib/${LIBSIMGRID_JAVA_SO} ${JAVA_NATIVE_PATH}/${LIBSIMGRID_JAVA_SO}
    )

if(APPLE)
  add_custom_command(
    TARGET simgrid_jar POST_BUILD
    COMMENT "Add the apple-specific native libs into simgrid.jar..."
    DEPENDS simgrid simgrid-java ${JAVALIBS}

    # We need to fix the rpath of the simgrid-java library so that it
    #    searches the simgrid library in the right location
    #
    # Since we don't officially install the lib before copying it in
    # the jarfile, the lib is searched for where it was built. Given
    # how we unpack it, we need to instruct simgrid-java to forget
    # about the build path, and search in its current directory
    # instead.
    #
    # This has to be done with the classical Apple tools, as follows:

    COMMAND install_name_tool -change ${CMAKE_BINARY_DIR}/lib/libsimgrid.${SIMGRID_VERSION_MAJOR}.${SIMGRID_VERSION_MINOR}${CMAKE_SHARED_LIBRARY_SUFFIX} @loader_path/libsimgrid.dylib ${JAVA_NATIVE_PATH}/${LIBSIMGRID_JAVA_SO}
  )
endif(APPLE)

  add_custom_command(
    TARGET simgrid_jar POST_BUILD
    COMMENT "Packing back the simgrid.jar with the native libs (turn lib_in_jar off when coding in java)..."
    DEPENDS simgrid simgrid-java ${JAVALIBS}

    COMMAND ${JAVA_ARCHIVE} -uvf ${SIMGRID_JAR}  ${JAVA_NATIVE_PATH}

    COMMAND ${CMAKE_COMMAND} -E echo "-- CMake puts the native code in ${JAVA_NATIVE_PATH}"
    COMMAND "${Java_JAVA_EXECUTABLE}" -classpath "${SIMGRID_JAR}" org.simgrid.NativeLib
  )
endif(enable_lib_in_jar)

add_dependencies(tests simgrid_jar)

include_directories(${JNI_INCLUDE_DIRS} ${JAVA_INCLUDE_PATH} ${JAVA_INCLUDE_PATH2})
