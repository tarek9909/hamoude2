import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

class PoliciesWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PoliciesWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PoliciesWebViewScreen> createState() => _PoliciesWebViewScreenState();
}

class _PoliciesWebViewScreenState extends State<PoliciesWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0.0;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8), width: 1.0),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  color: colors.primary, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.ebGaramond(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: colors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.transparent,
                color: AppTheme.primary,
                minHeight: 3,
              ),
            ),
          if (_isLoading && _progress < 0.1)
            Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
