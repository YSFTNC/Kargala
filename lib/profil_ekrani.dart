// KOD BLOK BAŞLANGICI (profil_ekrani.dart - AYARLAR İKONU EKLENDİ)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'yayinladigim_ilanlar_ekrani.dart'; 
import 'gorevlerim_ekrani.dart'; 
import 'is_gecmisim_ekrani.dart'; 
import 'giris_ekrani.dart'; 
import 'degerlendirmeler_ekrani.dart'; 
import 'ayarlar_ekrani.dart'; // <<< YENİ İMPORT (Birazdan oluşturacağız)


class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({super.key});

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  // ... (initState ve diğer tüm fonksiyonlarınız aynı kalıyor) ...
  User? user;
  String? _profilFotoUrl;
  bool _fotoYukleniyor = false;
  String? _adSoyad;
  double _ortalamaPuan = 0.0;
  int _degerlendirmeSayisi = 0;
  bool _puanYukleniyor = true;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
       _profilBilgileriniGetir();
    }
  }

  Future<void> _profilBilgileriniGetir() async {
    // ... (Bu fonksiyonun içi olduğu gibi aynı kalıyor)
    if (user == null || !mounted) return;
    setState(() => _puanYukleniyor = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user!.uid).get();
      if (mounted && userDoc.exists) {
         final userData = userDoc.data()!;
         _profilFotoUrl = userData['profilFotoUrl'] as String?;
         _adSoyad = "${userData['ad'] ?? ''} ${userData['soyad'] ?? ''}".trim();
      }

      final tumDegerlendirmelerSnapshot = await FirebaseFirestore.instance
           .collection('kullanicilar').doc(user!.uid).collection('aldigi_degerlendirmeler').get();
       _degerlendirmeSayisi = tumDegerlendirmelerSnapshot.docs.length;

       if (_degerlendirmeSayisi > 0) {
           double toplamPuan = 0;
           for (var doc in tumDegerlendirmelerSnapshot.docs) {
                toplamPuan += (doc.data()['puan'] as num? ?? 0);
           }
            _ortalamaPuan = toplamPuan / _degerlendirmeSayisi;
       } else {
            _ortalamaPuan = 0.0;
       }
       if (mounted) setState(() => _puanYukleniyor = false);
    } catch (e) {
       print("Profil bilgileri getirilirken hata: $e");
       if (mounted) { setState(() { _puanYukleniyor = false; }); }
    }
  }

  Future<void> _profilFotografiSecVeYukle() async {
    // ... (Bu fonksiyonun içi olduğu gibi aynı kalıyor)
    var status = await Permission.photos.status;
    if (status.isDenied) {
      status = await Permission.photos.request();
    }

    if (status.isPermanentlyDenied) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Galeri izni reddedildi. Lütfen ayarlardan izin verin.')));
       openAppSettings(); 
       return;
    }
    
    if (status.isGranted) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image == null || user == null || !mounted) return;

      setState(() => _fotoYukleniyor = true);
      try {
        final ref = FirebaseStorage.instance.ref().child('profil_resimleri').child('${user!.uid}.jpg');
        final uploadTask = ref.putFile(File(image.path));
        final snapshot = await uploadTask.whenComplete(() => {});
        
        if (snapshot.state == TaskState.success) {
          final url = await ref.getDownloadURL();
          await FirebaseFirestore.instance.collection('kullanicilar').doc(user!.uid).update({'profilFotoUrl': url});
          await user!.updatePhotoURL(url); 
          
          if (mounted) {
            setState(() { _profilFotoUrl = url; _fotoYukleniyor = false; });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil fotoğrafı güncellendi!')));
          }
        } else { throw Exception("Yükleme başarısız: ${snapshot.state}"); }
      } catch (e) {
         if (mounted) {
           setState(() => _fotoYukleniyor = false);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf yüklenemedi: ${e.toString()}')));
         }
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Galeri izni vermeniz gerekiyor.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
  
       Future.microtask(() {
         if (mounted) {
            Navigator.of(context).pushAndRemoveUntil( MaterialPageRoute(builder: (context) => const GirisEkrani()), (route) => false);
         }
       });
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
     }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF212121),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Profilim', style: TextStyle(color: Colors.white)),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Yeni oluşturacağımız Ayarlar Ekranı'na git
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AyarlarEkrani()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _profilBilgileriniGetir,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    child: _fotoYukleniyor
                      ? const CircularProgressIndicator()
                      : (_profilFotoUrl != null && _profilFotoUrl!.isNotEmpty)
                          ? ClipOval( child: Image.network( _profilFotoUrl!, fit: BoxFit.cover, width: 120, height: 120, errorBuilder: (c,o,s) => const Icon(Icons.person, size: 70, color: Colors.grey) ))
                          : const Icon(Icons.person, size: 70, color: Colors.grey),
                  ),
                  if (!_fotoYukleniyor)
                    Positioned(
                       child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFF32D74B),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                              onPressed: _profilFotografiSecVeYukle,
                            ),
                          ),
                       ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text(_adSoyad ?? user!.email ?? '...', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            if (_adSoyad != null && _adSoyad!.isNotEmpty) Center(child: Text(user!.email ?? '', style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
            const Divider(height: 40),

            if (_puanYukleniyor)
               const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: CircularProgressIndicator(strokeWidth: 2)))
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.star, color: Colors.amber, size: 30),
                title: Text(
                  _ortalamaPuan.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('$_degerlendirmeSayisi değerlendirme', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  if (context.mounted) {
                     Navigator.push(
                       context,
                       MaterialPageRoute(builder: (context) => DegerlendirmelerEkrani(
                          kullaniciId: user!.uid,
                          ortalamaPuan: _ortalamaPuan,
                          degerlendirmeSayisi: _degerlendirmeSayisi,
                       )),
                     );
                  }
                },
              ),
            
             const Divider(),
             ListTile(
               leading: const Icon(Icons.list_alt),
               title: const Text('Yayınladığım İlanlar'), 
               trailing: const Icon(Icons.chevron_right),
               onTap: () {
                 if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const YayinladigimIlanlarEkrani()));
               },
             ),
             ListTile(
               leading: const Icon(Icons.delivery_dining_rounded), 
               title: const Text('Aktif Görevlerim'), 
               trailing: const Icon(Icons.chevron_right),
               onTap: () {
                 if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const GorevlerimEkrani()));
               },
             ),
             ListTile(
               leading: const Icon(Icons.history_toggle_off), 
               title: const Text('İş Geçmişim'), 
               trailing: const Icon(Icons.chevron_right),
               onTap: () {
                 if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const IsGecmisimEkrani()));
               },
             ),

             const Divider(),
             ListTile(
               leading: const Icon(Icons.logout, color: Colors.red),
               title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
               onTap: () async {
                 final bool? cikisOnayi = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                        return AlertDialog(
                           title: const Text('Onay'),
                           content: const Text('Çıkış yapmak istediğinize emin misiniz?'),
                           actions: <Widget>[
                              TextButton(child: const Text('Hayır'), onPressed: () => Navigator.of(dialogContext).pop(false)),
                              TextButton(child: const Text('Evet'), onPressed: () => Navigator.of(dialogContext).pop(true)),
                           ],
                        );
                    },
                 );
                 if (cikisOnayi == true && context.mounted) {
                   await FirebaseAuth.instance.signOut();
                   Navigator.of(context).pushAndRemoveUntil(
                     MaterialPageRoute(builder: (context) => const GirisEkrani()),
                     (Route<dynamic> route) => false,
                   );
                 }
               },
             ),
          ],
        ),
      ),
    );
  }
}
// KOD BLOK SONU