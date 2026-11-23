# Note for maintainers
# --------------------
#
# Do not use absolute paths in DESTINATION arguments for install() command.
# Because the same install code will be executed again by CPack. And CPack will
# change internally CMAKE_INSTALL_PREFIX to point to some temporary folder
# for package content.
#
#


# Temporary change
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install"
    CACHE STRING "Install path prefix, prepended onto install directories"
    FORCE)

if(SYSTEM_LINUX)
    set(bin_dir             bin)
    set(lib_dir             lib)
    set(resources_dir       share)
    set(license_dir         .)

    set(qt_plugins_dir      ${lib_dir})
    set(qt_conf_dir         ${bin_dir})
    set(qt_conf_plugins     "../lib")
elseif(SYSTEM_MACOSX)
    set(bundle_name         "Robo 3T.app")
    set(contents_path       ${bundle_name}/Contents)

    set(bin_dir             ${contents_path}/MacOS)
    set(styles_dir          ${contents_path}/MacOS/styles)
    set(lib_dir             ${contents_path}/Frameworks)
    set(resources_dir       ${contents_path}/Resources)
    set(license_dir         ${resources_dir})

    set(qt_plugins_dir      ${contents_path}/PlugIns/Qt)
    set(qt_conf_dir         ${resources_dir})
    set(qt_conf_plugins     "PlugIns/Qt")
elseif(SYSTEM_WINDOWS)
    set(bin_dir             .)
    set(styles_dir          ${bin_dir}/styles)
    set(lib_dir             .)
    set(resources_dir       ./resources)
    set(license_dir         .)

    set(qt_plugins_dir      ${lib_dir})
    set(qt_conf_dir         ${bin_dir})
    set(qt_conf_plugins     .)
endif()

# Generate qt.conf file
configure_file(
    "${CMAKE_SOURCE_DIR}/install/qt.conf.in"
    "${CMAKE_BINARY_DIR}/qt.conf")

# Install qt.conf file
install(
    FILES       "${CMAKE_BINARY_DIR}/qt.conf"
    DESTINATION "${qt_conf_dir}")

# Install OpenSSL dynamic lib files
if(SYSTEM_WINDOWS)
    install(
        FILES 
        "${OpenSSL_DIR}/libssl-1_1-x64.dll"
        "${OpenSSL_DIR}/libcrypto-1_1-x64.dll"
        DESTINATION ${bin_dir})
elseif(SYSTEM_MACOSX)
    if(OPENSSL_VERSION VERSION_GREATER_EQUAL "3.0.0")
        set(OPENSSL_SSL_NAME "libssl.3.dylib")
        set(OPENSSL_CRYPTO_NAME "libcrypto.3.dylib")
    else()
        set(OPENSSL_SSL_NAME "libssl.1.1.dylib")
        set(OPENSSL_CRYPTO_NAME "libcrypto.1.1.dylib")
    endif()
    get_filename_component(OPENSSL_LIB_DIR "${OPENSSL_SSL_LIBRARY}" DIRECTORY)
    install(
        FILES 
        "${OPENSSL_LIB_DIR}/${OPENSSL_SSL_NAME}"
        "${OPENSSL_LIB_DIR}/${OPENSSL_CRYPTO_NAME}"
        DESTINATION ${lib_dir})
elseif(SYSTEM_LINUX)
    install(
        FILES 
        "${OpenSSL_DIR}/libssl.so"
        "${OpenSSL_DIR}/libssl.so.1.0.0"        
        "${OpenSSL_DIR}/libcrypto.so"        
        "${OpenSSL_DIR}/libcrypto.so.1.0.0"
        DESTINATION ${lib_dir})         
endif()

# Install binary
install(
    TARGETS robomongo
    RUNTIME DESTINATION ${bin_dir}
    BUNDLE DESTINATION .)

# Install license, copyright and changelogs files
install(
    FILES
        ${CMAKE_SOURCE_DIR}/LICENSE
        ${CMAKE_SOURCE_DIR}/COPYRIGHT
        ${CMAKE_SOURCE_DIR}/CHANGELOG
        ${CMAKE_SOURCE_DIR}/DESCRIPTION
    DESTINATION ${license_dir})

# Install common dependencies
if(NOT SYSTEM_MACOSX)
    SET(QT_LIBS Core Gui Widgets PrintSupport Network Xml)
    if(NOT SYSTEM_LINUX AND NOT DISABLE_WEBENGINE)
        SET(QT_LIBS ${QT_LIBS} WebEngineWidgets WebEngineCore Quick 
                               QuickWidgets WebChannel Qml Positioning)
    endif()
    install_qt_lib(${QT_LIBS})
    install_qt_plugins(QGifPlugin QICOPlugin)
    install_icu_libs()
endif()
set(QT_STYLES_DIR ${Qt5Core_DIR}/../../../plugins/styles/)
set(QT_BIN_DIR ${Qt5Core_DIR}/../../../bin/)
set(QT_RESOURCES_DIR ${Qt5Core_DIR}/../../../resources/)

if(SYSTEM_LINUX)
    install_qt_lib(XcbQpa DBus)
    install_qt_plugins(
        QXcbIntegrationPlugin)
        
    install(
        FILES
            "/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
            "/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.28"              
        DESTINATION ${lib_dir})
elseif(SYSTEM_MACOSX)
    # Install icon
    install(
        FILES       "${CMAKE_SOURCE_DIR}/install/macosx/robomongo.icns"
        DESTINATION "${resources_dir}")


    # Code signing identity: "-" = ad-hoc (local use only). For distribution pass a Developer ID,
    # e.g. -DCODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" - the hardened runtime is
    # then enabled as required for notarization (xcrun notarytool submit ...).
    set(CODESIGN_IDENTITY "-" CACHE STRING "macOS code signing identity (\"-\" for ad-hoc)")
    if(CODESIGN_IDENTITY STREQUAL "-")
        set(CODESIGN_EXTRA_OPTIONS "")
    else()
        set(CODESIGN_EXTRA_OPTIONS --options runtime --timestamp)
    endif()

    # Run macdeployqt on the bundle to copy dynamic libraries and rewrite library paths for portability
    find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${QT_BIN_DIR}")
    if(MACDEPLOYQT_EXECUTABLE)
        install(CODE "
            message(STATUS \"Running macdeployqt on the bundle: \${CMAKE_INSTALL_PREFIX}/Robo 3T.app\")
            execute_process(
                COMMAND \"${MACDEPLOYQT_EXECUTABLE}\" \"\${CMAKE_INSTALL_PREFIX}/Robo 3T.app\" -verbose=1
                RESULT_VARIABLE MACDEPLOYQT_RESULT
            )
            if(NOT MACDEPLOYQT_RESULT EQUAL 0)
                message(FATAL_ERROR \"macdeployqt failed with exit code \${MACDEPLOYQT_RESULT}\")
            endif()
            message(STATUS \"Re-signing the bundle to fix code signature: \${CMAKE_INSTALL_PREFIX}/Robo 3T.app\")
            execute_process(
                COMMAND codesign --force --deep ${CODESIGN_EXTRA_OPTIONS} --sign \"${CODESIGN_IDENTITY}\" \"\${CMAKE_INSTALL_PREFIX}/Robo 3T.app\"
                RESULT_VARIABLE CODESIGN_RESULT
            )
            if(NOT CODESIGN_RESULT EQUAL 0)
                message(FATAL_ERROR \"codesign failed with exit code \${CODESIGN_RESULT}\")
            endif()
        ")
    endif()
elseif(SYSTEM_WINDOWS)
    install_qt_plugins(
        QWindowsIntegrationPlugin
        QMinimalIntegrationPlugin
        QOffscreenIntegrationPlugin)

    # Qt WebEngine dependencies
    install(DIRECTORY ${QT_RESOURCES_DIR} DESTINATION ${resources_dir})
    install(FILES 
                "${QT_BIN_DIR}/libEGL.dll"
                "${QT_BIN_DIR}/libGLESv2.dll" 
                "${QT_BIN_DIR}/opengl32sw.dll" 
                "${QT_BIN_DIR}/QtWebEngineProcess.exe" 
            DESTINATION ${bin_dir})

    # Install Styles
    install(FILES "${QT_STYLES_DIR}/qwindowsvistastyle.dll" DESTINATION ${styles_dir})

    # Install runtime libraries:
    # msvcp120.dll
    # msvcr120.dll
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION .)
    include(InstallRequiredSystemLibraries)
endif()
