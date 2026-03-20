import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:bunny/services/auth_service.dart';
import 'package:bunny/services/image_upload_service.dart';
import 'package:bunny/widgets/image_picker_dialog.dart';

class ProfileImageWidget extends StatefulWidget {
  final double size;
  final bool editable;
  final String? imageUrl;
  final VoidCallback? onImageChanged;

  const ProfileImageWidget({
    super.key,
    this.size = 100,
    this.editable = true,
    this.imageUrl,
    this.onImageChanged,
  });

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  final ImageUploadService _imageUploadService = ImageUploadService();
  bool _isUploading = false;

  Future<void> _uploadProfileImage(XFile imageFile) async {
    setState(() => _isUploading = true);

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Upload image to Firebase Storage
      final String? imageUrl = await _imageUploadService.uploadProfilePicture(
        currentUser.id,
        imageFile,
      );

      if (imageUrl != null) {
        // Update user profile with new image URL
        await authService.updateUserProfile(profileImageUrl: imageUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Notify parent widget
          widget.onImageChanged?.call();
        }
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;
    final String? imageUrl = widget.imageUrl ?? currentUser?.profileImageUrl;

    return GestureDetector(
      onTap: widget.editable && !_isUploading
          ? () => ImagePickerDialog.show(
                context,
                onImageSelected: _uploadProfileImage,
                title: 'Select Profile Picture',
              )
          : null,
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _isUploading
                  ? Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar();
                          },
                        )
                      : _buildDefaultAvatar(),
            ),
          ),
          if (widget.editable && !_isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.size * 0.3,
                height: widget.size * 0.3,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: widget.size * 0.6,
        color: Colors.grey.shade600,
      ),
    );
  }
}
