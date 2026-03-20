import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import '../models/banner_config.dart';
import '../services/banner_service.dart';
import '../theme/app_theme.dart';

class AdminManageBannersScreen extends StatefulWidget {
  const AdminManageBannersScreen({super.key});

  @override
  State<AdminManageBannersScreen> createState() => _AdminManageBannersScreenState();
}

class _AdminManageBannersScreenState extends State<AdminManageBannersScreen> {
  final BannerService _bannerService = BannerService();
  List<BannerConfig> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final banners = await _bannerService.getAllBanners();
      if (mounted) {
        setState(() {
          _banners = banners;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading banners: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBannerActions(BannerConfig banner) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.colors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Set Active action
              if (!banner.isActive)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _setActiveBanner(banner);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Set as Active',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Show this banner on home screen',
                                  style: TextStyle(
                                    color: AppTheme.colors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (!banner.isActive)
                Divider(
                  height: 1,
                  color: AppTheme.colors.textSecondary.withOpacity(0.1),
                  indent: 76,
                ),

              // Edit action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showEditBannerDialog(banner);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: AppTheme.colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Banner',
                                style: TextStyle(
                                  color: AppTheme.colors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Modify banner information',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppTheme.colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Divider(
                height: 1,
                color: AppTheme.colors.textSecondary.withOpacity(0.1),
                indent: 76,
              ),

              // Delete action
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteBanner(banner);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delete Banner',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Remove banner permanently',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEditBannerDialog(BannerConfig banner) {
    final imageUrlController = TextEditingController(text: banner.imageUrl);
    final titleController = TextEditingController(text: banner.title);
    final descriptionController = TextEditingController(text: banner.description);
    final linkUrlController = TextEditingController(text: banner.linkUrl ?? '');
    final displayOrderController = TextEditingController(text: banner.displayOrder.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Link URL (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Display Order',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                imageUrlController.dispose();
                titleController.dispose();
                descriptionController.dispose();
                linkUrlController.dispose();
                displayOrderController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final imageUrl = imageUrlController.text;
                final title = titleController.text;
                final description = descriptionController.text;
                final linkUrl = linkUrlController.text;
                final displayOrder = displayOrderController.text;

                imageUrlController.dispose();
                titleController.dispose();
                descriptionController.dispose();
                linkUrlController.dispose();
                displayOrderController.dispose();

                Navigator.pop(context);

                _updateBanner(
                  banner,
                  imageUrl,
                  title,
                  description,
                  linkUrl,
                  displayOrder,
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateBannerDialog() {
    final imageUrlController = TextEditingController();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final linkUrlController = TextEditingController();
    final displayOrderController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Link URL (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayOrderController,
                  decoration: const InputDecoration(
                    labelText: 'Display Order',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                imageUrlController.dispose();
                titleController.dispose();
                descriptionController.dispose();
                linkUrlController.dispose();
                displayOrderController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final imageUrl = imageUrlController.text;
                final title = titleController.text;
                final description = descriptionController.text;
                final linkUrl = linkUrlController.text;
                final displayOrder = displayOrderController.text;

                imageUrlController.dispose();
                titleController.dispose();
                descriptionController.dispose();
                linkUrlController.dispose();
                displayOrderController.dispose();

                Navigator.pop(context);

                _createBanner(
                  imageUrl,
                  title,
                  description,
                  linkUrl,
                  displayOrder,
                );
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createBanner(
    String imageUrl,
    String title,
    String description,
    String linkUrl,
    String displayOrderStr,
  ) async {
    try {
      if (imageUrl.trim().isEmpty) {
        throw Exception('Image URL cannot be empty');
      }

      int displayOrder = int.tryParse(displayOrderStr) ?? 0;

      final banner = BannerConfig(
        id: '',
        imageUrl: imageUrl.trim(),
        title: title.trim(),
        description: description.trim(),
        linkUrl: linkUrl.trim().isEmpty ? null : linkUrl.trim(),
        displayOrder: displayOrder,
        isActive: false,
      );

      await _bannerService.createBanner(banner);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBanners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateBanner(
    BannerConfig banner,
    String imageUrl,
    String title,
    String description,
    String linkUrl,
    String displayOrderStr,
  ) async {
    try {
      if (imageUrl.trim().isEmpty) {
        throw Exception('Image URL cannot be empty');
      }

      int displayOrder = int.tryParse(displayOrderStr) ?? banner.displayOrder;

      await _bannerService.updateBanner(banner.id, {
        'imageUrl': imageUrl.trim(),
        'title': title.trim(),
        'description': description.trim(),
        'linkUrl': linkUrl.trim().isEmpty ? null : linkUrl.trim(),
        'displayOrder': displayOrder,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBanners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setActiveBanner(BannerConfig banner) async {
    try {
      await _bannerService.setActiveBanner(banner.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${banner.title.isEmpty ? "Banner" : banner.title} is now active'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBanners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting active banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteBanner(BannerConfig banner) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Banner'),
          content: Text(
            banner.title.isEmpty
                ? 'Are you sure you want to delete this banner? This action cannot be undone.'
                : 'Are you sure you want to delete "${banner.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteBanner(banner);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBanner(BannerConfig banner) async {
    try {
      await _bannerService.deleteBanner(banner.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Banner deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBanners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.colors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Banners',
          style: TextStyle(
            color: AppTheme.colors.text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.colors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Banners',
                      style: TextStyle(
                        color: AppTheme.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_banners.length}',
                      style: TextStyle(
                        color: AppTheme.colors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadBanners,
                      color: AppTheme.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateBannerDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.colors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Banners List
          Expanded(
            child: _isLoading
                ? Center(
                    child: SpinKitWaveSpinner(
                      color: AppTheme.colors.primary,
                      size: 50.0,
                    ),
                  )
                : _banners.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 64,
                              color: AppTheme.colors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No banners found',
                              style: TextStyle(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showCreateBannerDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Banner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.colors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBanners,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _banners.length,
                          itemBuilder: (context, index) {
                            final banner = _banners[index];
                            return _buildBannerCard(banner);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BannerConfig banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: banner.isActive
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            _showBannerActions(banner);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    banner.imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 150,
                        color: AppTheme.colors.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.broken_image,
                          color: AppTheme.colors.primary,
                          size: 48,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Banner Info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (banner.isActive) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  banner.title.isEmpty ? 'Untitled Banner' : banner.title,
                                  style: TextStyle(
                                    color: AppTheme.colors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (banner.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              banner.description,
                              style: TextStyle(
                                color: AppTheme.colors.textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.sort,
                                size: 14,
                                color: AppTheme.colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Order: ${banner.displayOrder}',
                                style: TextStyle(
                                  color: AppTheme.colors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.more_vert,
                      color: AppTheme.colors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
