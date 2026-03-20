import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerDialog extends StatelessWidget {
  final Function(XFile) onImageSelected;
  final String title;

  const ImagePickerDialog({
    super.key,
    required this.onImageSelected,
    this.title = 'Select Image',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1920,
                maxHeight: 1080,
                imageQuality: 85,
              );
              if (image != null) {
                Navigator.of(context).pop();
                onImageSelected(image);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1920,
                maxHeight: 1080,
                imageQuality: 85,
              );
              if (image != null) {
                Navigator.of(context).pop();
                onImageSelected(image);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static Future<void> show(
    BuildContext context, {
    required Function(XFile) onImageSelected,
    String title = 'Select Image',
  }) {
    return showDialog(
      context: context,
      builder: (context) => ImagePickerDialog(
        onImageSelected: onImageSelected,
        title: title,
      ),
    );
  }
}
