import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermisosScreen extends StatefulWidget {
  @override
  _PermisosScreenState createState() => _PermisosScreenState();
}

class _PermisosScreenState extends State<PermisosScreen> {
  String _cameraPermission = 'No concedido';
  String _locationPermission = 'No concedido';
  String _storagePermission = 'No concedido';

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _cameraPermission = prefs.getString('cameraPermission') ?? 'No concedido';
      _locationPermission =
          prefs.getString('locationPermission') ?? 'No concedido';
      _storagePermission =
          prefs.getString('storagePermission') ?? 'No concedido';
    });
  }

  Future<void> _savePermissionStatus(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _handlePermissionStatus(status, 'cameraPermission', 'cámara');
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    _handlePermissionStatus(status, 'locationPermission', 'ubicación');
  }

  Future<void> _requestStoragePermission() async {
    // Detectar la versión del SDK de Android
    if (Platform.isAndroid && (await _getSdkInt()) >= 30) {
      // Para Android 11 (API 30) y superior, usar manageExternalStorage
      final status = await Permission.manageExternalStorage.request();
      _handlePermissionStatus(status, 'storagePermission', 'almacenamiento');
    } else {
      // Para versiones de Android anteriores a Android 11
      final status = await Permission.storage.request();
      _handlePermissionStatus(status, 'storagePermission', 'almacenamiento');
    }
  }

  Future<int> _getSdkInt() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.version.sdkInt;
  }

  void _handlePermissionStatus(
      PermissionStatus status, String key, String permissionType) async {
    final isGranted = status.isGranted ? 'Concedido' : 'Denegado';

    setState(() {
      switch (key) {
        case 'cameraPermission':
          _cameraPermission = isGranted;
          break;
        case 'locationPermission':
          _locationPermission = isGranted;
          break;
        case 'storagePermission':
          _storagePermission = isGranted;
          break;
      }
    });
    await _savePermissionStatus(key, isGranted);

    if (status.isDenied || status.isPermanentlyDenied) {
      _showPermissionDeniedDialog(permissionType);
    } else if (status.isPermanentlyDenied) {
      _showGoToSettingsDialog(permissionType);
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Permiso de $permissionType denegado'),
          content: Text(
              'Debe conceder el permiso de $permissionType en la configuración.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showGoToSettingsDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Permiso de $permissionType denegado permanentemente'),
          content: Text(
              'Debe ir a la configuración de la aplicación para conceder el permiso de $permissionType.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: Text('Ir a configuración'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Permisos'),
        backgroundColor: Color(0xFFFDEFE9),
      ),
      backgroundColor: Color(0xFFFDEFE9),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildPermissionButton(
                'Permiso Cámara', _requestCameraPermission, _cameraPermission),
            _buildPermissionButton('Permiso Ubicación',
                _requestLocationPermission, _locationPermission),
            _buildPermissionButton('Permiso Almacenamiento',
                _requestStoragePermission, _storagePermission),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionButton(
      String title, Function onPressed, String status) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => onPressed(),
          child: Text(title),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Color(0xFFFFC1B6),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Estado: $status',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Color(0xFF3E4A59)),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
