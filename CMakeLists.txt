cmake_minimum_required(VERSION 3.16)

project(PushClone VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# By default, we use Qt6. For Raspberry Pi, build with -DUSE_QT6=OFF
option(USE_QT6 "Use Qt6 instead of Qt5" ON)

if(USE_QT6)
    message(STATUS "Building with Qt6")
    find_package(Qt6 REQUIRED COMPONENTS Quick SerialPort)
    qt_standard_project_setup(REQUIRES 6.8)

    qt_add_executable(appPushClone
        main.cpp
        ClipGridModel.cpp
        ClipGridModel.h
        TrackListModel.cpp
        TrackListModel.h
        SceneListModel.cpp
        SceneListModel.h
        SerialController.cpp
        SerialController.h
    )

    qt_add_qml_module(appPushClone
        URI PushClone
        VERSION 1.0
        QML_FILES
            Main.qml
            SplashScreen.qml
            PushCloneTheme.qml
            components/ClipPad.qml
            components/NavigationBar.qml
            components/TransportBar.qml
            components/MixChannelStrip.qml
            views/SessionView.qml
            views/MixView.qml
        RESOURCES
            assets/logo.png
    )

    # Fix qmldir to mark PushCloneTheme as singleton
    # Use different sed syntax based on platform (macOS vs Linux)
    if(APPLE)
        add_custom_command(TARGET appPushClone POST_BUILD
            COMMAND sed -i '' 's/^PushCloneTheme/singleton PushCloneTheme/' ${CMAKE_CURRENT_BINARY_DIR}/PushClone/qmldir
            COMMENT "Fixing qmldir to mark PushCloneTheme as singleton (macOS)"
        )
    else()
        add_custom_command(TARGET appPushClone POST_BUILD
            COMMAND sed -i 's/^PushCloneTheme/singleton PushCloneTheme/' ${CMAKE_CURRENT_BINARY_DIR}/PushClone/qmldir
            COMMENT "Fixing qmldir to mark PushCloneTheme as singleton (Linux)"
        )
    endif()

    target_link_libraries(appPushClone
        PRIVATE Qt6::Quick Qt6::SerialPort
    )
    
    target_compile_definitions(appPushClone PRIVATE USE_QT6)

else()
    message(STATUS "Building with Qt5")
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)

    find_package(Qt5 REQUIRED COMPONENTS Quick Qml SerialPort)

    add_executable(appPushClone
        main.cpp
        resources.qrc
        ClipGridModel.cpp
        ClipGridModel.h
        TrackListModel.cpp
        TrackListModel.h
        SceneListModel.cpp
        SceneListModel.h
        SerialController.cpp
        SerialController.h
    )

    target_link_libraries(appPushClone
        PRIVATE Qt5::Quick Qt5::Qml Qt5::SerialPort
    )
endif()


# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appPushClone PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appPushClone
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

include(GNUInstallDirs)
install(TARGETS appPushClone
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
