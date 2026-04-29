#include "platform_channels.h"
#include <flutter_linux/flutter_linux.h>
#include <cstring>
#include <iostream>
#include <fstream>
#include <algorithm>
#include <memory>

#include <glib.h>
#include <gio/gio.h>

#include <wayland-client.h>
#include <wayland-cursor.h>

#ifdef HAS_WLR_FOREIGN_TOPLEVEL
#include <wlr-foreign-toplevel-management-unstable-v1-client-protocol.h>
#endif

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>

enum class Backend {
  WAYLAND,
  X11,
  UNKNOWN
};

static Backend backend = Backend::UNKNOWN;
static bool backend_initialized = false;

struct WaylandState {
  struct wl_display* display = nullptr;
  struct wl_compositor* compositor = nullptr;
  struct wl_seat* seat = nullptr;
#ifdef HAS_WLR_FOREIGN_TOPLEVEL
  struct zwlr_foreign_toplevel_manager_v1* toplevel_manager = nullptr;
#endif
  GDBusConnection* dbus_conn = nullptr;
};

struct X11State {
  Display* display = nullptr;
  Window root_window;
  int screen_num;
};

static WaylandState wl_state;
static X11State x11_state;

static bool detect_backend() {
  if (backend_initialized) {
    return backend != Backend::UNKNOWN;
  }

  const char* wayland_display = g_getenv("WAYLAND_DISPLAY");
  const char* display = g_getenv("DISPLAY");

  if (wayland_display != nullptr && strlen(wayland_display) > 0) {
    backend = Backend::WAYLAND;
    std::cout << "[PlatformChannels] Detected Wayland backend" << std::endl;
  } else if (display != nullptr && strlen(display) > 0) {
    backend = Backend::X11;
    std::cout << "[PlatformChannels] Detected X11 backend" << std::endl;
  } else {
    backend = Backend::UNKNOWN;
    std::cerr << "[PlatformChannels] Could not detect display backend" << std::endl;
  }

  backend_initialized = true;
  return backend != Backend::UNKNOWN;
}

static bool init_wayland() {
  if (backend != Backend::WAYLAND) {
    return false;
  }

  wl_state.display = wl_display_connect(nullptr);
  if (!wl_state.display) {
    std::cerr << "[PlatformChannels] Failed to connect to Wayland display" << std::endl;
    backend = Backend::UNKNOWN;
    return false;
  }

  GError* error = nullptr;
  wl_state.dbus_conn = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (!wl_state.dbus_conn) {
    std::cerr << "[PlatformChannels] Failed to connect to DBus: " << error->message << std::endl;
    g_error_free(error);
    wl_display_disconnect(wl_state.display);
    wl_state.display = nullptr;
    return false;
  }

  std::cout << "[PlatformChannels] Wayland backend initialized" << std::endl;
  return true;
}

static bool init_x11() {
  if (backend != Backend::X11) {
    return false;
  }

  x11_state.display = XOpenDisplay(nullptr);
  if (!x11_state.display) {
    std::cerr << "[PlatformChannels] Failed to open X display" << std::endl;
    backend = Backend::UNKNOWN;
    return false;
  }

  x11_state.screen_num = DefaultScreen(x11_state.display);
  x11_state.root_window = RootWindow(x11_state.display, x11_state.screen_num);

  std::cout << "[PlatformChannels] X11 backend initialized" << std::endl;
  return true;
}

static bool init_backend() {
  if (!detect_backend()) {
    return false;
  }

  if (backend == Backend::WAYLAND) {
    return init_wayland();
  } else if (backend == Backend::X11) {
    return init_x11();
  }

  return false;
}

static GVariant* call_dbus_portal(const gchar* object_path, const gchar* interface_name,
                                   const gchar* method_name, GVariant* parameters,
                                   GError** error) {
  if (!wl_state.dbus_conn) {
    g_set_error(error, G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED, "DBus not connected");
    return nullptr;
  }

  GVariant* result = g_dbus_connection_call_sync(
    wl_state.dbus_conn,
    "org.freedesktop.portal.Desktop",
    object_path,
    interface_name,
    method_name,
    parameters,
    nullptr,
    G_DBUS_CALL_FLAGS_NONE,
    -1,
    nullptr,
    error
  );

  return result;
}

static FlValue* capture_screenshot_wayland(const char* path) {
  GError* error = nullptr;

  GVariant* result = call_dbus_portal(
    "/org/freedesktop/portal/desktop",
    "org.freedesktop.portal.Screenshot",
    "Screenshot",
    g_variant_new("(sa{sv})", "", nullptr),
    &error
  );

  if (!result) {
    std::cerr << "[PlatformChannels] Portal screenshot failed: " << error->message << std::endl;
    g_error_free(error);
    return fl_value_new_bool(false);
  }

  guint32 response;
  GVariant* results;
  g_variant_get(result, "(u@a{sv})", &response, &results);

  if (response != 0) {
    std::cerr << "[PlatformChannels] Portal screenshot denied by user" << std::endl;
    g_variant_unref(results);
    g_variant_unref(result);
    return fl_value_new_bool(false);
  }

  GVariant* uri_variant = g_variant_lookup_value(results, "uri", nullptr);
  if (!uri_variant) {
    std::cerr << "[PlatformChannels] Portal screenshot returned no URI" << std::endl;
    g_variant_unref(results);
    g_variant_unref(result);
    return fl_value_new_bool(false);
  }

  const gchar* uri = g_variant_get_string(uri_variant, nullptr);
  gchar* file_path = g_filename_from_uri(uri, nullptr, nullptr);

  if (file_path) {
    std::ifstream src(file_path, std::ios::binary);
    std::ofstream dst(path, std::ios::binary);
    dst << src.rdbuf();
    g_free(file_path);
  }

  g_variant_unref(results);
  g_variant_unref(result);

  return fl_value_new_bool(true);
}

static FlValue* capture_screenshot_x11(const char* path) {
  if (!x11_state.display) {
    return fl_value_new_bool(false);
  }

  int screen_width = DisplayWidth(x11_state.display, x11_state.screen_num);
  int screen_height = DisplayHeight(x11_state.display, x11_state.screen_num);

  XImage* x_image = XGetImage(x11_state.display, x11_state.root_window, 0, 0,
                               screen_width, screen_height, AllPlanes, ZPixmap);

  if (!x_image) {
    std::cerr << "[PlatformChannels] Failed to capture X11 screenshot" << std::endl;
    return fl_value_new_bool(false);
  }

  std::ofstream file(path, std::ios::binary);
  bool success = false;

  if (file.is_open()) {
    file << "P6\n" << screen_width << " " << screen_height << "\n255\n";

    for (int y = 0; y < screen_height; y++) {
      for (int x = 0; x < screen_width; x++) {
        unsigned long pixel = XGetPixel(x_image, x, y);
        unsigned char red = (pixel & x_image->red_mask) >> 16;
        unsigned char green = (pixel & x_image->green_mask) >> 8;
        unsigned char blue = (pixel & x_image->blue_mask);

        file.write(reinterpret_cast<const char*>(&red), 1);
        file.write(reinterpret_cast<const char*>(&green), 1);
        file.write(reinterpret_cast<const char*>(&blue), 1);
      }
    }
    success = true;
    file.close();
  }

  XFree(x_image);
  return fl_value_new_bool(success);
}

static FlValue* capture_screenshot(FlValue* args) {
  if (!init_backend()) {
    return fl_value_new_bool(false);
  }

  const char* path = nullptr;
  if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* path_value = fl_value_lookup_string(args, "path");
    if (path_value && fl_value_get_type(path_value) == FL_VALUE_TYPE_STRING) {
      path = fl_value_get_string(path_value);
    }
  }

  if (!path) {
    return fl_value_new_bool(false);
  }

  if (backend == Backend::WAYLAND) {
    return capture_screenshot_wayland(path);
  } else if (backend == Backend::X11) {
    return capture_screenshot_x11(path);
  }

  return fl_value_new_bool(false);
}

static FlValue* capture_region_wayland(int x, int y, int width, int height, const char* path) {
  GError* error = nullptr;

  GVariantBuilder options_builder;
  g_variant_builder_init(&options_builder, G_VARIANT_TYPE_VARDICT);

  GVariant* result = call_dbus_portal(
    "/org/freedesktop/portal/desktop",
    "org.freedesktop.portal.Screenshot",
    "Screenshot",
    g_variant_new("(sa{sv})", "", &options_builder),
    &error
  );

  g_variant_builder_clear(&options_builder);

  if (!result) {
    std::cerr << "[PlatformChannels] Portal region capture failed: " << error->message << std::endl;
    g_error_free(error);
    return fl_value_new_bool(false);
  }

  guint32 response;
  GVariant* results;
  g_variant_get(result, "(u@a{sv})", &response, &results);

  if (response != 0) {
    std::cerr << "[PlatformChannels] Portal region capture denied" << std::endl;
    g_variant_unref(results);
    g_variant_unref(result);
    return fl_value_new_bool(false);
  }

  GVariant* uri_variant = g_variant_lookup_value(results, "uri", nullptr);
  if (!uri_variant) {
    std::cerr << "[PlatformChannels] Portal region capture no URI" << std::endl;
    g_variant_unref(results);
    g_variant_unref(result);
    return fl_value_new_bool(false);
  }

  const gchar* uri = g_variant_get_string(uri_variant, nullptr);
  gchar* file_path = g_filename_from_uri(uri, nullptr, nullptr);

  if (file_path) {
    std::ifstream src(file_path, std::ios::binary);
    std::ofstream dst(path, std::ios::binary);
    dst << src.rdbuf();
    g_free(file_path);
  }

  g_variant_unref(results);
  g_variant_unref(result);

  return fl_value_new_bool(true);
}

static FlValue* capture_region_x11(int x, int y, int width, int height, const char* path) {
  if (!x11_state.display) {
    return fl_value_new_bool(false);
  }

  XImage* x_image = XGetImage(x11_state.display, x11_state.root_window, x, y,
                               width, height, AllPlanes, ZPixmap);

  if (!x_image) {
    std::cerr << "[PlatformChannels] Failed to capture X11 region" << std::endl;
    return fl_value_new_bool(false);
  }

  std::ofstream file(path, std::ios::binary);
  bool success = false;

  if (file.is_open()) {
    file << "P6\n" << width << " " << height << "\n255\n";

    for (int row = 0; row < height; row++) {
      for (int col = 0; col < width; col++) {
        unsigned long pixel = XGetPixel(x_image, col, row);
        unsigned char red = (pixel & x_image->red_mask) >> 16;
        unsigned char green = (pixel & x_image->green_mask) >> 8;
        unsigned char blue = (pixel & x_image->blue_mask);

        file.write(reinterpret_cast<const char*>(&red), 1);
        file.write(reinterpret_cast<const char*>(&green), 1);
        file.write(reinterpret_cast<const char*>(&blue), 1);
      }
    }
    success = true;
    file.close();
  }

  XFree(x_image);
  return fl_value_new_bool(success);
}

static FlValue* capture_region(FlValue* args) {
  if (!init_backend()) {
    return fl_value_new_bool(false);
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_bool(false);
  }

  FlValue* x_value = fl_value_lookup_string(args, "x");
  FlValue* y_value = fl_value_lookup_string(args, "y");
  FlValue* width_value = fl_value_lookup_string(args, "width");
  FlValue* height_value = fl_value_lookup_string(args, "height");
  FlValue* path_value = fl_value_lookup_string(args, "path");

  if (!x_value || !y_value || !width_value || !height_value || !path_value) {
    return fl_value_new_bool(false);
  }

  int x = fl_value_get_int(x_value);
  int y = fl_value_get_int(y_value);
  int width = fl_value_get_int(width_value);
  int height = fl_value_get_int(height_value);
  const char* path = fl_value_get_string(path_value);

  if (backend == Backend::WAYLAND) {
    return capture_region_wayland(x, y, width, height, path);
  } else if (backend == Backend::X11) {
    return capture_region_x11(x, y, width, height, path);
  }

  return fl_value_new_bool(false);
}

static FlValue* execute_action(FlValue* args) {
  if (!init_backend()) {
    return fl_value_new_string("Backend not initialized");
  }

  if (backend == Backend::WAYLAND) {
    return fl_value_new_string("Input automation on Wayland requires XWayland");
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_string("Invalid arguments");
  }

  FlValue* action_value = fl_value_lookup_string(args, "action");
  if (!action_value || fl_value_get_type(action_value) != FL_VALUE_TYPE_STRING) {
    return fl_value_new_string("No action specified");
  }

  const char* action = fl_value_get_string(action_value);
  std::string action_str(action);

  bool success = false;

  if (action_str.find("click(") == 0) {
    size_t start = action_str.find("(");
    size_t comma = action_str.find(",");
    size_t end = action_str.find(")");

    if (start != std::string::npos && comma != std::string::npos && end != std::string::npos) {
      int x = std::stoi(action_str.substr(start + 1, comma - start - 1));
      int y = std::stoi(action_str.substr(comma + 1, end - comma - 1));

      XTestFakeMotionEvent(x11_state.display, x11_state.screen_num, x, y, CurrentTime);
      XTestFakeButtonEvent(x11_state.display, 1, True, CurrentTime);
      XTestFakeButtonEvent(x11_state.display, 1, False, CurrentTime);
      XFlush(x11_state.display);
      success = true;
    }
  } else if (action_str.find("keypress(") == 0) {
    size_t start = action_str.find("(");
    size_t end = action_str.find(")");

    if (start != std::string::npos && end != std::string::npos) {
      std::string key = action_str.substr(start + 1, end - start - 1);

      KeySym keysym = NoSymbol;
      if (key == "Enter") keysym = XK_Return;
      else if (key == "Tab") keysym = XK_Tab;
      else if (key == "Escape") keysym = XK_Escape;
      else if (key == "Backspace") keysym = XK_BackSpace;
      else if (key == "Delete") keysym = XK_Delete;
      else if (key == "space") keysym = XK_space;
      else if (key.length() == 1) {
        keysym = XStringToKeysym(key.c_str());
      }

      if (keysym != NoSymbol) {
        KeyCode keycode = XKeysymToKeycode(x11_state.display, keysym);
        if (keycode != 0) {
          XTestFakeKeyEvent(x11_state.display, keycode, True, CurrentTime);
          XTestFakeKeyEvent(x11_state.display, keycode, False, CurrentTime);
          XFlush(x11_state.display);
          success = true;
        }
      }
    }
  } else if (action_str.find("scroll(") == 0) {
    size_t start = action_str.find("(");
    size_t end = action_str.find(")");

    if (start != std::string::npos && end != std::string::npos) {
      std::string direction = action_str.substr(start + 1, end - start - 1);

      int button = 4;
      if (direction == "down") button = 5;
      else if (direction == "left") button = 6;
      else if (direction == "right") button = 7;

      XTestFakeButtonEvent(x11_state.display, button, True, CurrentTime);
      XTestFakeButtonEvent(x11_state.display, button, False, CurrentTime);
      XFlush(x11_state.display);
      success = true;
    }
  }

  return fl_value_new_string(success ? "Executed successfully" : "Execution failed");
}

static FlValue* get_windows_wayland() {
  FlValue* result = fl_value_new_list();

  if (!wl_state.dbus_conn) {
    return result;
  }

#ifdef HAS_WLR_FOREIGN_TOPLEVEL
  if (!wl_state.toplevel_manager) {
    std::cerr << "[PlatformChannels] wlr-foreign-toplevel not available" << std::endl;
    return result;
  }
#endif

  return result;
}

static FlValue* get_windows_x11() {
  if (!x11_state.display) {
    return fl_value_new_list();
  }

  FlValue* result = fl_value_new_list();
  Atom net_client_list = XInternAtom(x11_state.display, "_NET_CLIENT_LIST", True);

  Atom actual_type;
  int actual_format;
  unsigned long n_items, bytes_after;
  unsigned char* prop = nullptr;

  if (XGetWindowProperty(x11_state.display, x11_state.root_window, net_client_list, 0, 1024, False,
                        XA_WINDOW, &actual_type, &actual_format, &n_items, &bytes_after, &prop) == Success) {
    Window* windows = reinterpret_cast<Window*>(prop);

    for (unsigned long i = 0; i < n_items; i++) {
      FlValue* window_info = fl_value_new_map();

      fl_value_set(window_info, fl_value_new_string("id"),
        fl_value_new_string(std::to_string(windows[i]).c_str()));

      char* window_name = nullptr;
      XFetchName(x11_state.display, windows[i], &window_name);
      if (window_name) {
        fl_value_set(window_info, fl_value_new_string("title"),
          fl_value_new_string(window_name));
        XFree(window_name);
      } else {
        fl_value_set(window_info, fl_value_new_string("title"),
          fl_value_new_string("Unknown"));
      }

      Window root_return;
      int x_return, y_return;
      unsigned int width_return, height_return, border_width_return, depth_return;
      XGetGeometry(x11_state.display, windows[i], &root_return,
                 &x_return, &y_return, &width_return, &height_return,
                 &border_width_return, &depth_return);

      fl_value_set(window_info, fl_value_new_string("x"),
        fl_value_new_int(x_return));
      fl_value_set(window_info, fl_value_new_string("y"),
        fl_value_new_int(y_return));
      fl_value_set(window_info, fl_value_new_string("width"),
        fl_value_new_int(width_return));
      fl_value_set(window_info, fl_value_new_string("height"),
        fl_value_new_int(height_return));

      XClassHint class_hint;
      if (XGetClassHint(x11_state.display, windows[i], &class_hint)) {
        fl_value_set(window_info, fl_value_new_string("appName"),
          fl_value_new_string(class_hint.res_name ? class_hint.res_name : ""));
        XFree(class_hint.res_name);
        XFree(class_hint.res_class);
      } else {
        fl_value_set(window_info, fl_value_new_string("appName"),
          fl_value_new_string("Unknown"));
      }

      fl_value_set(window_info, fl_value_new_string("isMinimized"),
        fl_value_new_bool(false));
      fl_value_set(window_info, fl_value_new_string("isMaximized"),
        fl_value_new_bool(false));
      fl_value_set(window_info, fl_value_new_string("isActive"),
        fl_value_new_bool(false));

      fl_value_append(result, window_info);
    }

    XFree(prop);
  }

  return result;
}

static FlValue* get_windows() {
  if (!init_backend()) {
    return fl_value_new_list();
  }

  if (backend == Backend::WAYLAND) {
    return get_windows_wayland();
  } else if (backend == Backend::X11) {
    return get_windows_x11();
  }

  return fl_value_new_list();
}

static FlValue* focus_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  if (!window_id_value || fl_value_get_type(window_id_value) != FL_VALUE_TYPE_STRING) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);

  XRaiseWindow(x11_state.display, window_id);
  XSetInputFocus(x11_state.display, window_id, RevertToParent, CurrentTime);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* move_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  FlValue* x_value = fl_value_lookup_string(args, "x");
  FlValue* y_value = fl_value_lookup_string(args, "y");

  if (!window_id_value || !x_value || !y_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);
  int x = fl_value_get_int(x_value);
  int y = fl_value_get_int(y_value);

  XMoveWindow(x11_state.display, window_id, x, y);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* resize_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  FlValue* width_value = fl_value_lookup_string(args, "width");
  FlValue* height_value = fl_value_lookup_string(args, "height");

  if (!window_id_value || !width_value || !height_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);
  int width = fl_value_get_int(width_value);
  int height = fl_value_get_int(height_value);

  XResizeWindow(x11_state.display, window_id, width, height);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* minimize_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  if (!window_id_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);

  Atom wm_state = XInternAtom(x11_state.display, "WM_STATE", False);
  Atom iconic = XInternAtom(x11_state.display, "IconicState", False);

  XEvent event;
  event.type = ClientMessage;
  event.xclient.display = x11_state.display;
  event.xclient.window = window_id;
  event.xclient.message_type = wm_state;
  event.xclient.format = 32;
  event.xclient.data.l[0] = iconic;
  event.xclient.data.l[1] = 0;

  XSendEvent(x11_state.display, x11_state.root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* maximize_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  if (!window_id_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);

  Atom net_wm_state = XInternAtom(x11_state.display, "_NET_WM_STATE", True);
  Atom net_wm_state_maximized_vert = XInternAtom(x11_state.display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
  Atom net_wm_state_maximized_horz = XInternAtom(x11_state.display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);

  XEvent event;
  memset(&event, 0, sizeof(event));
  event.type = ClientMessage;
  event.xclient.display = x11_state.display;
  event.xclient.window = window_id;
  event.xclient.message_type = net_wm_state;
  event.xclient.format = 32;
  event.xclient.data.l[0] = 1;
  event.xclient.data.l[1] = net_wm_state_maximized_vert;
  event.xclient.data.l[2] = net_wm_state_maximized_horz;

  XSendEvent(x11_state.display, x11_state.root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* toggle_maximize(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  if (!window_id_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);

  Atom net_wm_state = XInternAtom(x11_state.display, "_NET_WM_STATE", True);
  Atom net_wm_state_maximized_vert = XInternAtom(x11_state.display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
  Atom net_wm_state_maximized_horz = XInternAtom(x11_state.display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);

  XEvent event;
  memset(&event, 0, sizeof(event));
  event.type = ClientMessage;
  event.xclient.display = x11_state.display;
  event.xclient.window = window_id;
  event.xclient.message_type = net_wm_state;
  event.xclient.format = 32;
  event.xclient.data.l[0] = 2;
  event.xclient.data.l[1] = net_wm_state_maximized_vert;
  event.xclient.data.l[2] = net_wm_state_maximized_horz;

  XSendEvent(x11_state.display, x11_state.root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* close_window(FlValue* args) {
  if (!init_backend() || backend != Backend::X11) {
    return fl_value_new_bool(false);
  }

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return fl_value_new_bool(false);
  }

  FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
  if (!window_id_value) {
    return fl_value_new_bool(false);
  }

  const char* window_id_str = fl_value_get_string(window_id_value);
  Window window_id = std::stoull(window_id_str);

  Atom wm_protocols = XInternAtom(x11_state.display, "WM_PROTOCOLS", False);
  Atom wm_delete_window = XInternAtom(x11_state.display, "WM_DELETE_WINDOW", False);

  XEvent event;
  event.type = ClientMessage;
  event.xclient.display = x11_state.display;
  event.xclient.window = window_id;
  event.xclient.message_type = wm_protocols;
  event.xclient.format = 32;
  event.xclient.data.l[0] = wm_delete_window;
  event.xclient.data.l[1] = CurrentTime;

  XSendEvent(x11_state.display, window_id, False, NoEventMask, &event);
  XFlush(x11_state.display);

  return fl_value_new_bool(true);
}

static FlValue* get_screen_size() {
  if (!init_backend()) {
    return fl_value_new_null();
  }

  FlValue* result = fl_value_new_map();
  int width = 0, height = 0;

  if (backend == Backend::WAYLAND) {
    const char* wayland_display = g_getenv("WAYLAND_DISPLAY");
    if (wayland_display) {
      struct wl_display* display = wl_display_connect(nullptr);
      if (display) {
        struct wl_registry* registry = wl_display_get_registry(display);
        (void)registry;
        wl_display_roundtrip(display);
        wl_display_disconnect(display);
      }
    }
  } else if (backend == Backend::X11) {
    width = DisplayWidth(x11_state.display, x11_state.screen_num);
    height = DisplayHeight(x11_state.display, x11_state.screen_num);
  }

  fl_value_set(result, fl_value_new_string("width"), fl_value_new_int(width));
  fl_value_set(result, fl_value_new_string("height"), fl_value_new_int(height));

  return result;
}

static FlValue* initialize_region_capture() {
  if (!init_backend()) {
    return fl_value_new_bool(false);
  }

  return fl_value_new_bool(true);
}

static void platform_channels_method_call_handler(FlMethodChannel* channel,
                                                   FlMethodCall* method_call,
                                                   gpointer user_data) {
    const gchar* method = fl_method_call_get_name(method_call);
    FlValue* args = fl_method_call_get_args(method_call);

    g_autoptr(FlMethodResponse) response = nullptr;
    FlValue* result = nullptr;

    if (strcmp(method, "takeScreenshot") == 0) {
        result = capture_screenshot(args);
    } else if (strcmp(method, "executeAction") == 0) {
        result = execute_action(args);
    } else if (strcmp(method, "captureRegion") == 0) {
        result = capture_region(args);
    } else if (strcmp(method, "getScreenSize") == 0) {
        result = get_screen_size();
    } else if (strcmp(method, "initialize") == 0) {
        result = initialize_region_capture();
    } else if (strcmp(method, "getWindows") == 0) {
        result = get_windows();
    } else if (strcmp(method, "focusWindow") == 0) {
        result = focus_window(args);
    } else if (strcmp(method, "moveWindow") == 0) {
        result = move_window(args);
    } else if (strcmp(method, "resizeWindow") == 0) {
        result = resize_window(args);
    } else if (strcmp(method, "minimizeWindow") == 0) {
        result = minimize_window(args);
    } else if (strcmp(method, "maximizeWindow") == 0) {
        result = maximize_window(args);
    } else if (strcmp(method, "toggleMaximize") == 0) {
        result = toggle_maximize(args);
    } else if (strcmp(method, "closeWindow") == 0) {
        result = close_window(args);
    } else {
        response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
        fl_method_call_respond(method_call, response, nullptr);
        return;
    }

    if (result) {
        g_autoptr(FlValue) response_data = result;
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(response_data));
    } else {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    }

    fl_method_call_respond(method_call, response, nullptr);
}

void register_platform_channels(FlEngine* engine) {
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

    g_autoptr(FlMethodChannel) gui_automation_channel =
        fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                              "cloudtolocallm/gui_automation",
                              FL_METHOD_CODEC(codec));

    fl_method_channel_set_method_call_handler(
        gui_automation_channel,
        platform_channels_method_call_handler,
        nullptr,
        nullptr);

    g_autoptr(FlMethodChannel) region_capture_channel =
        fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                              "cloudtolocallm/region_capture",
                              FL_METHOD_CODEC(codec));

    fl_method_channel_set_method_call_handler(
        region_capture_channel,
        platform_channels_method_call_handler,
        nullptr,
        nullptr);

    g_autoptr(FlMethodChannel) window_manager_channel =
        fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                              "cloudtolocallm/window_manager",
                              FL_METHOD_CODEC(codec));

    fl_method_channel_set_method_call_handler(
        window_manager_channel,
        platform_channels_method_call_handler,
        nullptr,
        nullptr);
}
