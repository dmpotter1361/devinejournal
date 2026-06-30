import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class VoiceRecording {
  final Uint8List bytes;
  final int durationMs;
  final String mime;
  const VoiceRecording({required this.bytes, required this.durationMs, required this.mime});
}

class WebAudioRecorder {
  html.MediaRecorder? _recorder;
  html.MediaStream? _stream;
  List<html.Blob> _chunks = [];
  DateTime? _startTime;

  bool get isRecording => _recorder != null;

  Future<void> start() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) throw Exception('Microphone not available in this browser');
    _stream = await devices.getUserMedia({'audio': true});
    _chunks = [];
    _recorder = html.MediaRecorder(_stream!);
    _recorder!.addEventListener('dataavailable', (event) {
      final e = event as html.BlobEvent;
      if (e.data != null && e.data!.size > 0) _chunks.add(e.data!);
    });
    _startTime = DateTime.now();
    _recorder!.start();
  }

  Future<VoiceRecording> stop() async {
    final rec = _recorder;
    if (rec == null) throw Exception('Not recording');
    final completer = Completer<Uint8List>();
    final mime = (rec.mimeType != null && rec.mimeType!.isNotEmpty) ? rec.mimeType! : 'audio/webm';
    rec.addEventListener('stop', (_) {
      final blob = html.Blob(_chunks, mime);
      final reader = html.FileReader();
      reader.readAsArrayBuffer(blob);
      reader.onLoadEnd.listen((_) {
        completer.complete(reader.result as Uint8List);
      });
    });
    rec.stop();
    final bytes = await completer.future;
    final durationMs = DateTime.now().difference(_startTime ?? DateTime.now()).inMilliseconds;
    _stream?.getTracks().forEach((t) => t.stop());
    _recorder = null;
    return VoiceRecording(bytes: bytes, durationMs: durationMs, mime: mime);
  }

  void cancel() {
    _stream?.getTracks().forEach((t) => t.stop());
    _recorder = null;
    _chunks = [];
  }
}
