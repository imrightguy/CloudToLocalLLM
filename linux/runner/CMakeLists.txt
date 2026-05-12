cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "platform_channels.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# APPLICATION_ID is now defined globally in the main CMakeLists.txt
# No need to redefine it here

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# Wayland and DBus libraries for Wayland support
pkg_check_modules(WAYLAND REQUIRED wayland-client wayland-cursor)
target_link_libraries(${BINARY_NAME} PRIVATE ${WAYLAND_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${WAYLAND_INCLUDE_DIRS})

pkg_check_modules(DBUS REQUIRED dbus-1)
target_link_libraries(${BINARY_NAME} PRIVATE ${DBUS_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${DBUS_INCLUDE_DIRS})

# GLib for DBus integration
pkg_check_modules(GLIB REQUIRED glib-2.0 gio-2.0 gio-unix-2.0)
target_link_libraries(${BINARY_NAME} PRIVATE ${GLIB_LIBRARIES})
target_include_directories(${BINARY_NAME} PRIVATE ${GLIB_INCLUDE_DIRS})

# X11 libraries for X11/XWayland fallback
target_link_libraries(${BINARY_NAME} PRIVATE X11)
target_link_libraries(${BINARY_NAME} PRIVATE Xext)
target_link_libraries(${BINARY_NAME} PRIVATE Xtst)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
