// KOD BLOK BAŞLANGICI (main.dart - DİL DESTEKLİ NİHAİ SÜRÜM)
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart'; // <<< DİL PAKETİ
import 'firebase_options.dart';

// Ekranlar
import 'ana_ekran.dart';
import 'giris_ekrani.dart';
import 'email_onay_ekrani.dart';
import 'navigation_service.dart';
import 'teklifleri_gor_ekrani.dart';
import 'sohbet_ekrani.dart';
import 'profil_ekrani.dart';

// --- BİLDİRİM SANTRALİ (Arka Plan Handler) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print(">>> Arka Plan Bildirimi (Handler) yakaladı: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i Başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Dil Sistemini Başlat
  await EasyLocalization.ensureInitialized();
  
  // Arka plan bildirim dinleyicisini ayarla
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(
    // Uygulamayı Dil Yöneticisi ile sarıyoruz
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations', // Dil dosyalarının yolu
      fallbackLocale: const Locale('tr'), // Varsayılan dil
      child: const KargalaApp(),
    ),
  );
}

class KargalaApp extends StatefulWidget {
  const KargalaApp({super.key});

  @override
  State<KargalaApp> createState() => _KargalaAppState();
}

class _KargalaAppState extends State<KargalaApp> {

  @override
  void initState() {
    super.initState();
    _bildirimSisteminiKur(); // "Santrali" çalıştır
  }

  // --- BİLDİRİM SANTRALİ FONKSİYONLARI ---
  Future<void> _bildirimSisteminiKur() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // İzin İste (iOS için özellikle gerekli)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 1. Uygulama KAPALIYKEN (Terminated) açıldıysa:
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print(">>> Uygulama KAPALIYDI, bildirimle açıldı: ${initialMessage.data}");
      Future.delayed(const Duration(seconds: 1), () {
         _bildirimiYonlendir(initialMessage);
      });
    }

    // 2. Uygulama ARKA PLANDAYKEN açıldıysa:
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print(">>> Uygulama ARKA PLANDAYDI, bildirimle açıldı: ${message.data}");
      _bildirimiYonlendir(message);
    });

    // 3. Uygulama AÇIKKEN (Foreground) bildirim gelirse:
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(">>> Uygulama AÇIKKEN bildirim geldi: ${message.notification?.title}");
      
      // Bildirimi Snackbar ile göster (Dil desteği yoksa varsayılan metin)
      if (message.notification != null && NavigationService.navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(NavigationService.navigatorKey.currentContext!)
          .showSnackBar(SnackBar(
             content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.notification?.title ?? "Yeni Bildirim", style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(message.notification?.body ?? ""),
                ],
             ),
             backgroundColor: const Color(0xFF32D74B), // Ana renk
             behavior: SnackBarBehavior.floating,
             margin: const EdgeInsets.all(10),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
      }
    });
  }

  // --- YÖNLENDİRME FONKSİYONU ---
  void _bildirimiYonlendir(RemoteMessage message) async {
    final data = message.data;
    final navigator = NavigationService.navigatorKey.currentState;
    
    if (navigator == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !currentUser.emailVerified) return;

    try {
      final String type = data['type'] ?? '';
      final String ilanId = data['ilanId'] ?? '';
      
      if (ilanId.isEmpty) return;
      
      // İlan verisini çek
      final doc = await FirebaseFirestore.instance.collection('aktifIlanlar').doc(ilanId).get();
      if (!doc.exists) return;
      
      final ilanVerisi = doc.data() as Map<String, dynamic>;
      final gondericiId = ilanVerisi['kullaniciId'] as String?;
      
      if (type == 'offer') {
        // Teklif Geldi -> Teklifleri Gör
        navigator.push(MaterialPageRoute(
          builder: (_) => TeklifleriGorEkrani(ilanId: ilanId, ilanVerisi: ilanVerisi),
        ));
      } 
      else if (type == 'chat' || type == 'agreement' || type == 'rating') {
        // Mesaj/Anlaşma -> Sohbet
        final tasiyiciId = ilanVerisi['tasiyiciId'] as String?;
        
        if(gondericiId != null && tasiyiciId != null) {
           final digerKullaniciId = (currentUser.uid == gondericiId) ? tasiyiciId : gondericiId;
           final userDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(digerKullaniciId).get();
           final userData = userDoc.data() as Map<String, dynamic>? ?? {};
           final konusulanKisiAdi = ("${userData['ad'] ?? ''} ${userData['soyad'] ?? ''}").trim();

           navigator.push(MaterialPageRoute(
              builder: (_) => SohbetEkrani(
                ilanId: ilanId,
                gondericiId: gondericiId,
                tasiyiciId: tasiyiciId,
                konusulanKisiAdi: konusulanKisiAdi.isNotEmpty ? konusulanKisiAdi : (userData['email'] ?? 'Kullanıcı'),
              ),
           ));
        }
      }
      else if (type == 'profile') {
        // Puanlama -> Profil
        navigator.push(MaterialPageRoute(builder: (_) => const ProfilEkrani()));
      }

    } catch (e) {
      print("XXX Bildirim yönlendirme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- TEMA AYARLARI ---
    final ThemeData theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF32D74B),
        primary: const Color(0xFF32D74B),
        secondary: Colors.blue,
        background: Colors.white,
        surface: Colors.grey[50],
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF212121),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF32D74B),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF212121),
          side: const BorderSide(color: Color(0xFF212121)),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: Colors.grey[600]),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF32D74B), width: 2.0),
        ),
      ),
    );

    return MaterialApp(
      title: 'Kargala',
      debugShowCheckedModeBanner: false,
      theme: theme,
      
      // --- DİL AYARLARI BURAYA BAĞLANIYOR ---
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // --------------------------------------

      // Navigasyon Anahtarı
      navigatorKey: NavigationService.navigatorKey, 
      
      // "Bekçi" (AuthGate)
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          // 1. Giriş yapılmış mı?
          if (snapshot.hasData && snapshot.data != null) {
            // 2. E-posta onaylı mı?
            if (snapshot.data!.emailVerified) {
              return AnaEkran(currentUser: snapshot.data!);
            } else {
              return const EmailOnayEkrani(); 
            }
          } else {
            return const GirisEkrani();
          }
        },
      ),
    );
  }
}
// KOD BLOK SONU