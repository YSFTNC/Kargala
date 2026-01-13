// KOD BLOK BAŞLANGICI (ilan_harita_ekrani.dart - YENİ TASARIMLI PİN VE KART)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ilan_detay_tasiyici_ekrani.dart'; //
import 'package:flutter/services.dart' show rootBundle, ByteData, Uint8List; // <<< İkon yüklemek için
import 'dart:ui' as ui; // <<< İkon yüklemek için

// --- Mesafe Hesaplama Fonksiyonu (Aynı) ---
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = cos;
  var a = 0.5 -
      c((lat2 - lat1) * p) / 2 +
      c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a));
}
// --- Fonksiyon Sonu ---

class IlanHaritaEkrani extends StatefulWidget {
  const IlanHaritaEkrani({super.key});

  @override
  State<IlanHaritaEkrani> createState() => _IlanHaritaEkraniState();
}

class _IlanHaritaEkraniState extends State<IlanHaritaEkrani> {
  final Location _locationService = Location();
  GoogleMapController? _mapController;

  bool _isLoading = true;
  CameraPosition? _initialCameraPos;
  final Set<Marker> _markers = {};
  final double _filtreCapi = 10.0;

  // --- YENİ EKLENDİ: Özel Harita İkonu ---
  BitmapDescriptor _customMarkerIcon = BitmapDescriptor.defaultMarker;
  // --- YENİ EKLEME SONU ---

  @override
  void initState() {
    super.initState();
    // Ekran açılırken, hem konumu al hem de özel ikonumuzu hazırla
    _initializeMap();
  }
  
  // --- YENİ FONKSİYON: İkonu ve Konumu Yükle ---
  Future<void> _initializeMap() async {
    // 1. Özel ikonu yükle
    await _loadCustomMarkerIcon();
    
    // 2. Konumu al ve haritayı çiz
    await _kullaniciKonumunuAlVeIlanlariGetir();
  }

  // --- YENİ FONKSİYON: Elit İkonu Hazırla ---
  // (assets/logo.png dosyanızı geçici olarak ikon gibi kullanacağız,
  // bu daha sonra özel bir pin ikonuyla değiştirilebilir)
  // Bu fonksiyon, bir asset'i harita pin'ine dönüştürür
  Future<void> _loadCustomMarkerIcon() async {
    // Asset'ten resmi byte olarak oku
    final ByteData data = await rootBundle.load('assets/logo.png'); // Sizin logonuz
    // Byte'ları resim codec'i ile işle
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: 100, // İkonun boyutu (piksel)
      targetWidth: 100
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List resizedBytes = byteData!.buffer.asUint8List();

    if (mounted) {
      setState(() {
        _customMarkerIcon = BitmapDescriptor.fromBytes(resizedBytes);
      });
    }
  }
  // --- YENİ EKLEME SONU ---


  Future<void> _kullaniciKonumunuAlVeIlanlariGetir() async {
    // ... (Bu fonksiyonun try/catch/finally bloğu aynı)
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) throw Exception('GPS kapalı.');
      }
      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Konum izni reddedildi.');
        }
      }
      final locationData = await _locationService.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;
      if (lat == null || lng == null) {
        throw Exception('Konum verisi alınamadı.');
      }
      final userLocation = LatLng(lat, lng);
      _initialCameraPos = CameraPosition(
        target: userLocation,
        zoom: 12.0,
      );
      
      // Yakındaki ilanları getir (Değişiklik yok)
      await _yakindakiIlanlariGetir(userLocation);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata (Konum/İlan): ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _yakindakiIlanlariGetir(LatLng userLocation) async {
    // ... (Tüm ilanları çekme ve filtreleme kısmı aynı)
    print(">>> Tüm ilanlar getiriliyor... (Merkez: ${userLocation.latitude}, ${userLocation.longitude})");
    _markers.clear();
    final snapshot = await FirebaseFirestore.instance
        .collection('aktifIlanlar')
        .where('durum', isEqualTo: 'Aktif')
        .get();
    print(">>> ${snapshot.docs.length} adet 'Aktif' ilan bulundu. Filtreleniyor...");
    for (final doc in snapshot.docs) {
      final ilanVerisi = doc.data();
      final geoPoint = ilanVerisi['alinacakKonumGeoPoint'] as GeoPoint?;
      if (geoPoint == null) {
        print("XXX İlan ${doc.id} koordinatsız, atlanıyor.");
        continue; 
      }
      final double distance = _calculateDistance(
          userLocation.latitude, userLocation.longitude, geoPoint.latitude, geoPoint.longitude);

      if (distance <= _filtreCapi) {
        print(">>> EKLENDİ: ${doc.id} (Mesafe: ${distance.toStringAsFixed(1)} km)");
        
        // --- MARKER GÜNCELLENDİ ---
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(geoPoint.latitude, geoPoint.longitude),
            
            // 1. İKON GÜNCELLENDİ
            icon: _customMarkerIcon, // <<< Artık özel logo ikonunuz
            
            // 2. InfoWindow SİLİNDİ
            // infoWindow: InfoWindow(...), 
            
            // 3. 'onTap' GÜNCELLENDİ
            onTap: () {
              // Tıklayınca alttan özel kart göster
              _showIlanKarti(context, doc.id, ilanVerisi);
            },
          ),
        );
        // --- GÜNCELLEME SONU ---
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  // --- YENİ FONKSİYON: Pin'e Tıklayınca Alttan Açılan Kart ---
  void _showIlanKarti(BuildContext context, String ilanId, Map<String, dynamic> ilanVerisi) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext bContext) {
        // Alttaki kartı oluşturmak için yeni bir özel widget kullan
        return _IlanHaritaKarti(
          ilanId: ilanId,
          ilanVerisi: ilanVerisi,
        );
      },
    );
  }
  // --- YENİ FONKSİYON SONU ---

  @override
  Widget build(BuildContext context) {
    // ... (Build metodu aynı)
    return Scaffold(
      appBar: AppBar(
        title: Text('Yakındaki İlanlar (${_filtreCapi.toInt()} km)'),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Konumunuz alınıyor..."),
                ],
              ),
            )
          : GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: _initialCameraPos!,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _markers,
            ),
    );
  }
}


// --- YENİ WIDGET: Alttan Açılan İlan Kartı ---
// (Bu, ilan_karti.dart'taki tasarıma benzer)
class _IlanHaritaKarti extends StatelessWidget {
  final String ilanId;
  final Map<String, dynamic> ilanVerisi;
  
  const _IlanHaritaKarti({required this.ilanId, required this.ilanVerisi});

  @override
  Widget build(BuildContext context) {
    // Gerekli verileri oku
    final String alinacakAdres = ilanVerisi['alinacakAdres'] as String? ?? '...';
    final String teslimAdres = ilanVerisi['teslimAdres'] as String? ?? '...';
    final String paketBoyutu = ilanVerisi['paketBoyutu'] as String? ?? '-';
    final String teklif = (ilanVerisi['teklif'] as num? ?? 0).toStringAsFixed(0);
    final String gondericiId = ilanVerisi['kullaniciId'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // İçerik kadar yer kapla
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gönderici Bilgisi (FutureBuilder ile)
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('kullanicilar').doc(gondericiId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Text("Gönderici yükleniyor...");
              
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final gondericiAdi = ("${data['ad'] ?? ''} ${data['soyad'] ?? ''}").trim();
              final fotoUrl = data['profilFotoUrl'];
              
              return Row(children: [
                 CircleAvatar(
                   radius: 20, 
                   backgroundImage: (fotoUrl != null) ? NetworkImage(fotoUrl) : null, 
                   child: (fotoUrl == null) ? const Icon(Icons.person, size: 20) : null
                 ),
                 const SizedBox(width: 8),
                 Text(
                   gondericiAdi.isNotEmpty ? gondericiAdi : (data['email'] ?? 'Gönderici'), 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                 ),
              ]);
            }
          ),
          
          const Divider(height: 24),
          
          // 2. Rota (İkonlu)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trip_origin, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alinacakAdres, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 4, bottom: 4),
            child: Icon(Icons.more_vert, size: 16, color: Colors.grey[400]),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  teslimAdres, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 3. Fiyat ve Boyut
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                child: Text(
                  paketBoyutu.toUpperCase(), 
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)
                ),
              ),
              Text(
                '$teklif TL (Önerilen Fiyat)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF32D74B))
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 4. Eylem Butonu
          ElevatedButton(
            // (Bu butonun stili main.dart'taki temadan gelecek)
            onPressed: () {
              // Önce alttaki kartı kapat
              Navigator.of(context).pop();
              // Sonra asıl detay ekranına git
              Navigator.push(
                context, // Ana context'i kullan
                MaterialPageRoute(
                  builder: (context) => IlanDetayTasiyiciEkrani(
                    ilanVerisi: ilanVerisi,
                    ilanId: ilanId,
                  ),
                ),
              );
            },
            child: const Text('TEKLİF VERMEK İÇİN GİT'),
          ),
        ],
      ),
    );
  }
}
// --- YENİ WIDGET SONU ---