import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/top_toast.dart';

/// Hosts that may be loaded over plain http, and only in debug builds
/// (matches android/app/src/debug network_security_config).
const _debugCleartextHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

/// Returns the parsed [Uri] when [url] is safe to open in the app, else null.
///
/// Only https URLs are accepted. In debug builds http is also accepted for
/// local development hosts.
Uri? safeExternalUri(String? url) {
  final raw = url?.trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return uri;
  if (kDebugMode &&
      scheme == 'http' &&
      _debugCleartextHosts.contains(uri.host.toLowerCase())) {
    return uri;
  }
  return null;
}

class PoliciesWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PoliciesWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  /// Opens [url] safely: rejects non-https links with a toast, opens a
  /// browser tab on web, and pushes the in-app WebView elsewhere.
  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
  }) async {
    final uri = safeExternalUri(url);
    if (uri == null) {
      showTopToast(context, 'This link cannot be opened securely.');
      return;
    }
    if (kIsWeb) {
      final opened = await _launchInBrowser(uri);
      if (!opened && context.mounted) {
        showTopToast(context, 'Unable to open this page.');
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PoliciesWebViewScreen(url: uri.toString(), title: title),
      ),
    );
  }

  @override
  State<PoliciesWebViewScreen> createState() => _PoliciesWebViewScreenState();
}

Future<bool> _launchInBrowser(Uri uri) async {
  try {
    return await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } catch (e) {
    debugPrint('Failed to open $uri: $e');
    return false;
  }
}

class _PoliciesWebViewScreenState extends State<PoliciesWebViewScreen> {
  WebViewController? _controller;
  Uri? _uri;
  bool _isLoading = true;
  bool _hasError = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _uri = safeExternalUri(widget.url);
    final uri = _uri;
    if (uri == null) {
      _isLoading = false;
      _hasError = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showTopToast(context, 'This link cannot be opened securely.');
        }
      });
      return;
    }
    if (kIsWeb) {
      // webview_flutter has no web implementation; use a browser tab.
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInBrowser());
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (safeExternalUri(request.url) == null) {
              if (mounted) {
                showTopToast(context, 'This link cannot be opened securely.');
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _progress = 0.0;
            });
          },
          onPageFinished: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
            // Ignore failures of sub-resources (images, scripts); only a
            // failed main document leaves the page blank.
            if (error.isForMainFrame == false) return;
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      );
    _load();
  }

  void _load() {
    final controller = _controller;
    final uri = _uri;
    if (controller == null || uri == null) return;
    controller.loadRequest(uri).catchError((Object e) {
      debugPrint('WebView load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    });
  }

  void _retry() {
    if (kIsWeb) {
      _openInBrowser();
      return;
    }
    setState(() {
      _hasError = false;
      _isLoading = true;
      _progress = 0.0;
    });
    _load();
  }

  Future<void> _openInBrowser() async {
    final uri = _uri;
    if (uri == null) return;
    final opened = await _launchInBrowser(uri);
    if (!opened && mounted) {
      showTopToast(context, 'Unable to open this page.');
    }
  }

  Widget _buildMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primary, size: 40),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppTheme.secondary,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_uri == null) {
      return _buildMessage(
        icon: Icons.link_off_rounded,
        message: 'This link cannot be opened securely.',
      );
    }
    if (kIsWeb) {
      return _buildMessage(
        icon: Icons.open_in_new_rounded,
        message: 'This page opens in a new browser tab.',
        actionLabel: 'OPEN PAGE',
        onAction: _openInBrowser,
      );
    }
    if (_hasError) {
      return _buildMessage(
        icon: Icons.wifi_off_rounded,
        message:
            'We could not load this page. Check your connection and try again.',
        actionLabel: 'RETRY',
        onAction: _retry,
      );
    }
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
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
    );
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
      body: _buildBody(),
    );
  }
}
