import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geocoding/geocoding.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class GaleriaScreen extends StatefulWidget {
  @override
  _GaleriaScreenState createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, String>> _photos = []; // Lista de fotos y sus notas
  bool _isCameraPermissionGranted = false; // Estado del permiso de cámara
  bool _isStoragePermissionGranted =
      false; // Estado del permiso de almacenamiento
  bool _isLocationPermissionGranted = false; // Estado del permiso de ubicación
  String _currentAddress = "Ubicación no disponible"; // Dirección actual

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _checkCameraPermission();
    _checkStoragePermission();
    _checkLocationPermission(); // Comprobar permiso de ubicación
  }

  Future<void> _loadPhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedPhotos = prefs.getStringList('photos');
    if (savedPhotos != null) {
      setState(() {
        _photos = savedPhotos.map((photo) {
          final splitData = photo.split('||');
          return {'path': splitData[0], 'note': splitData[1]};
        }).toList();
      });
    }
  }

  Future<void> _savePhotos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> photoData = _photos.map((photo) {
      return '${photo['path']}||${photo['note']}';
    }).toList();
    await prefs.setStringList('photos', photoData);
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _isCameraPermissionGranted = status.isGranted;
    });
  }

  Future<void> _checkStoragePermission() async {
    PermissionStatus status;

    if (Platform.isAndroid && (await _getSdkInt()) >= 30) {
      status = await Permission.manageExternalStorage.status;
    } else {
      status = await Permission.storage.status;
    }

    setState(() {
      _isStoragePermissionGranted = status.isGranted;
    });
  }

  Future<int> _getSdkInt() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.version.sdkInt;
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    setState(() {
      _isLocationPermissionGranted = status.isGranted;
    });

    if (_isLocationPermissionGranted) {
      _getCurrentLocation(); // Obtener la ubicación si el permiso está concedido
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // Mejor precisión posible
        distanceFilter: 100, // Notificación cada 100 metros
      );

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      setState(() {
        _currentAddress = "${place.locality}, ${place.country}";
      });
    } catch (e) {
      setState(() {
        _currentAddress = "Error al obtener la ubicación";
      });
    }
  }

  Future<void> _takePhoto() async {
    if (_isCameraPermissionGranted) {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _photos.add({'path': photo.path, 'note': ''});
        });
        await _savePhotos();
      }
    } else {
      _showPermissionDeniedDialog('cámara');
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Permiso Denegado'),
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

  void _openNoteDialog(int index) {
    TextEditingController noteController =
        TextEditingController(text: _photos[index]['note']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Agregar Nota'),
          content: SizedBox(
            height: 150,
            child: TextField(
              controller: noteController,
              maxLines: null,
              maxLength: 20,
              decoration: InputDecoration(hintText: 'Escribe una nota...'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                setState(() {
                  _photos[index]['note'] =
                      noteController.text; // Actualiza la nota
                });
                await _savePhotos();
                Navigator.of(context).pop(); // Cierra el diálogo
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _savePhotoToDevice(String path) async {
    if (_isStoragePermissionGranted) {
      try {
        // Guardar en la galería
        final result = await GallerySaver.saveImage(path);

        if (result != null && result) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Foto guardada en la galería.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al guardar la foto.')));
        }
      } catch (e) {
        print("Error al guardar la foto: $e");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al guardar la foto.')));
      }
    } else {
      _showStoragePermissionSnackbar();
    }
  }

  void _showStoragePermissionSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Permiso de almacenamiento denegado. Ve a configuración para aceptarlo.'),
        action: SnackBarAction(
          label: 'Configurar',
          onPressed: () async {
            await openAppSettings();
          },
        ),
      ),
    );
  }

  void _showPhotoOptions(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: _isLocationPermissionGranted
              ? Text('Ubicación: $_currentAddress')
              : Text(
                  'Debe aceptar el permiso de ubicación para ver la dirección.'),
          content: Text('¿Qué deseas hacer?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo de opciones
                _openNoteDialog(index); // Abre el diálogo de notas
              },
              child: Text('Escribir Nota'),
            ),
            TextButton(
              onPressed: () async {
                await _savePhotoToDevice(_photos[index]['path']!);
                Navigator.of(context).pop(); // Cierra el diálogo de opciones
              },
              child: Text('Guardar Foto'),
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
        title: Text('Galería de Fotos'),
        backgroundColor: Color(0xFFFDEFE9),
      ),
      backgroundColor: Color(0xFFFDEFE9),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isCameraPermissionGranted ? _takePhoto : null,
            child: Text('Tomar Foto'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor:
                  _isCameraPermissionGranted ? Color(0xFFFFC1B6) : Colors.grey,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showPhotoOptions(
                      index), // Muestra las opciones al tocar la foto
                  child: Column(
                    children: [
                      Image.file(
                        File(_photos[index]['path']!),
                        fit: BoxFit.cover,
                        height: 100,
                      ),
                      SizedBox(height: 5),
                      if (_photos[index]['note']!.isNotEmpty)
                        Container(
                          alignment: Alignment.center,
                          constraints: BoxConstraints(maxWidth: 100),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              _photos[index]['note']!,
                              style: TextStyle(fontSize: 12),
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                      SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
