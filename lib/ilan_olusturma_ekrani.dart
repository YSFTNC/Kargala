// KOD BLOK BAŞLANGICI (ilan_olusturma_ekrani.dart - KONUM GÜNCELLEMESİ)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kargala/ilan_detay_ekrani.dart'; // <<< BU DOSYAYI DA BİR SONRAKİ ADIMDA GÜNCELLEYECEĞİZ
import 'package:uuid/uuid.dart';
import 'package:location/location.dart'; // <<< YENİ İMPORT

class IlanOlusturmaEkrani extends StatefulWidget {
  const IlanOlusturmaEkrani({super.key});

  @override
  State<IlanOlusturmaEkrani> createState() => _IlanOlusturmaEkraniState();
}

class _IlanOlusturmaEkraniState extends State<IlanOlusturmaEkrani> {
  final _alinacakAdresController = TextEditingController();
  final _teslimAdresController = TextEditingController();
  final String googleApiKey = "AIzaSyAXGF_21o4hKqI4wYFbH9dz2dmZpKEo86M"; // KENDİ ANAHTARINIZ (Mevcuttu)
  final _uuid = Uuid();
  String? _sessionToken;
  List<dynamic> _alinacakAdresOnerileri = [];
  List<dynamic> _teslimAdresOnerileri = [];
  bool _alinacakAdresFocus = false;
  bool _teslimAdresFocus = false;

  // --- YENİ EKLENEN DEĞİŞKENLER ---
  final Location _locationService = Location();
  bool _konumAliniyor = false; // "Konumumu Kullan" butonu için yüklenme durumu

  // Bu koordinatları bir sonraki ekrana (ilan_detay_ekrani) aktaracağız.
  double? _alinacakAdresLat;
  double? _alinacakAdresLng;
  double? _teslimAdresLat;
  double? _teslimAdresLng;
  // --- YENİ DEĞİŞKENLER SONU ---

  @override
  void initState() {
    super.initState();
    print(">>> initState: Listener'lar ekleniyor.");
    // Adres yazarken autocomplete'i tetikleyen listener'lar (Mevcuttu)
    _alinacakAdresController.addListener(() {
      if (_alinacakAdresFocus) _adresOnerileriniGetir(_alinacakAdresController.text, true);
    });
    _teslimAdresController.addListener(() {
      if (_teslimAdresFocus) _adresOnerileriniGetir(_teslimAdresController.text, false);
    });
    print(">>> initState: Listener'lar eklendi.");
  }

  @override
  void dispose() {
    _alinacakAdresController.dispose();
    _teslimAdresController.dispose();
    super.dispose();
  }

  // "Konumumu Kullan" butonuna basıldığında çalışır
  Future<void> _getCurrentLocationAndAddress() async {
    if (!mounted) return;
    setState(() => _konumAliniyor = true);

    try {
      // 1. Konum servisi (GPS) açık mı?
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          throw Exception('Konum servisi (GPS) kapalı.');
        }
      }

      // 2. Konum izni verilmiş mi?
      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Konum izni reddedildi.');
        }
      }

      // 3. Konumu al
      final locationData = await _locationService.getLocation();
      final lat = locationData.latitude;
      final lng = locationData.longitude;

      if (lat == null || lng == null) {
        throw Exception('Konum bilgisi alınamadı (null).');
      }

      // 4. Koordinatları Google'a gönderip adresi al (Reverse Geocoding)
      final adresMetni = await _getAddressFromCoords(lat, lng);

      // 5. Değişkenleri ve metin kutusunu güncelle
      if (mounted) {
        setState(() {
          _alinacakAdresLat = lat;
          _alinacakAdresLng = lng;
          _alinacakAdresController.text = adresMetni; // Adres metin kutusunu doldur
          _alinacakAdresOnerileri = []; // Öneri listesini temizle
          FocusScope.of(context).unfocus(); // Klavyeyi kapat
          _konumAliniyor = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _konumAliniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Konum hatası: ${e.toString()}')));
      }
    }
  }

  // Koordinatları (lat, lng) Google'a gönderip adres metni alan fonksiyon
  Future<String> _getAddressFromCoords(double lat, double lng) async {
    final url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$googleApiKey&language=tr";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        if (responseBody['status'] == 'OK' && responseBody['results'].isNotEmpty) {
          // Google'dan gelen ilk adres sonucunu (en olası) al
          return responseBody['results'][0]['formatted_address'] as String;
        } else {
          throw Exception('Adres bulunamadı: ${responseBody['status']}');
        }
      } else {
        throw Exception('Google Geocode API hatası: ${response.statusCode}');
      }
    } catch (e) {
      print("XXX _getAddressFromCoords Hata: $e");
      return "Adres dönüştürülemedi";
    }
  }
  
  // Autocomplete listesinden seçilen adresin 'placeId'sini Google'a gönderip koordinat alan fonksiyon
  Future<void> _getCoordsFromPlaceId(String placeId, bool isAlinacakAdres) async {
     final url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry/location&key=$googleApiKey";
     try {
       final response = await http.get(Uri.parse(url));
       if (response.statusCode == 200) {
         final responseBody = json.decode(response.body);
         if (responseBody['status'] == 'OK') {
            final location = responseBody['result']['geometry']['location'];
            final lat = location['lat'] as double?;
            final lng = location['lng'] as double?;
            
            if(lat != null && lng != null) {
              // Koordinatları state değişkenlerimize kaydediyoruz
               if(isAlinacakAdres) {
                  _alinacakAdresLat = lat;
                  _alinacakAdresLng = lng;
               } else {
                  _teslimAdresLat = lat;
                  _teslimAdresLng = lng;
               }
               print(">>> Koordinatlar alındı ($placeId): $lat, $lng");
            } else {
               throw Exception('Koordinatlar (lat/lng) null geldi.');
            }
         } else {
           throw Exception('Places Details API status: ${responseBody['status']}');
         }
       } else {
         throw Exception('Google Places Details API hatası: ${response.statusCode}');
       }
     } catch(e) {
        print("XXX _getCoordsFromPlaceId Hata: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Adres koordinatları alınamadı: $e')));
     }
  }

  // Bu fonksiyon mevcuttu, sadece listeyi temizlerken koordinatları da sıfırlamalıyız
  void _adresOnerileriniGetir(String input, bool isAlinacakAdres) async {
    // ... (Fonksiyonun içindeki http.get kısmı aynı) ...
    // Sadece koordinatları sıfırlama ekleyelim:
    if (input.length < 2) {
       // ... (mevcut kodunuz) ...
       setState(() {
          if (isAlinacakAdres) {
             _alinacakAdresOnerileri = [];
             _alinacakAdresLat = null; // <<< YENİ
             _alinacakAdresLng = null; // <<< YENİ
          } else {
             _teslimAdresOnerileri = [];
             _teslimAdresLat = null; // <<< YENİ
             _teslimAdresLng = null; // <<< YENİ
          }
       });
       return;
    }
    
    // ... (Geri kalan http istek ve response kısmı tamamen aynı) ...
    // --- BU KISIMIN MEVCUT HALİNE DOKUNMAYIN ---
    print('>>> Adres önerisi getiriliyor: "$input"');

    if (!mounted) return; // Widget ekrandan kaldırıldıysa işlem yapma

    if (_sessionToken == null) {
      print(">>> Yeni session token oluşturuluyor.");
      _sessionToken = _uuid.v4();
    }
    
    // ... (input.length < 2 kontrolü yukarıya taşındı) ...

    String url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$googleApiKey&sessiontoken=$_sessionToken&language=tr&components=country:tr";
    print('>>> Google API URL oluşturuldu: $url');

    try {
      print(">>> HTTP GET isteği gönderiliyor...");
      final response = await http.get(Uri.parse(url));
      print('>>> HTTP GET isteği tamamlandı. Status Code: ${response.statusCode}');

      if (!mounted) return; // İstek tamamlandığında widget hala ekranda mı?

      if (response.statusCode == 200) {
        print(">>> Cevap başarılı (200 OK). Body parse ediliyor...");
        final responseBody = json.decode(response.body);
        print('>>> Gelen Veri: $responseBody');

        if (responseBody['status'] == 'OK') {
          print(">>> Status OK. Öneriler güncelleniyor.");
          setState(() {
            final predictions = responseBody['predictions'];
            isAlinacakAdres ? _alinacakAdresOnerileri = predictions : _teslimAdresOnerileri = predictions;
          });
        } else {
           print('XXX Google Places API Hata Durumu: ${responseBody['status']} - ${responseBody['error_message']}');
           setState(() { 
              isAlinacakAdres ? _alinacakAdresOnerileri = [] : _teslimAdresOnerileri = [];
           });
        }

      } else {
        print('XXX Google Places API HTTP Hatası! Status: ${response.statusCode}, Body: ${response.body}');
         setState(() {
              isAlinacakAdres ? _alinacakAdresOnerileri = [] : _teslimAdresOnerileri = [];
         });
      }
    } catch (e) {
      print('XXX _adresOnerileriniGetir fonksiyonunda YAKALANAN HATA: $e');
       if(mounted){
         setState(() {
              isAlinacakAdres ? _alinacakAdresOnerileri = [] : _teslimAdresOnerileri = [];
         });
       }
    }
    // --- MEVCUT KODUN SONU ---
  }


  @override
  Widget build(BuildContext context) {
    print(">>> Build metodu çalışıyor.");
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('1/3: Nereden Nereye?', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- ALINACAK ADRES (KOMPLE GÜNCELLENDİ) ---
            Focus(
              onFocusChange: (hasFocus) {
                 print(">>> Alınacak Adres Focus Değişti: $hasFocus");
                 setState(() => _alinacakAdresFocus = hasFocus);
                 if (hasFocus) {
                    _sessionToken = _uuid.v4();
                    _alinacakAdresOnerileri = [];
                 }
              },
              child: TextField(
                controller: _alinacakAdresController,
                decoration: InputDecoration(
                  labelText: 'Alınacak Adres',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  // --- "Konumumu Kullan" Butonu Eklendi ---
                  suffixIcon: _konumAliniyor 
                    ? const Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _getCurrentLocationAndAddress, // <<< YENİ FONKSİYONA BAĞLANDI
                      ),
                  // --- Bitiş ---
                ),
              ),
            ),
            if (_alinacakAdresOnerileri.isNotEmpty && _alinacakAdresFocus)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _alinacakAdresOnerileri.length,
                    itemBuilder: (context, index) {
                      final suggestion = _alinacakAdresOnerileri[index]['description'];
                      final placeId = _alinacakAdresOnerileri[index]['place_id']; // <<< YENİ
                      
                      return ListTile(
                        title: Text(suggestion),
                        onTap: () {
                          print(">>> Öneriye tıklandı: $suggestion");
                          
                          // --- GÜNCELLENDİ: Hem metni ayarla hem koordinatı al ---
                          _getCoordsFromPlaceId(placeId, true); // <<< YENİ
                          setState(() {
                            _alinacakAdresController.text = suggestion;
                            _alinacakAdresOnerileri = [];
                            _sessionToken = null;
                            _alinacakAdresFocus = false;
                            FocusScope.of(context).unfocus();
                          });
                          // --- GÜNCELLEME SONU ---
                        },
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // --- TESLİM ADRES (Sadece ListView.builder güncellendi) ---
            Focus(
              onFocusChange: (hasFocus) {
                 print(">>> Teslim Adres Focus Değişti: $hasFocus");
                 setState(() => _teslimAdresFocus = hasFocus);
                 if (hasFocus) {
                    _sessionToken = _uuid.v4();
                    _teslimAdresOnerileri = [];
                 }
              },
              child: TextField(
                controller: _teslimAdresController,
                decoration: InputDecoration(
                  labelText: 'Teslim Edilecek Adres',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   suffixIcon: _teslimAdresOnerileri.isNotEmpty ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                          setState(() {
                              _teslimAdresController.clear();
                              _teslimAdresOnerileri = [];
                              _teslimAdresLat = null; // <<< YENİ
                              _teslimAdresLng = null; // <<< YENİ
                              FocusScope.of(context).unfocus();
                          });
                      },
                  ) : null,
                ),
              ),
            ),
            if (_teslimAdresOnerileri.isNotEmpty && _teslimAdresFocus)
              Expanded(
                child: Container(
                   decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: ListView.builder(
                     shrinkWrap: true,
                    itemCount: _teslimAdresOnerileri.length,
                    itemBuilder: (context, index) {
                       final suggestion = _teslimAdresOnerileri[index]['description'];
                       final placeId = _teslimAdresOnerileri[index]['place_id']; // <<< YENİ
                      
                       return ListTile(
                        title: Text(suggestion),
                        onTap: () {
                           print(">>> Öneriye tıklandı: $suggestion");
                           
                           // --- GÜNCELLENDİ: Hem metni ayarla hem koordinatı al ---
                           _getCoordsFromPlaceId(placeId, false); // <<< YENİ
                           setState(() {
                            _teslimAdresController.text = suggestion;
                            _teslimAdresOnerileri = [];
                            _sessionToken = null;
                            _teslimAdresFocus = false;
                            FocusScope.of(context).unfocus();
                           });
                           // --- GÜNCELLEME SONU ---
                        },
                      );
                    },
                  ),
                ),
              ),

             if (_alinacakAdresOnerileri.isEmpty && _teslimAdresOnerileri.isEmpty)
                const Spacer(),
            const SizedBox(height: 16),

            // --- DEVAM BUTONU (ŞİMDİLİK AYNI, BİR SONRAKİ ADIMDA GÜNCELLEMELİYİZ) ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF32D74B),
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                 final alinacakAdres = _alinacakAdresController.text;
                 final teslimAdres = _teslimAdresController.text;
                 
                 // KONTROL: Koordinatlar alındı mı?
                 if (alinacakAdres.isEmpty || teslimAdres.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen her iki adresi de seçin!')));
                    return;
                 }
                 if (_alinacakAdresLat == null || _teslimAdresLat == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adreslerin koordinatları alınamadı. Lütfen adresi listeden seçin veya konumunuzu kullanın.')));
                    return;
                 }
                 
                 print(">>> DEVAM: Alınacak: ($alinacakAdres) $_alinacakAdresLat, $_alinacakAdresLng");
                 print(">>> DEVAM: Teslim: ($teslimAdres) $_teslimAdresLat, $_teslimAdresLng");

                 // TODO: ŞİMDİ BU KOORDİNATLARI IlanDetayEkrani'na AKTARMAMIZ GEREKİYOR.
                 // Mevcut kodunuz bunu yapamıyor.
                 
                 if (context.mounted) {
                    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => IlanDetayEkrani(
      alinacakAdres: alinacakAdres,
      teslimAdres: teslimAdres,
      // --- YENİ EKLENDİ: Artık koordinatları da aktarıyoruz ---
      alinacakAdresLat: _alinacakAdresLat!,
      alinacakAdresLng: _alinacakAdresLng!,
      teslimAdresLat: _teslimAdresLat!,
      teslimAdresLng: _teslimAdresLng!,
                          // BİR SONRAKİ ADIMDA BURAYA KOORDİNATLARI EKLEYECEĞİZ
                          // alinacakAdresLat: _alinacakAdresLat!,
                          // alinacakAdresLng: _alinacakAdresLng!,
                          // teslimAdresLat: _teslimAdresLat!,
                          // teslimAdresLng: _teslimAdresLng!,
                        ),
                      ),
                    );
                 }
              },
              child: const Text('DEVAM'),
            ),
          ],
        ),
      ),
    );
  }
}
