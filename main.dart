import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_editor/emojis.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html;

void main() {
  runApp(const VideoEditorApp());
}

class VideoEditorApp extends StatelessWidget {
  const VideoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Editor',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        cardColor: const Color(0xFF2D2D2D),
      ),
      home: const VideoEditorScreen(),
    );
  }
}

// คลาสเก็บข้อมูลองค์ประกอบที่เพิ่มในวิดีโอ
class VideoElement {
  final String id;
  String type; // 'text', 'icon', 'sticker'
  String content;
  Offset position;
  double size;
  Color color;
  double rotation;
  Duration startTime;
  Duration duration;
  bool isVisible;

  VideoElement({
    required this.id,
    required this.type,
    required this.content,
    required this.position,
    this.size = 32,
    this.color = Colors.white,
    this.rotation = 0,
    required this.startTime,
    required this.duration,
    this.isVisible = true,
  });

  VideoElement copyWith({
    String? type,
    String? content,
    Offset? position,
    double? size,
    Color? color,
    double? rotation,
    Duration? startTime,
    Duration? duration,
    bool? isVisible,
  }) {
    return VideoElement(
      id: id,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

// เพิ่ม class สำหรับจัดการ responsive breakpoints
class ResponsiveBreakpoints {
  static const double desktop = 1200;
  static const double tablet = 768;
  static const double mobile = 480;
}

// สร้าง extension เพื่อเช็ค screen size
extension ResponsiveContext on BuildContext {
  bool get isMobile =>
      MediaQuery.of(this).size.width < ResponsiveBreakpoints.tablet;
  bool get isTablet =>
      MediaQuery.of(this).size.width >= ResponsiveBreakpoints.tablet &&
      MediaQuery.of(this).size.width < ResponsiveBreakpoints.desktop;
  bool get isDesktop =>
      MediaQuery.of(this).size.width >= ResponsiveBreakpoints.desktop;
}

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _videoController;
  List<VideoElement> _elements = [];
  VideoElement? _selectedElement;
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  double _timelineScale = 1.0;
  bool _isProcessing = false;

  // ไอคอนพื้นฐาน
  final List<IconData> _basicIcons = [
    Icons.favorite,
    Icons.star,
    Icons.emoji_emotions,
    Icons.cake,
    Icons.music_note,
    Icons.local_fire_department,
    Icons.celebration,
    Icons.pets,
  ];

  // สติกเกอร์อิโมจิ
  final List<String> _basicEmojis = Emojis.basicEmojis;

  // สีพื้นฐาน
  final List<Color> _basicColors = [
    Colors.white,
    Colors.grey.shade300,
    Colors.grey.shade600,
    Colors.black,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
  ];

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final blob = html.Blob([file.bytes!]);
          final url = html.Url.createObjectUrlFromBlob(blob);

          _videoController?.dispose();

          setState(() {
            _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
            _elements = [];
            _selectedElement = null;
            _currentPosition = Duration.zero;
          });

          await _initializeVideoPlayer();
        }
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoController != null) {
      try {
        await _videoController!.initialize();
        _videoController!.addListener(_videoListener);
        setState(() {});
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && mounted) {
      setState(() {
        _currentPosition = _videoController!.value.position;
        _updateElementsVisibility();
      });
    }
  }

  void _updateElementsVisibility() {
    for (var element in _elements) {
      final endTime = element.startTime + element.duration;
      element.isVisible =
          _currentPosition >= element.startTime && _currentPosition <= endTime;
    }
  }

  void _addElement(String type, {String? content}) {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    try {
      final totalDuration = _videoController!.value.duration;
      final remainingDuration = totalDuration - _currentPosition;

      // ตั้งค่าความยาวเริ่มต้นเป็น 3 วินาที หรือเวลาที่เหลือถ้าน้อยกว่า
      final defaultDuration = Duration(seconds: 3);
      final elementDuration = remainingDuration < defaultDuration
          ? remainingDuration
          : defaultDuration;

      final element = VideoElement(
        id: DateTime.now().toString(),
        type: type,
        content: content ?? 'New Element',
        position: const Offset(100, 100),
        startTime: _currentPosition,
        duration: elementDuration,
      );

      setState(() {
        _elements.add(element);
        _selectedElement = element;
      });
    } catch (e) {
      debugPrint('Error adding element: $e');
    }
  }

  Widget _buildTimeline() {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return const SizedBox();

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(
          top: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      child: Column(
        children: [
          _buildTimelineToolbar(),
          _buildTimelineSlider(),
          Expanded(
            child: ListView.builder(
              itemCount: _elements.length,
              itemBuilder: (context, index) {
                return _buildTimelineTrack(_elements[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineToolbar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isPlaying = !_isPlaying;
                if (_isPlaying) {
                  _videoController?.play();
                } else {
                  _videoController?.pause();
                }
              });
            },
          ),
          Text(_formatDuration(_currentPosition)),
          const SizedBox(width: 8),
          Text('/'),
          const SizedBox(width: 8),
          Text(_formatDuration(
              _videoController?.value.duration ?? Duration.zero)),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _timelineScale *= 1.2;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _timelineScale /= 1.2;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.blue,
        inactiveTrackColor: Colors.grey.shade800,
        thumbColor: Colors.white,
        trackHeight: 4,
      ),
      child: Slider(
        value: _currentPosition.inMilliseconds.toDouble(),
        min: 0,
        max: _videoController?.value.duration.inMilliseconds.toDouble() ?? 0,
        onChanged: (value) {
          final newPosition = Duration(milliseconds: value.toInt());
          _videoController?.seekTo(newPosition);
          setState(() {
            _currentPosition = newPosition;
          });
        },
      ),
    );
  }

  Widget _buildTimelineTrack(VideoElement element) {
    if (_videoController == null) return const SizedBox();

    final totalDuration =
        _videoController!.value.duration.inMilliseconds.toDouble();
    final trackWidth = totalDuration * _timelineScale;
    final startPosition = element.startTime.inMilliseconds * _timelineScale;
    final elementWidth = element.duration.inMilliseconds * _timelineScale;

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          Positioned(
            left: startPosition,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _selectedElement = element),
              child: Container(
                width: elementWidth,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  border: Border.all(
                    color: _selectedElement == element
                        ? Colors.blue
                        : Colors.blue.withOpacity(0.5),
                    width: _selectedElement == element ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    element.type == 'text'
                        ? element.content
                        : element.type == 'icon'
                            ? '🎯'
                            : '🌟',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementTools() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'เพิ่มองค์ประกอบ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.text_fields),
                  label: const Text('ข้อความ'),
                  onPressed: _videoController != null
                      ? () => _addElement('text')
                      : null,
                ),
                /*ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_emotions),
                  label: const Text('ไอคอน'),
                  onPressed:
                      _videoController != null ? () => _showIconPicker() : null,
                ),*/
                ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_emotions),
                  label: const Text('สติกเกอร์'),
                  onPressed: _videoController != null
                      ? () => _showStickerPicker()
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showIconPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกไอคอน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _basicIcons.map((icon) {
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _addElement('icon', content: icon.codePoint.toString());
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStickerPicker() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'เลือกสติกเกอร์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _basicEmojis.map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _addElement('sticker', content: emoji);
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 30),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElementProperties() {
    if (_selectedElement == null) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('เลือกองค์ประกอบเพื่อแก้ไข'),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'แก้ไขคุณสมบัติ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedElement = null),
                ),
              ],
            ),
            const Divider(),
            if (_selectedElement!.type == 'text') ...[
              const Text('ข้อความ:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller:
                    TextEditingController(text: _selectedElement!.content),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedElement!.content = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text('สี:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _basicColors.map((color) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedElement!.color = color;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: _selectedElement!.color == color
                            ? Colors.blue
                            : Colors.grey,
                        width: _selectedElement!.color == color ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        if (_selectedElement!.color == color)
                          const BoxShadow(
                            color: Colors.blue,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('ขนาด:', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: _selectedElement!.size,
                    min: 12,
                    max: 72,
                    onChanged: (value) {
                      setState(() {
                        _selectedElement!.size = value;
                      });
                    },
                  ),
                ),
                Text('${_selectedElement!.size.round()}'),
              ],
            ),
            if (_videoController != null) ...[
              const Divider(),
              const Text('ระยะเวลา:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'เริ่ม: ${_formatDuration(_selectedElement!.startTime)}'),
                  Text(
                      'จบ: ${_formatDuration(_selectedElement!.startTime + _selectedElement!.duration)}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('เริ่ม:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value:
                          _selectedElement!.startTime.inMilliseconds.toDouble(),
                      min: 0,
                      max: _videoController!.value.duration.inMilliseconds
                          .toDouble(),
                      onChanged: (value) {
                        final newStart = Duration(milliseconds: value.toInt());
                        if (newStart + _selectedElement!.duration <=
                            _videoController!.value.duration) {
                          setState(() {
                            _selectedElement!.startTime = newStart;
                          });
                          _videoController?.seekTo(newStart);
                        }
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('ความยาว:', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value:
                          _selectedElement!.duration.inMilliseconds.toDouble(),
                      min: 500,
                      max: (_videoController!.value.duration -
                              _selectedElement!.startTime)
                          .inMilliseconds
                          .toDouble(),
                      onChanged: (value) {
                        setState(() {
                          _selectedElement!.duration =
                              Duration(milliseconds: value.toInt());
                        });
                      },
                    ),
                  ),
                  Text(_formatDuration(_selectedElement!.duration)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('ลบ'),
                  onPressed: () {
                    setState(() {
                      _elements.remove(_selectedElement);
                      _selectedElement = null;
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('คัดลอก'),
                  onPressed: () {
                    final copy = VideoElement(
                      id: DateTime.now().toString(),
                      type: _selectedElement!.type,
                      content: _selectedElement!.content,
                      position:
                          _selectedElement!.position + const Offset(20, 20),
                      size: _selectedElement!.size,
                      color: _selectedElement!.color,
                      startTime: _selectedElement!.startTime,
                      duration: _selectedElement!.duration,
                    );
                    setState(() {
                      _elements.add(copy);
                      _selectedElement = copy;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // ฟังก์ชันแปลงสีเป็น CSS
  String _colorToCss(Color color) {
    return 'rgba(${color.red},${color.green},${color.blue},${color.opacity})';
  }

  Future<void> _saveVideo() async {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // สร้าง canvas สำหรับ render วิดีโอ
      final canvas = html.CanvasElement(
        width: _videoController!.value.size.width.toInt(),
        height: _videoController!.value.size.height.toInt(),
      );
      final ctx = canvas.getContext('2d') as html.CanvasRenderingContext2D;

      // สร้าง video element
      final videoElement = html.VideoElement()
        ..src = _videoController!.dataSource
        ..autoplay = false;

      await videoElement.onLoadedData.first;

      // ดึง VideoStream จาก canvas
      final videoStream = canvas.captureStream(30); // 30 FPS

      // ดึง AudioStream จาก video element
      final audioStream = videoElement.captureStream();
      final audioTracks = audioStream.getAudioTracks();

      // เพิ่ม AudioTrack เข้าไปใน VideoStream
      if (audioTracks.isNotEmpty) {
        videoStream.addTrack(audioTracks[0]);
      }

      // ตั้งค่า MediaRecorder พร้อมทั้ง video และ audio
      final mediaRecorder = html.MediaRecorder(videoStream, {
        'mimeType':
            'video/webm;codecs=vp9,opus', // เพิ่ม opus codec สำหรับเสียง
        'videoBitsPerSecond': 5000000,
        'audioBitsPerSecond': 128000, // bit rate สำหรับเสียง
      });

      final chunks = <html.Blob>[];
      mediaRecorder.addEventListener('dataavailable', (event) {
        final blob = (event as html.BlobEvent).data;
        if (blob != null) {
          chunks.add(blob);
        }
      });

      mediaRecorder.addEventListener('stop', (_) {
        final blob = html.Blob(chunks, 'video/webm');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..download = 'edited_video.webm'
          ..click();
        html.Url.revokeObjectUrl(url);

        // Clean up
        audioTracks.forEach((track) => track.stop());

        setState(() {
          _isProcessing = false;
        });
      });

      // เริ่มบันทึก
      mediaRecorder.start();
      videoElement.currentTime = 0;
      await videoElement.onSeeked.first;
      videoElement.play();

      // Process video frames
      Timer.periodic(const Duration(milliseconds: 33), (timer) {
        if (videoElement.ended) {
          timer.cancel();
          mediaRecorder.stop();
          return;
        }

        ctx.drawImage(videoElement, 0, 0);

        // วาดองค์ประกอบที่ active ในเฟรมปัจจุบัน
        final currentTime =
            Duration(milliseconds: (videoElement.currentTime * 1000).toInt());
        for (final element in _elements) {
          if (currentTime >= element.startTime &&
              currentTime <= element.startTime + element.duration) {
            // วาดตามประเภทขององค์ประกอบ
            switch (element.type) {
              case 'text':
                ctx.font = '${element.size}px Arial';
                ctx.fillStyle = _colorToCss(element.color);
                ctx.strokeStyle = 'rgba(0,0,0,0.5)';
                ctx.lineWidth = 2;
                // วาดเงาข้อความ
                ctx.strokeText(
                    element.content, element.position.dx, element.position.dy);
                // วาดข้อความ
                ctx.fillText(
                    element.content, element.position.dx, element.position.dy);
                break;

              case 'sticker':
                ctx.font = '${element.size}px Arial';
                ctx.fillStyle = _colorToCss(element.color);
                ctx.fillText(
                    element.content, element.position.dx, element.position.dy);
                break;

              case 'icon':
                // หมายเหตุ: การวาดไอคอนบน canvas ต้องการการจัดการที่ซับซ้อนกว่านี้
                break;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Error saving video: $e');
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกวิดีโอ: $e')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Video Editor'),
      actions: [
        if (_videoController != null) ...[
          if (_isProcessing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'บันทึกวิดีโอ',
              onPressed: _saveVideo,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // เลือก layout ตาม screen size
          if (context.isMobile) {
            return _buildMobileLayout();
          } else if (context.isTablet) {
            return _buildDesktopLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }

  Widget _buildVideoArea() {
    return Stack(
      children: [
        if (_videoController != null)
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        // Elements overlay
        if (_videoController != null)
          Positioned.fill(
            child: Stack(
              children: _elements.where((e) => e.isVisible).map((element) {
                return Positioned(
                  left: element.position.dx,
                  top: element.position.dy,
                  child: GestureDetector(
                    onTapDown: (_) =>
                        setState(() => _selectedElement = element),
                    onPanUpdate: (details) {
                      setState(() {
                        element.position += details.delta;
                      });
                    },
                    child: Transform.rotate(
                      angle: element.rotation * 3.14159 / 180,
                      child: _buildElement(element),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (_videoController == null)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.video_library),
              label: Text(
                'เลือกวิดีโอ',
                style: TextStyle(
                  fontSize: context.isMobile ? 14 : 16,
                ),
              ),
              onPressed: _pickVideo,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Video Area
        Expanded(
          flex: 2,
          child: _buildVideoArea(),
        ),
        // Controls in a bottom sheet
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildElementTools(),
                _buildElementProperties(),
                if (_videoController != null) _buildTimeline(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // พื้นที่แสดงวิดีโอ
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.1,
              ),
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    if (_videoController != null)
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    // แสดง elements ที่ active
                    ..._elements.where((e) => e.isVisible).map((element) {
                      return Positioned(
                        left: element.position.dx,
                        top: element.position.dy,
                        child: GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _selectedElement = element),
                          onPanUpdate: (details) {
                            setState(() {
                              element.position += details.delta;
                            });
                          },
                          child: Transform.rotate(
                            angle: element.rotation * 3.14159 / 180,
                            child: _buildElement(element),
                          ),
                        ),
                      );
                    }).toList(),
                    if (_videoController == null)
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.video_library),
                          label: const Text('เลือกวิดีโอ'),
                          onPressed: _pickVideo,
                        ),
                      ),
                  ],
                ),
              ),
              // Panel ด้านขวา
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _buildElementTools(),
                    Expanded(child: _buildElementProperties()),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Timeline
        if (_videoController != null)
          Padding(
            padding: const EdgeInsets.only(
              top: 8.0,
              bottom: 8.0,
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.video_library),
              label: const Text('เลือกวิดีโอ'),
              onPressed: _pickVideo,
            ),
          ),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildElement(VideoElement element) {
    switch (element.type) {
      case 'text':
        return Text(
          element.content,
          style: TextStyle(
            fontSize: element.size,
            color: element.color,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 3.0,
                offset: Offset(1, 1),
              ),
            ],
          ),
        );
      case 'icon':
        return Icon(
          Icons.favorite,
          size: element.size,
          color: element.color,
        );
      case 'sticker':
        return Text(
          element.content,
          style: TextStyle(
            fontSize: element.size,
            color: element.color,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 3.0,
                offset: Offset(1, 1),
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }
}
