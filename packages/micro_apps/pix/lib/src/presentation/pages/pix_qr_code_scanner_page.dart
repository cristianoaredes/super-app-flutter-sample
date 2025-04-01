import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../bloc/pix_bloc.dart';
import '../bloc/pix_event.dart';
import '../bloc/pix_state.dart';


class PixQrCodeScannerPage extends StatefulWidget {
  const PixQrCodeScannerPage({super.key});

  @override
  State<PixQrCodeScannerPage> createState() => _PixQrCodeScannerPageState();
}

class _PixQrCodeScannerPageState extends State<PixQrCodeScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasScanned = false;
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
  
  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _hasScanned = true;
        });
        
        context.read<PixBloc>().add(
          ReadQrCodeEvent(payload: barcode.rawValue!),
        );
        
        break;
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ler QR Code Pix'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                }
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: BlocConsumer<PixBloc, PixState>(
        listener: (context, state) {
          if (state is PixQrCodeReadState) {
            
            Navigator.of(context).pop();
            Navigator.of(context).pushNamed('pix/send');
          } else if (state is PixQrCodeReadErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            
            setState(() {
              _hasScanned = false;
            });
          }
        },
        builder: (context, state) {
          if (state is PixQrCodeReadingState) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          return Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                ),
                child: CustomPaint(
                  painter: ScannerOverlayPainter(),
                  child: Container(),
                ),
              ),
              Positioned(
                bottom: 40.0,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: const Text(
                          'Posicione o QR Code dentro da área',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.7;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final double right = left + scanAreaSize;
    final double bottom = top + scanAreaSize;
    
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final scanAreaPath = Path()
      ..addRect(Rect.fromLTRB(left, top, right, bottom));
    
    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      scanAreaPath,
    );
    
    canvas.drawPath(
      finalPath,
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    
    
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    
    canvas.drawLine(
      Offset(left, top + 30),
      Offset(left, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + 30, top),
      borderPaint,
    );
    
    
    canvas.drawLine(
      Offset(right - 30, top),
      Offset(right, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + 30),
      borderPaint,
    );
    
    
    canvas.drawLine(
      Offset(left, bottom - 30),
      Offset(left, bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + 30, bottom),
      borderPaint,
    );
    
    
    canvas.drawLine(
      Offset(right - 30, bottom),
      Offset(right, bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - 30),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
