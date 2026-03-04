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

# X11 libraries for Vision and Desktop Control
target_link_libraries(${BINARY_NAME} PRIVATE X11)
target_link_libraries(${BINARY_NAME} PRIVATE Xext)
target_link_libraries(${BINARY_NAME} PRIVATE Xtst)
target_link_libraries(${BINARY_NAME} PRIVATE xcb)
target_link_libraries(${BINARY_NAME} PRIVATE Imlib2)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
