import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class RowingRouteImage extends StatefulWidget {
  final String fileName;
  const RowingRouteImage({super.key, required this.fileName});

  @override
  State<RowingRouteImage> createState() => _RowingRouteImageState();
}

class _RowingRouteImageState extends State<RowingRouteImage> {
  List<Offset> _pixelPoints = [];
  bool _isLoading = true;

  // These coordinates must match the edges of your screenshot precisely
  // Adjust these based on the area shown in Screenshot_2026-03-04_at_01.36.46.jpg
  static const double minLat = 51.890; // Bottom edge
  static const double maxLat = 51.905; // Top edge
  static const double minLon = -8.510; // Left edge
  static const double maxLon = -8.450; // Right edge

  @override
  void initState() {
    super.initState();
    _loadAndConvertData();
  }

  Future<void> _loadAndConvertData() async {
    final String rawData = await rootBundle.loadString('assets/rowing_data/${widget.fileName}');
    List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);

    List<Offset> points = [];
    for (var row in listData) {
      if (row.length >= 2) {
        double lon = double.parse(row[0].toString().replaceAll('[', ''));
        double lat = double.parse(row[1].toString().replaceAll(']', ''));

        // Convert GPS to 0.0 - 1.0 percentage scale
        double x = (lon - minLon) / (maxLon - minLon);
        double y = 1 - ((lat - minLat) / (maxLat - minLat)); // Flip Y for screen coords

        points.add(Offset(x, y));
      }
    }

    setState(() {
      _pixelPoints = points;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return AspectRatio(
      aspectRatio: 16 / 9, // Adjust to match your screenshot aspect ratio
      child: Stack(
        children: [
          // The Background Screenshot
          Positioned.fill(
            child: Image.asset(
              'assets/img/cork.png',
              fit: BoxFit.fill,
            ),
          ),
          // The Painted Path
          Positioned.fill(
            child: CustomPaint(
              painter: RowingPathPainter(_pixelPoints),
            ),
          ),
        ],
      ),
    );
  }
}

class RowingPathPainter extends CustomPainter {
  final List<Offset> points;
  RowingPathPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    // Convert percentages to actual pixel sizes
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(RowingPathPainter oldDelegate) => oldDelegate.points != points;
}
class StaticRowingMap extends StatelessWidget {
  const StaticRowingMap({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. The Hardcoded Background Image
        Positioned.fill(
          child: Image.asset(
            'assets/img/cork.png',
            fit: BoxFit.cover,
          ),
        ),
        // 2. The Hardcoded Path Overlay
      ]
    );
  }
}
