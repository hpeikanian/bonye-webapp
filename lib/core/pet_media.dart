import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as imaging;
import 'api.dart';
import 'design.dart';
import 'language.dart';
import 'widgets.dart';

const maxPetPhotoBytes = 300 * 1024;
Uint8List preparePetPhoto(Uint8List bytes) {
  try {
    return _preparePetPhoto(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('photo_format');
  }
}

Uint8List _preparePetPhoto(Uint8List bytes) {
  if (bytes.length > 15 * 1024 * 1024) {
    throw const FormatException('photo_size');
  }
  final decoder = imaging.findDecoderForData(bytes);
  if (decoder == null ||
      !(decoder is imaging.JpegDecoder ||
          decoder is imaging.PngDecoder ||
          decoder is imaging.WebPDecoder)) {
    throw const FormatException('photo_format');
  }
  final info = decoder.startDecode(bytes);
  if (info == null || info.width * info.height > 40000000) {
    throw const FormatException('photo_size');
  }
  var decoded = decoder.decodeFrame(0);
  if (decoded == null) throw const FormatException('photo_format');
  decoded = imaging.bakeOrientation(decoded);
  if (decoded.width > 1024 || decoded.height > 1024) {
    decoded = imaging.copyResize(decoded,
        width: decoded.width >= decoded.height ? 1024 : null,
        height: decoded.height > decoded.width ? 1024 : null);
  }
  // A fresh raster strips source EXIF/GPS metadata and flattens alpha onto white.
  var clean = imaging.Image(width: decoded.width, height: decoded.height);
  imaging.fill(clean, color: imaging.ColorRgb8(255, 255, 255));
  imaging.compositeImage(clean, decoded);
  for (var edge = 0; edge < 4; edge++) {
    for (final quality in [85, 75, 65, 55]) {
      final result = imaging.encodeJpg(clean, quality: quality);
      if (result.length <= maxPetPhotoBytes) return result;
    }
    clean = imaging.copyResize(clean, width: (clean.width * .75).round());
  }
  throw const FormatException('photo_size');
}

String? petPhotoUrl(Json pet) {
  final url = Uri.tryParse('${pet['photo_url'] ?? ''}');
  return url != null && url.scheme == 'https' && url.userInfo.isEmpty
      ? url.toString()
      : null;
}

class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.pet});
  final Json pet;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
          width: 64,
          height: 64,
          child: petPhotoUrl(pet) == null
              ? SoftIcon(Icons.pets_outlined,
                  size: 64, color: pet['species'] == 'cat' ? peach : sage)
              : Image.network(petPhotoUrl(pet)!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const SoftIcon(Icons.pets_outlined, size: 64))));
}

class PetPhotoCard extends StatefulWidget {
  const PetPhotoCard({super.key, required this.api, required this.pet});
  final BonyeApi api;
  final Json pet;
  @override
  State<PetPhotoCard> createState() => _PetPhotoCardState();
}

class _PetPhotoCardState extends State<PetPhotoCard> {
  bool busy = false;
  Uint8List? preview;
  String? key;
  Future<void> upload() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final chosen = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          withData: true);
      if (chosen == null) return;
      final bytes = chosen.files.single.bytes;
      if (bytes == null) throw const FormatException();
      final photo = await compute(preparePetPhoto, bytes);
      key = operationKey();
      final result = await widget.api.request(
          'PUT', '/pets/${widget.pet['id']}/photo',
          body: {
            'content_type': 'image/jpeg',
            'image_base64': base64Encode(photo)
          },
          key: key);
      if (petPhotoUrl(result) == null) throw ApiError('invalid_response');
      if (mounted) {
        setState(() {
          widget.pet['photo_url'] = result['photo_url'];
          preview = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is FormatException) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  AppText('عکس JPG، PNG یا WebP تا ۱۵ مگابایت انتخاب کنید.')));
        } else {
          showError(context, e);
        }
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
                height: 220,
                width: double.infinity,
                child: preview != null
                    ? Image.memory(preview!, fit: BoxFit.cover)
                    : petPhotoUrl(widget.pet) != null
                        ? Image.network(petPhotoUrl(widget.pet)!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                                child: SoftIcon(Icons.pets_outlined, size: 90)))
                        : const ColoredBox(
                            color: sage,
                            child: Center(
                                child:
                                    SoftIcon(Icons.pets_outlined, size: 90))))),
        OutlinedButton.icon(
            onPressed: busy ? null : upload,
            icon:
                Icon(busy ? Icons.hourglass_empty : Icons.add_a_photo_outlined),
            label: AppText(busy ? 'در حال ذخیره…' : 'انتخاب عکس پت')),
        const AppText(
            'عکس پیش از ارسال کوچک می‌شود؛ حداکثر ۱۰۲۴ پیکسل و ۳۰۰ کیلوبایت.',
            style: TextStyle(fontSize: 12)),
      ]);
}
