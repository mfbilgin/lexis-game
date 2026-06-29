import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _githubUsername = 'mfbilgin';
  static const String _githubRepo = 'lexis-game';
  
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      final url = Uri.parse('https://api.github.com/repos/$_githubUsername/$_githubRepo/releases/latest');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestTag = data['tag_name'] as String;
        
        final latestVersion = latestTag.replaceAll('v', '').split('+')[0];
        final currentVersionStr = currentVersion.replaceAll('v', '').split('+')[0];
        
        if (_isUpdateAvailable(currentVersionStr, latestVersion)) {
          final apkAsset = (data['assets'] as List).firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          );
          
          if (apkAsset != null && context.mounted) {
            _showUpdateDialog(context, latestVersion, apkAsset['browser_download_url']);
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static bool _isUpdateAvailable(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (_) {}
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Güncelleme! 🚀'),
        content: Text('Lexis\'in $version sürümü yayınlandı. Daha iyi bir deneyim için güncellemeyi indirebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Daha Sonra'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final url = Uri.parse(downloadUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Şimdi İndir'),
          ),
        ],
      ),
    );
  }
}
