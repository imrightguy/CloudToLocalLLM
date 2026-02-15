import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AgentBrowserPage extends StatefulWidget {
  const AgentBrowserPage({super.key});

  @override
  State<AgentBrowserPage> createState() => _AgentBrowserPageState();
}

class _AgentBrowserPageState extends State<AgentBrowserPage> {
  InAppWebViewController? webViewController;
  final TextEditingController urlController = TextEditingController(text: "https://www.google.com");
  double progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agent Browser Prototype"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              webViewController?.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      hintText: "Enter URL",
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      _loadUrl(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    _loadUrl(urlController.text);
                  },
                ),
              ],
            ),
          ),
          if (progress < 1.0) 
            LinearProgressIndicator(value: progress, minHeight: 2),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
              initialSettings: InAppWebViewSettings(
                isInspectable: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                iframeAllow: "camera; microphone",
                iframeAllowFullscreen: true,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                if (url != null) {
                  setState(() {
                    urlController.text = url.toString();
                  });
                }
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  this.progress = progress / 100;
                });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _captureStatus,
        label: const Text("Capture Context"),
        icon: const Icon(Icons.analytics),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _loadUrl(String urlString) {
    if (urlString.isEmpty) return;
    
    var url = WebUri(urlString);
    if (!url.hasScheme) {
      url = WebUri("https://$urlString");
    }
    webViewController?.loadUrl(urlRequest: URLRequest(url: url));
  }

  Future<void> _captureStatus() async {
    if (webViewController == null) return;

    try {
      // 1. Capture HTML DOM
      String? html = await webViewController!.getHtml();
      
      // 2. Capture Screenshot
      Uint8List? screenshot = await webViewController!.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 80,
        ),
      );

      // 3. Get current URL and Title
      WebUri? currentUrl = await webViewController!.getUrl();
      String? title = await webViewController!.getTitle();

      // Mock sending to agent service
      debugPrint("--- AGENT CAPTURE START ---");
      debugPrint("Title: $title");
      debugPrint("URL: $currentUrl");
      debugPrint("DOM Length: ${html?.length ?? 0}");
      debugPrint("Screenshot Size: ${screenshot?.length ?? 0} bytes");
      debugPrint("--- AGENT CAPTURE END ---");

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Capture Successful"),
            content: SingleChildScrollView(
              child: ListBody(
                children: [
                  Text("URL: $currentUrl"),
                  Text("Title: $title"),
                  Text("DOM Size: ${html?.length ?? 0} characters"),
                  Text("Screenshot: ${screenshot != null ? 'Captured (${screenshot.length} bytes)' : 'Failed'}"),
                  const SizedBox(height: 10),
                  const Text("This data has been 'sent' to the (mocked) agent service.", 
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      debugPrint("Capture failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Capture failed: $e")),
        );
      }
    }
  }
}
