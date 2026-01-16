
add_library(ProjectM-Uber MODULE
    macos/iTunesAPI.cpp
    macos/iTunesAPI.h
    macos/iTunesVisualAPI.h
    getConfigFilename.cpp
    getConfigFilename.h
    iprojectM.hpp
    iprojectM.mm
    iprojectM_mac.mm
    )

set_target_properties(ProjectM-Uber PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Resources/ProjectM-plugin-info.plist"
    BUILD_RPATH "/usr/local/lib"
    INSTALL_RPATH "/usr/local/lib"
    )

target_link_libraries(ProjectM-Uber
    PRIVATE
    "-framework Cocoa"
    "-framework AppKit"
    "-framework CoreData"
    "-framework Foundation"
    "-framework QuartzCore"
    libprojectM::projectM
    libprojectM::playlist
    )
