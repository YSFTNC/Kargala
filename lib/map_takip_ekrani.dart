// KOD BLOK BAŞLANGICI (map_takip_ekrani.dart - ETA ÖZELLİKLİ)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http; // API İsteği için

class MapTakipEkrani extends StatefulWidget {
  final String ilanId;
  final String ilanRotasi;

  const MapTakipEkrani({
    super.key,
    required this.ilanId,
    required this.ilanRotasi,
  });

  @override
  State<MapTakipEkrani> createState() => _MapTakipEkraniState();
}

class _MapTakipEkraniState extends State<MapTakipEkrani> {
  GoogleMapController? _mapController;
  
  // Google API Anahtarın (IlanOlusturmaEkrani'ndaki ile aynı olmalı)
  final String _googleApiKey = "AIzaSyAXGF_21o4hKqI4wYFbH9dz2dmZpKEo86M"; 

  // Harita Başlangıç
  static const CameraPosition _baslangicKonumu = CameraPosition(
    target: LatLng(39.9334, 32.8597), // Ankara
    zoom: 12,
  );
  
  bool _kameraOdaklandiMi = false;
  String _tahminiSure = "Hesaplanıyor...";
  String _kalanMesafe = "...";
  
  // API sorgusu çok sık gitmesin diye son sorgu zamanını tutalım
  DateTime? _sonSorguZamani;

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // --- YENİ: ETA HESAPLAMA FONKSİYONU ---
  Future<void> _etaHesapla(LatLng kuryeKonumu, LatLng hedefKonum) async {
    // Saniyede 1 kereden fazla sorgu atma (Kotayı korumak için)
    if (_sonSorguZamani != null && DateTime.now().difference(_sonSorguZamani!).inSeconds < 5) {
      return;
    }
    _sonSorguZamani = DateTime.now();

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=${kuryeKonumu.latitude},${kuryeKonumu.longitude}&destinations=${hedefKonum.latitude},${hedefKonum.longitude}&key=$_googleApiKey&language=tr"
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['rows'][0]['elements'][0]['status'] == 'OK') {
          final sure = data['rows'][0]['elements'][0]['duration']['text']; // "15 dk"
          final mesafe = data['rows'][0]['elements'][0]['distance']['text']; // "5.2 km"
          
          if (mounted) {
            setState(() {
              _tahminiSure = sure;
              _kalanMesafe = mesafe;
            });
          }
        }
      }
    } catch (e) {
      print("ETA Hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Canlı Takip', style: TextStyle(fontSize: 16)),
            Text(widget.ilanRotasi, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. HARİTA KATMANI
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('aktifIlanlar').doc(widget.ilanId).snapshots(),
            builder: (context, snapshot) {
              final Set<Marker> markers = {};
              LatLng? kuryeLatLng;
              LatLng? hedefLatLng;

              if (snapshot.hasData && snapshot.data!.exists) {
                final ilanVerisi = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                
                // Kurye Konumu
                final konumVerisi = ilanVerisi['tasiyiciAnlikKonum'] as Map<String, dynamic>?;
                if (konumVerisi != null) {
                  kuryeLatLng = LatLng(konumVerisi['latitude'], konumVerisi['longitude']);
                  markers.add(
                    Marker(
                      markerId: const MarkerId('kurye'),
                      position: kuryeLatLng,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      infoWindow: const InfoWindow(title: 'Kurye'),
                    ),
                  );
                }

                // Hedef Konumu (Teslim Adresi)
                final teslimGeo = ilanVerisi['teslimKonumGeoPoint'] as GeoPoint?;
                if (teslimGeo != null) {
                  hedefLatLng = LatLng(teslimGeo.latitude, teslimGeo.longitude);
                  markers.add(
                    Marker(
                      markerId: const MarkerId('hedef'),
                      position: hedefLatLng,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'Teslim Noktası'),
                    ),
                  );
                }

                // --- EĞER İKİSİ DE VARSA ETA HESAPLA ---
                if (kuryeLatLng != null && hedefLatLng != null) {
                  _etaHesapla(kuryeLatLng, hedefLatLng);
                  
                  // Kamerayı kuryeye odakla (sadece ilk seferde veya kullanıcı haritayı oynatmadıysa)
                  if (!_kameraOdaklandiMi && _mapController != null) {
                    _mapController!.animateCamera(
                       CameraUpdate.newCameraPosition(CameraPosition(target: kuryeLatLng, zoom: 15.0)),
                    );
                    _kameraOdaklandiMi = true;
                  }
                }
              }

              return GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: _baslangicKonumu,
                onMapCreated: _onMapCreated,
                markers: markers,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),

          // 2. BİLGİ KARTI KATMANI (ALT TARAFTA)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Sol Taraf: İkon ve Süre
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer, color: Colors.blue, size: 28),
                    ),
                    const SizedBox(width: 16),
                    
                    // Orta: Bilgiler
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Tahmini Varış",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Text(
                          _tahminiSure, // API'den gelen süre (örn: 15 dk)
                          style: const TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.black87
                          ),
                        ),
                        Text(
                          "Kalan Mesafe: $_kalanMesafe", // API'den gelen mesafe
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// KOD BLOK SONU