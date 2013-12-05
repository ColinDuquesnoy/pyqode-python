## Debian Source Package Generator
#
# Copyright (c) 2010 Daniel Pfeifer <daniel@pfeifer-mail.de>
# Many modifications by Rosen Diankov <rosen.diankov@gmail.com>
#
# Creates source debian files and manages library dependencies
#
# Features:
#
# - Automatically generates symbols and run-time dependencies from the build dependencies
# - Custom copy of source directory via CPACK_DEBIAN_PACKAGE_SOURCE_COPY
# - Simultaneous output of multiple debian source packages for each distribution
# - Can specificy distribution-specific dependencies by suffixing DEPENDS with _${DISTRO_NAME}, for example: CPACK_DEBIAN_PACKAGE_DEPENDS_LUCID, CPACK_COMPONENT_MYCOMP0_DEPENDS_LUCID
#
# Usage:
#
# set(CPACK_DEBIAN_BUILD_DEPENDS debhelper cmake)
# set(CPACK_DEBIAN_PACKAGE_PRIORITY optional)
# set(CPACK_DEBIAN_PACKAGE_SECTION devel)
# set(CPACK_DEBIAN_CMAKE_OPTIONS "-DMYOPTION=myvalue")
# set(CPACK_DEBIAN_PACKAGE_DEPENDS mycomp0 mycomp1 some_ubuntu_package)
# set(CPACK_DEBIAN_PACKAGE_DEPENDS_UBUNTU_LUCID mycomp0 mycomp1 lucid_specific_package)
# set(CPACK_DEBIAN_PACKAGE_NAME mypackage)
# set(CPACK_DEBIAN_PACKAGE_REMOVE_SOURCE_FILES unnecessary_file unnecessary_dir/file0)
# set(CPACK_DEBIAN_PACKAGE_SOURCE_COPY svn export --force) # if using subversion
# set(CPACK_DEBIAN_DISTRIBUTION_NAME ubuntu)
# set(CPACK_DEBIAN_DISTRIBUTION_RELEASES karmic lucid maverick natty)
# set(CPACK_DEBIAN_CHANGELOG "  * Extra change log lines")
# set(CPACK_DEBIAN_PACKAGE_SUGGESTS "ipython")
# set(CPACK_COMPONENT_X_RECOMMENDS "recommended-package")
##

find_program(DEBUILD_EXECUTABLE debuild)
find_program(DPUT_EXECUTABLE dput)

if(NOT DEBUILD_EXECUTABLE OR NOT DPUT_EXECUTABLE)
  return()
endif(NOT DEBUILD_EXECUTABLE OR NOT DPUT_EXECUTABLE)

# DEBIAN/control
# debian policy enforce lower case for package name
# Package: (mandatory)
IF(NOT CPACK_DEBIAN_PACKAGE_NAME)
  STRING(TOLOWER "${CPACK_PACKAGE_NAME}" CPACK_DEBIAN_PACKAGE_NAME)
ENDIF(NOT CPACK_DEBIAN_PACKAGE_NAME)

# Section: (recommended)
IF(NOT CPACK_DEBIAN_PACKAGE_SECTION)
  SET(CPACK_DEBIAN_PACKAGE_SECTION "devel")
ENDIF(NOT CPACK_DEBIAN_PACKAGE_SECTION)

# Priority: (recommended)
IF(NOT CPACK_DEBIAN_PACKAGE_PRIORITY)
  SET(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
ENDIF(NOT CPACK_DEBIAN_PACKAGE_PRIORITY)

# file(STRINGS ${CPACK_PACKAGE_DESCRIPTION_FILE} DESC_LINES)
# foreach(LINE ${DESC_LINES})
#   set(DEB_LONG_DESCRIPTION "${DEB_LONG_DESCRIPTION} ${LINE}\n")
# endforeach(LINE ${DESC_LINES})

file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/Debian")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/Debian")
set(DEBIAN_SOURCE_ORIG_DIR "${CMAKE_BINARY_DIR}/Debian/${CPACK_DEBIAN_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}")

if( CPACK_DEBIAN_PACKAGE_SOURCE_COPY )
    execute_process(COMMAND ${PYTHON_EXECUTABLE} tools/copydebfiles.py
                    "${CMAKE_SOURCE_DIR}" "${DEBIAN_SOURCE_ORIG_DIR}.orig"
                    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
else()
  execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_SOURCE_DIR}/pyqode "${DEBIAN_SOURCE_ORIG_DIR}.orig")
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory "${DEBIAN_SOURCE_ORIG_DIR}.orig/.git")
  execute_process(COMMAND ${CMAKE_COMMAND} -E remove_directory "${DEBIAN_SOURCE_ORIG_DIR}.orig/.svn")
endif()

# remove unnecessary folders
foreach(REMOVE_DIR ${CPACK_DEBIAN_PACKAGE_REMOVE_SOURCE_FILES})
  file(REMOVE_RECURSE ${DEBIAN_SOURCE_ORIG_DIR}.orig/${REMOVE_DIR})
endforeach()

# create the original source tar
execute_process(COMMAND ${CMAKE_COMMAND} -E tar czf "${CPACK_DEBIAN_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}.orig.tar.gz" "${CPACK_DEBIAN_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}.orig" WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/Debian)

set(DEB_SOURCE_CHANGES)
foreach(RELEASE ${CPACK_DEBIAN_DISTRIBUTION_RELEASES})
  set(DEBIAN_SOURCE_DIR "${DEBIAN_SOURCE_ORIG_DIR}-${CPACK_DEBIAN_DISTRIBUTION_NAME}1~${RELEASE}1")
  set(RELEASE_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}-${CPACK_DEBIAN_DISTRIBUTION_NAME}1~${RELEASE}1")
  string(TOUPPER ${RELEASE} RELEASE_UPPER)
  string(TOUPPER ${CPACK_DEBIAN_DISTRIBUTION_NAME} DISTRIBUTION_NAME_UPPER)
  file(MAKE_DIRECTORY ${DEBIAN_SOURCE_DIR}/debian)
  ##############################################################################
  # debian/control
  set(DEBIAN_CONTROL ${DEBIAN_SOURCE_DIR}/debian/control)
  file(WRITE ${DEBIAN_CONTROL}
    "Source: ${CPACK_DEBIAN_PACKAGE_NAME}\n"
    "Section: ${CPACK_DEBIAN_PACKAGE_SECTION}\n"
    "Priority: ${CPACK_DEBIAN_PACKAGE_PRIORITY}\n"
    "DM-Upload-Allowed: yes\n"
    "Maintainer: ${CPACK_PACKAGE_CONTACT}\n"
    "Build-Depends: "
    )

  if( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    foreach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
      file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
    endforeach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
  else( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    if( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
    else( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_BUILD_DEPENDS})
    endif( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
  endif( CPACK_DEBIAN_BUILD_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )


  file(APPEND ${DEBIAN_CONTROL} "\n"
    "Standards-Version: 3.8.4\n"
    "Homepage: ${CPACK_PACKAGE_VENDOR}\n"
    "\n"
    "Package: ${CPACK_DEBIAN_PACKAGE_NAME}\n"
    "Architecture: any\n"
    "Pre-Depends: ${PREDEPENDS}\n"
    "Depends: "
    )

  if( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    foreach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
      file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
    endforeach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
  else( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    if( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
    else( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_DEPENDS})
    endif( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
  endif( CPACK_DEBIAN_PACKAGE_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

  file(APPEND ${DEBIAN_CONTROL} "\nRecommends: ")
  if( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    foreach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
      file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
    endforeach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
  else( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    if( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}})
    else( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_RECOMMENDS})
    endif( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
  endif( CPACK_DEBIAN_PACKAGE_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

  file(APPEND ${DEBIAN_CONTROL} "\nSuggests: ")
  if( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    foreach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
      file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
    endforeach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
  else( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
    if( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}})
    else( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
      foreach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS})
        file(APPEND ${DEBIAN_CONTROL} "${DEP}, ")
      endforeach(DEP ${CPACK_DEBIAN_PACKAGE_SUGGESTS})
    endif( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
  endif( CPACK_DEBIAN_PACKAGE_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

  file(APPEND ${DEBIAN_CONTROL} "\n"
    "Description: ${CPACK_PACKAGE_DESCRIPTION_SUMMARY} \n${DEB_LONG_DESCRIPTION}"
    )

  foreach(COMPONENT ${CPACK_COMPONENTS_ALL})
    string(TOUPPER ${COMPONENT} UPPER_COMPONENT)
    set(DEPENDS "\${shlibs:Depends}")
    if( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
        set(DEPENDS "${DEPENDS}, ${DEP}")
      endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
    else( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      if( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
          set(DEPENDS "${DEPENDS}, ${DEP}")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}})
      else( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS})
          set(DEPENDS "${DEPENDS}, ${DEP}")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS})
      endif( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER} )
    endif( CPACK_COMPONENT_${UPPER_COMPONENT}_DEPENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

    set(RECOMMENDS)
    if( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
        set(RECOMMENDS "${RECOMMENDS} ${DEP}, ")
      endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
    else( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      if( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}})
          set(RECOMMENDS "${RECOMMENDS} ${DEP}, ")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}})
      else( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS})
          set(RECOMMENDS "${RECOMMENDS} ${DEP}, ")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS})
      endif( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER} )
    endif( CPACK_COMPONENT_${UPPER_COMPONENT}_RECOMMENDS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

    set(SUGGESTS)
    if( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
        set(SUGGESTS "${SUGGESTS} ${DEP}, ")
      endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER}})
    else( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )
      if( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}})
          set(SUGGESTS "${SUGGESTS} ${DEP}, ")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}})
      else( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
        foreach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS})
          set(SUGGESTS "${SUGGESTS} ${DEP}, ")
        endforeach(DEP ${CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS})
      endif( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER} )
    endif( CPACK_COMPONENT_${UPPER_COMPONENT}_SUGGESTS_${DISTRIBUTION_NAME_UPPER}_${RELEASE_UPPER} )

    file(APPEND ${DEBIAN_CONTROL} "\n"
      "Package: ${COMPONENT}\n"
      "Architecture: any\n"
      "Depends: ${DEPENDS}\n"
      "Recommends: ${RECOMMENDS}\n"
      "Suggests: ${SUGGESTS}\n"
      "Description: ${CPACK_COMPONENT_${UPPER_COMPONENT}_DISPLAY_NAME}\n${DEB_LONG_DESCRIPTION}")
  endforeach(COMPONENT ${CPACK_COMPONENTS_ALL})

  ##############################################################################
  # debian/copyright
  set(DEBIAN_COPYRIGHT ${DEBIAN_SOURCE_DIR}/debian/copyright)
  execute_process(COMMAND ${CMAKE_COMMAND} -E
    copy ${CPACK_RESOURCE_FILE_LICENSE} ${DEBIAN_COPYRIGHT}
    )

  ##############################################################################
  # preinst
  set(preinst ${DEBIAN_SOURCE_DIR}/debian/preinst)
  file(WRITE  ${preinst}
       "sudo ${PIP} install jedi pep8 pyflakes"
      )
  execute_process(COMMAND chmod +x ${preinst})

  ##############################################################################
  # debian/rules
  set(DEBIAN_RULES ${DEBIAN_SOURCE_DIR}/debian/rules)
  file(WRITE ${DEBIAN_RULES}
    "#!/usr/bin/make -f\n"
    "\n"
    "BUILDDIR = build_dir\n"
    "\n"
    "build:\n"
    "	mkdir $(BUILDDIR)\n"
    "	cd $(BUILDDIR); cmake -DCMAKE_BUILD_TYPE=Release ${CPACK_DEBIAN_CMAKE_OPTIONS} ..\n"
    "	$(MAKE) -C $(BUILDDIR) preinstall\n"
    "	touch build\n"
    "\n"
    "binary: binary-indep binary-arch\n"
    "\n"
    "binary-indep: build\n"
    "\n"
    "binary-arch: build\n"
    "	cd $(BUILDDIR); cmake -DCOMPONENT=Unspecified -DCMAKE_INSTALL_PREFIX=../debian/tmp/usr -P cmake_install.cmake\n"
    "	mkdir -p debian/tmp/DEBIAN\n"
    "	cp $(BUILDDIR)/preinst debian/tmp/DEBIAN\n"
    "	dpkg-gensymbols -p${CPACK_DEBIAN_PACKAGE_NAME}\n"
    )

  foreach(COMPONENT ${CPACK_COMPONENTS_ALL})
    set(PATH debian/${COMPONENT})
    file(APPEND ${DEBIAN_RULES}
      "	cd $(BUILDDIR); cmake -DCOMPONENT=${COMPONENT} -DCMAKE_INSTALL_PREFIX=../${PATH}/usr -P cmake_install.cmake\n"
      "	mkdir -p ${PATH}/DEBIAN\n"
      "	dpkg-gensymbols -p${COMPONENT} -P${PATH}\n"
      )
  endforeach(COMPONENT ${CPACK_COMPONENTS_ALL})

  file(APPEND ${DEBIAN_RULES}
    "	dh_shlibdeps\n"
    "	dh_strip\n" # for reducing size
    "	dpkg-gencontrol -p${CPACK_DEBIAN_PACKAGE_NAME}\n"
    "	dpkg --build debian/tmp ..\n"
    )

  foreach(COMPONENT ${CPACK_COMPONENTS_ALL})
    set(PATH debian/${COMPONENT})
    file(APPEND ${DEBIAN_RULES}
      "	dpkg-gencontrol -p${COMPONENT} -P${PATH} -Tdebian/${COMPONENT}.substvars\n"
      "	dpkg --build ${PATH} ..\n"
      )
  endforeach(COMPONENT ${CPACK_COMPONENTS_ALL})

  file(APPEND ${DEBIAN_RULES}
    "\n"
    "clean:\n"
    "	rm -f build\n"
    "	rm -rf $(BUILDDIR)\n"
    "\n"
    ".PHONY: binary binary-arch binary-indep clean\n"
    )

  execute_process(COMMAND chmod +x ${DEBIAN_RULES})

  ##############################################################################
  # debian/compat
  file(WRITE ${DEBIAN_SOURCE_DIR}/debian/compat "7")

  ##############################################################################
  # debian/source/format
  file(WRITE ${DEBIAN_SOURCE_DIR}/debian/source/format "3.0 (quilt)")

  ##############################################################################
  # debian/changelog
  set(DEBIAN_CHANGELOG ${DEBIAN_SOURCE_DIR}/debian/changelog)
  execute_process(COMMAND date -R  OUTPUT_VARIABLE DATE_TIME)
  file(WRITE ${DEBIAN_CHANGELOG}
    "${CPACK_DEBIAN_PACKAGE_NAME} (${RELEASE_PACKAGE_VERSION}) ${RELEASE}; urgency=medium\n\n"
    "${CPACK_DEBIAN_CHANGELOG}"
    " -- ${CPACK_PACKAGE_CONTACT}  ${DATE_TIME}"
    )

  ##############################################################################
  # debuild -S
  if( DEB_SOURCE_CHANGES )
    set(DEBUILD_OPTIONS "-sd")
  else()
    set(DEBUILD_OPTIONS "-sa")
  endif()
  set(SOURCE_CHANGES_FILE "${CPACK_DEBIAN_PACKAGE_NAME}_${RELEASE_PACKAGE_VERSION}_source.changes")
  set(DEB_SOURCE_CHANGES ${DEB_SOURCE_CHANGES} "${SOURCE_CHANGES_FILE}")
  add_custom_command(OUTPUT "${SOURCE_CHANGES_FILE}" COMMAND ${DEBUILD_EXECUTABLE} -S ${DEBUILD_OPTIONS} WORKING_DIRECTORY ${DEBIAN_SOURCE_DIR})
endforeach(RELEASE ${CPACK_DEBIAN_DISTRIBUTION_RELEASES})

##############################################################################
# dput ppa:your-lp-id/ppa <source.changes>
add_custom_target(dput ${DPUT_EXECUTABLE} ${DPUT_HOST} ${DEB_SOURCE_CHANGES} DEPENDS ${DEB_SOURCE_CHANGES} WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/Debian)
