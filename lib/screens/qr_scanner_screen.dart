import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QrScannerScreen extends StatefulWidget {
  final String ilanId;
  final String gercekKod; // Veritabanındaki doğru kod

  const QrScannerScreen({Key? key, required this.ilanId, required this.gercekKod}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool isScanCompleted = false; // Çift okumayı engellemek için

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("QR Kodu Tara")),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
        ),
        onDetect: (capture) {
          if (!isScanCompleted) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final String? okunanKod = barcode.rawValue;
              
              if (okunanKod != null) {
                // KOD BULUNDU, KONTROL EDİYORUZ
                debugPrint('QR Okundu: $okunanKod');
                _dogrulaVeBitir(okunanKod);
              }
            }
          }
        },
      ),
    );
  }

  void _dogrulaVeBitir(String okunanKod) async {
    setState(() {
      isScanCompleted = true; // Taramayı durdur
    });

    if (okunanKod == widget.gercekKod) {
      // --- DOĞRU EŞLEŞME ---
      
      // 1. Veritabanını güncelle
      await FirebaseFirestore.instance.collection('aktifIlanlar').doc(widget.ilanId).update({
        'durum': 'Tamamlandı',
        'tamamlanmaTarihi': FieldValue.serverTimestamp(),
      });

      // 2. Kullanıcıya bilgi ver ve sayfayı kapat
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Teslimat Doğrulandı! İşlem Başarılı.")),
        );
        Navigator.pop(context); // Scanner'dan çık
        Navigator.pop(context); // Teslimat ekranından çık (Ana sayfaya dön)
      }
    } else {
      // --- YANLIŞ KOD ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Hatalı QR Kod! Lütfen doğru kodu taratın."), backgroundColor: Colors.red),
        );
        // Hatalıysa tekrar taramaya izin ver
        Future.delayed(Duration(seconds: 2), () {
          setState(() {
            isScanCompleted = false;
          });
        });
      }
    }
  }
}