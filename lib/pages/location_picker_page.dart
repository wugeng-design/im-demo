import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.onLocationSelected,
  });

  final void Function(Map<String, dynamic> locationData) onLocationSelected;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  Position? _currentPosition;
  Placemark? _currentPlacemark;
  bool _isLoading = true;
  List<Placemark> _searchResults = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('需要位置权限才能使用位置选择功能');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('位置权限已被永久拒绝，请在设置中开启');
        setState(() => _isLoading = false);
        return;
      }

      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      // 获取地址信息
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      _showError('获取位置失败: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _currentPlacemark = placemarks[0];
        });
      }
    } catch (e) {
      print('获取地址失败: $e');
    }
  }

  Future<void> _getCoordinatesFromAddress(Placemark placemark) async {
    try {
      // 构建完整地址字符串
      String address = _formatAddress(placemark);
      
      // 使用geocoding库根据地址获取坐标
      List<Location> locations = await locationFromAddress(address);
      
      if (locations.isNotEmpty) {
        Location location = locations[0];
        setState(() {
          _currentPosition = Position(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });
      }
    } catch (e) {
      print('获取坐标失败: $e');
      _showError('获取位置坐标失败');
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      // 使用geocoding库执行地址搜索
      List<Location> locations = await locationFromAddress(query);
      
      // 将Location转换为Placemark
      List<Placemark> placemarks = [];
      for (Location location in locations) {
        List<Placemark> placemarkList = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarkList.isNotEmpty) {
          placemarks.add(placemarkList[0]);
        }
      }
      
      setState(() {
        _searchResults = placemarks;
      });
    } catch (e) {
      print('搜索失败: $e');
      _showError('搜索位置失败，请尝试其他关键词');
    }
  }

  void _selectLocation() {
    if (_currentPosition == null || _currentPlacemark == null) {
      _showError('请先获取位置信息');
      return;
    }

    String address = _formatAddress(_currentPlacemark!);
    final locationData = {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
      'address': address,
    };

    widget.onLocationSelected(locationData);
    Navigator.pop(context);
  }

  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];

    if (placemark.country != null && placemark.country!.isNotEmpty) {
      addressParts.add(placemark.country!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      addressParts.add(placemark.subLocality!);
    }
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    }
    if (placemark.name != null && placemark.name!.isNotEmpty) {
      addressParts.add(placemark.name!);
    }

    return addressParts.join(' ');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置'),
        actions: [
          TextButton(
            onPressed: _selectLocation,
            child: const Text('发送'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Container(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchPlaces,
                    decoration: InputDecoration(
                      hintText: '搜索位置',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // 搜索结果
                if (_searchResults.isNotEmpty)
                  Container(
                    height: 200,
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final placemark = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.red),
                          title: Text(placemark.name ?? ''),
                          subtitle: Text(_formatAddress(placemark)),
                          onTap: () async {
                            // 选择搜索结果
                            setState(() {
                              _currentPlacemark = placemark;
                              _searchResults = [];
                              _searchController.clear();
                            });
                            
                            // 获取该位置的坐标信息
                            await _getCoordinatesFromAddress(placemark);
                          },
                        );
                      },
                    ),
                  ),

                // 位置列表
                Expanded(
                  child: ListView(
                    children: [
                      if (_currentPlacemark != null)
                        ListTile(
                          leading: const Icon(Icons.my_location, color: Colors.blue),
                          title: const Text('当前位置'),
                          subtitle: Text(_formatAddress(_currentPlacemark!)),
                          onTap: () {
                            // 选择当前位置
                          },
                        ),
                      // 这里可以添加更多位置选项，比如常用位置
                      ListTile(
                        leading: const Icon(Icons.home, color: Colors.green),
                        title: const Text('家'),
                        subtitle: const Text('请设置家庭地址'),
                        onTap: () {
                          _showError('请先设置家庭地址');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.work, color: Colors.purple),
                        title: const Text('公司'),
                        subtitle: const Text('请设置公司地址'),
                        onTap: () {
                          _showError('请先设置公司地址');
                        },
                      ),
                    ],
                  ),
                ),

                // 当前位置信息
                if (_currentPlacemark != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatAddress(_currentPlacemark!),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
