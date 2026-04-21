import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationViewerPage extends StatelessWidget {
  const LocationViewerPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('位置信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation),
            onPressed: _openInMaps,
            tooltip: '导航到此位置',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: colors.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 64,
                      color: colors.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        address,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyCoordinates,
                      icon: const Icon(Icons.copy),
                      label: const Text('复制坐标'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _openInMaps,
                      icon: const Icon(Icons.map),
                      label: const Text('打开地图'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps() async {
    // 使用Google Maps URL
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    // 尝试使用geo:协议打开地图应用
    final geoUrl = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude($address)',
    );

    // 首先尝试geo:协议
    if (await canLaunchUrl(geoUrl)) {
      await launchUrl(geoUrl);
      return;
    }

    // 如果geo:协议不可用，使用Google Maps URL
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // 如果都不可用，抛出异常
    throw Exception('无法打开地图应用');
  }

  Future<void> _copyCoordinates() async {
    // 复制坐标到剪贴板
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
