#include "platform_channels.h"
#include <flutter_linux/flutter_linux.h>
#include <cstring>
#include <iostream>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/XTest.h>
#include <algorithm>
#include <fstream>

// X11 Display and Screen
static Display* display = nullptr;
static Window root_window;
static int screen_num;

// Initialize X11 connection
static bool init_x11() {
    if (!display) {
        display = XOpenDisplay(nullptr);
        if (!display) {
            std::cerr << "Failed to open X display" << std::endl;
            return false;
        }
        screen_num = DefaultScreen(display);
        root_window = RootWindow(display, screen_num);
    }
    return true;
}

// ========================================================================
// GUI AUTOMATION CHANNEL HANDLERS
// ========================================================================

// Screenshot capture
static FlValue* capture_screenshot(FlValue* args) {
    if (!init_x11()) {
        return fl_value_new_bool(false);
    }

    // Get screen dimensions
    int screen_width = DisplayWidth(display, screen_num);
    int screen_height = DisplayHeight(display, screen_num);

    // Get file path from arguments
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

    // Capture screenshot using XGetImage
    XImage* x_image = XGetImage(display, root_window, 0, 0,
                                 screen_width, screen_height, AllPlanes, ZPixmap);

    if (!x_image) {
        std::cerr << "Failed to capture screenshot" << std::endl;
        return fl_value_new_bool(false);
    }

    // Write as PPM format (simple, no external dependencies)
    std::ofstream file(path, std::ios::binary);
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
        file.close();
        XFree(x_image);
        return fl_value_new_bool(true);
    }

    XFree(x_image);
    return fl_value_new_bool(false);
}

// Execute action (keyboard/mouse input)
static FlValue* execute_action(FlValue* args) {
    if (!init_x11()) {
        return fl_value_new_string("Failed to initialize X11");
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

    // Parse action string: "click(x,y)", "type(text)", "scroll(direction)", "keypress(key)"
    bool success = false;

    if (action_str.find("click(") == 0) {
        // Parse click(x,y)
        size_t start = action_str.find("(");
        size_t comma = action_str.find(",");
        size_t end = action_str.find(")");

        if (start != std::string::npos && comma != std::string::npos && end != std::string::npos) {
            int x = std::stoi(action_str.substr(start + 1, comma - start - 1));
            int y = std::stoi(action_str.substr(comma + 1, end - comma - 1));

            // Move mouse and click
            XTestFakeMotionEvent(display, screen_num, x, y, CurrentTime);
            XTestFakeButtonEvent(display, 1, True, CurrentTime);
            XTestFakeButtonEvent(display, 1, False, CurrentTime);
            XFlush(display);
            success = true;
        }
    } else if (action_str.find("keypress(") == 0) {
        // Parse keypress(key)
        size_t start = action_str.find("(");
        size_t end = action_str.find(")");

        if (start != std::string::npos && end != std::string::npos) {
            std::string key = action_str.substr(start + 1, end - start - 1);

            // Convert key string to keycode (simplified - common keys only)
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
                KeyCode keycode = XKeysymToKeycode(display, keysym);
                if (keycode != 0) {
                    XTestFakeKeyEvent(display, keycode, True, CurrentTime);
                    XTestFakeKeyEvent(display, keycode, False, CurrentTime);
                    XFlush(display);
                    success = true;
                }
            }
        }
    } else if (action_str.find("scroll(") == 0) {
        // Parse scroll(direction)
        size_t start = action_str.find("(");
        size_t end = action_str.find(")");

        if (start != std::string::npos && end != std::string::npos) {
            std::string direction = action_str.substr(start + 1, end - start - 1);

            int button = 4;  // Scroll up
            if (direction == "down") button = 5;
            else if (direction == "left") button = 6;
            else if (direction == "right") button = 7;

            XTestFakeButtonEvent(display, button, True, CurrentTime);
            XTestFakeButtonEvent(display, button, False, CurrentTime);
            XFlush(display);
            success = true;
        }
    }

    return fl_value_new_string(success ? "Executed successfully" : "Execution failed");
}

// ========================================================================
// WINDOW MANAGER CHANNEL HANDLERS
// ========================================================================

// Get all windows
static FlValue* get_windows() {
    if (!init_x11()) {
        return fl_value_new_list();
    }

    FlValue* result = fl_value_new_list();

    // Get window list via EWMH
    Atom net_client_list = XInternAtom(display, "_NET_CLIENT_LIST", True);

    Atom actual_type;
    int actual_format;
    unsigned long n_items, bytes_after;
    unsigned char* prop = nullptr;

    if (XGetWindowProperty(display, root_window, net_client_list, 0, 1024, False,
                          XA_WINDOW, &actual_type, &actual_format, &n_items, &bytes_after, &prop) == Success) {
        Window* windows = reinterpret_cast<Window*>(prop);

        for (unsigned long i = 0; i < n_items; i++) {
            FlValue* window_info = fl_value_new_map();

            // Window ID
            fl_value_set(window_info, fl_value_new_string("id"),
                fl_value_new_string(std::to_string(windows[i]).c_str()));

            // Window title
            char* window_name = nullptr;
            XFetchName(display, windows[i], &window_name);
            if (window_name) {
                fl_value_set(window_info, fl_value_new_string("title"),
                    fl_value_new_string(window_name));
                XFree(window_name);
            } else {
                fl_value_set(window_info, fl_value_new_string("title"),
                    fl_value_new_string("Unknown"));
            }

            // Get window geometry
            Window root_return;
            int x_return, y_return;
            unsigned int width_return, height_return, border_width_return, depth_return;
            XGetGeometry(display, windows[i], &root_return,
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

            // App name (using WM_CLASS)
            XClassHint class_hint;
            if (XGetClassHint(display, windows[i], &class_hint)) {
                fl_value_set(window_info, fl_value_new_string("appName"),
                    fl_value_new_string(class_hint.res_name ? class_hint.res_name : ""));
                XFree(class_hint.res_name);
                XFree(class_hint.res_class);
            } else {
                fl_value_set(window_info, fl_value_new_string("appName"),
                    fl_value_new_string("Unknown"));
            }

            // State flags (placeholder)
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

// Focus window
static FlValue* focus_window(FlValue* args) {
    if (!init_x11()) {
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

    // Raise and focus window
    XRaiseWindow(display, window_id);
    XSetInputFocus(display, window_id, RevertToParent, CurrentTime);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Move window
static FlValue* move_window(FlValue* args) {
    if (!init_x11()) {
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

    XMoveWindow(display, window_id, x, y);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Resize window
static FlValue* resize_window(FlValue* args) {
    if (!init_x11()) {
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

    XResizeWindow(display, window_id, width, height);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Minimize window
static FlValue* minimize_window(FlValue* args) {
    if (!init_x11()) {
        return fl_value_new_bool(false);
    }

    FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
    if (!window_id_value) {
        return fl_value_new_bool(false);
    }

    const char* window_id_str = fl_value_get_string(window_id_value);
    Window window_id = std::stoull(window_id_str);

    // Send WM_CHANGE_STATE to Iconic
    Atom wm_state = XInternAtom(display, "WM_STATE", False);
    Atom iconic = XInternAtom(display, "IconicState", False);

    XEvent event;
    event.type = ClientMessage;
    event.xclient.display = display;
    event.xclient.window = window_id;
    event.xclient.message_type = wm_state;
    event.xclient.format = 32;
    event.xclient.data.l[0] = iconic;
    event.xclient.data.l[1] = 0;

    XSendEvent(display, root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Maximize window
static FlValue* maximize_window(FlValue* args) {
    if (!init_x11()) {
        return fl_value_new_bool(false);
    }

    FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
    if (!window_id_value) {
        return fl_value_new_bool(false);
    }

    const char* window_id_str = fl_value_get_string(window_id_value);
    Window window_id = std::stoull(window_id_str);

    // Maximize using _NET_WM_STATE
    Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", True);
    Atom net_wm_state_maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
    Atom net_wm_state_maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);

    XEvent event;
    memset(&event, 0, sizeof(event));
    event.type = ClientMessage;
    event.xclient.display = display;
    event.xclient.window = window_id;
    event.xclient.message_type = net_wm_state;
    event.xclient.format = 32;
    event.xclient.data.l[0] = 1;  // _NET_WM_STATE_ADD
    event.xclient.data.l[1] = net_wm_state_maximized_vert;
    event.xclient.data.l[2] = net_wm_state_maximized_horz;

    XSendEvent(display, root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Toggle maximize
static FlValue* toggle_maximize(FlValue* args) {
    if (!init_x11()) {
        return fl_value_new_bool(false);
    }

    FlValue* window_id_value = fl_value_lookup_string(args, "windowId");
    if (!window_id_value) {
        return fl_value_new_bool(false);
    }

    const char* window_id_str = fl_value_get_string(window_id_value);
    Window window_id = std::stoull(window_id_str);

    // Toggle using _NET_WM_STATE with _NET_WM_STATE_TOGGLE (2)
    Atom net_wm_state = XInternAtom(display, "_NET_WM_STATE", True);
    Atom net_wm_state_maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
    Atom net_wm_state_maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);

    XEvent event;
    memset(&event, 0, sizeof(event));
    event.type = ClientMessage;
    event.xclient.display = display;
    event.xclient.window = window_id;
    event.xclient.message_type = net_wm_state;
    event.xclient.format = 32;
    event.xclient.data.l[0] = 2;  // _NET_WM_STATE_TOGGLE
    event.xclient.data.l[1] = net_wm_state_maximized_vert;
    event.xclient.data.l[2] = net_wm_state_maximized_horz;

    XSendEvent(display, root_window, False, SubstructureRedirectMask | SubstructureNotifyMask, &event);
    XFlush(display);

    return fl_value_new_bool(true);
}

// Close window
static FlValue* close_window(FlValue* args) {
    if (!init_x11()) {
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

    // Send WM_DELETE_WINDOW protocol
    Atom wm_protocols = XInternAtom(display, "WM_PROTOCOLS", False);
    Atom wm_delete_window = XInternAtom(display, "WM_DELETE_WINDOW", False);

    XEvent event;
    event.type = ClientMessage;
    event.xclient.display = display;
    event.xclient.window = window_id;
    event.xclient.message_type = wm_protocols;
    event.xclient.format = 32;
    event.xclient.data.l[0] = wm_delete_window;
    event.xclient.data.l[1] = CurrentTime;

    XSendEvent(display, window_id, False, NoEventMask, &event);
    XFlush(display);

    return fl_value_new_bool(true);
}

// ========================================================================
// METHOD CHANNEL HANDLER
// ========================================================================

static void platform_channels_method_call_handler(FlMethodChannel* channel,
                                                   FlMethodCall* method_call,
                                                   gpointer user_data) {
    const gchar* method = fl_method_call_get_name(method_call);
    FlValue* args = fl_method_call_get_args(method_call);

    g_autoptr(FlMethodResponse) response = nullptr;
    FlValue* result = nullptr;

    // GUI AUTOMATION CHANNEL
    if (strcmp(method, "takeScreenshot") == 0) {
        result = capture_screenshot(args);
    } else if (strcmp(method, "executeAction") == 0) {
        result = execute_action(args);
    }

    // WINDOW MANAGER CHANNEL
    else if (strcmp(method, "getWindows") == 0) {
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
    }

    // Unknown method
    else {
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
    // Create standard method codec
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

    // Register GUI Automation channel
    g_autoptr(FlMethodChannel) gui_automation_channel =
        fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                              "cloudtolocallm/gui_automation",
                              FL_METHOD_CODEC(codec));

    fl_method_channel_set_method_call_handler(
        gui_automation_channel,
        platform_channels_method_call_handler,
        nullptr,
        nullptr);

    // Register Window Manager channel
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
