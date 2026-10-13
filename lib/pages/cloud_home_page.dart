import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../colors.dart';
import '../struct/models/cloud_document.dart';
import '../struct/state/cloud_provider.dart';
import 'add_edit_cloud_document_page.dart';
import 'cloud_document_detail_page.dart';
import 'login_page.dart';
import 'share_document_page.dart';

/// Trang chính của hệ thống Cloud Document Management
class CloudHomePage extends StatefulWidget {
  const CloudHomePage({super.key});
  @override
  State<CloudHomePage> createState() => _CloudHomePageState();
}

class _CloudHomePageState extends State<CloudHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      final provider = context.read<CloudProvider>();
      provider.setShowShared(_tabController.index == 1);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static const _docTypeFilters = [
    {'key': null, 'label': 'Tất cả'},
    {'key': 'lecture', 'label': 'Bài giảng'},
    {'key': 'assignment', 'label': 'Bài tập'},
    {'key': 'reference', 'label': 'Tham khảo'},
    {'key': 'exam', 'label': 'Đề thi'},
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CloudProvider>();

    // Nếu chưa đăng nhập → hiển thị trang đăng nhập
    if (!provider.isAuthenticated) {
      return const LoginPage();
    }

    final stats = provider.statistics;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'DocCloud',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Của tôi (${stats['total']})'),
            Tab(text: 'Được chia sẻ (${stats['shared']})'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
            onPressed: provider.loadDocuments,
          ),
          // Avatar + menu người dùng
          PopupMenuButton<String>(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _UserAvatar(
                photoUrl: provider.currentUser?.photoUrl,
                displayName: provider.currentUser?.displayName,
              ),
            ),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.currentUser?.displayName ?? 'Người dùng',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      provider.currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'signout') await provider.signOut();
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditCloudDocumentPage(),
                ),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Thêm tài liệu'),
            )
          : null,
      body: Column(
        children: [
          // ── Stats Bar ──
          _StatsBar(stats: stats),

          // ── Search + Filter ──
          _SearchFilterBar(
            controller: _searchController,
            docTypeFilters: _docTypeFilters,
            onSearch: provider.setSearchQuery,
            selectedDocType: provider.selectedDocType,
            onDocTypeChanged: provider.setSelectedDocType,
            onlyFavorites: provider.onlyFavorites,
            onToggleFavorites: provider.toggleFavoriteFilter,
            onClear: () {
              _searchController.clear();
              provider.clearFilters();
            },
          ),

          // ── Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Tài liệu của tôi
                _DocumentList(
                  documents: provider.filteredDocuments,
                  isLoading: provider.docStatus == LoadingStatus.loading,
                  emptyMessage:
                      'Chưa có tài liệu nào\nNhấn "Thêm tài liệu" để bắt đầu',
                  currentUserUid: provider.currentUser?.uid ?? '',
                  onRefresh: provider.loadDocuments,
                ),
                // Tab 2: Được chia sẻ
                _DocumentList(
                  documents: provider.filteredDocuments,
                  isLoading: provider.docStatus == LoadingStatus.loading,
                  emptyMessage: 'Chưa có tài liệu nào được chia sẻ với bạn',
                  currentUserUid: provider.currentUser?.uid ?? '',
                  onRefresh: provider.loadDocuments,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.photoUrl, required this.displayName});

  final String? photoUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final imageUrl = photoUrl;
    final name = displayName?.trim();
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary,
      child: imageUrl == null || imageUrl.isEmpty
          ? _initial(name)
          : ClipOval(
              child: Image.network(
                imageUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initial(name),
              ),
            ),
    );
  }

  Widget _initial(String? name) {
    return Text(
      name == null || name.isEmpty ? 'U' : name[0].toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

// ── Stats Bar ──
class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem('${stats['total']}', 'Tổng', Icons.folder_rounded),
          _StatItem('${stats['shared']}', 'Chia sẻ', Icons.people_rounded),
          _StatItem('${stats['favorites']}', 'Yêu thích', Icons.star_rounded),
          _StatItem('${stats['lecture']}', 'Bài giảng', Icons.class_rounded),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatItem(this.value, this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

// ── Search + Filter ──
class _SearchFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final List<Map<String, dynamic>> docTypeFilters;
  final Function(String) onSearch;
  final String? selectedDocType;
  final Function(String?) onDocTypeChanged;
  final bool onlyFavorites;
  final VoidCallback onToggleFavorites;
  final VoidCallback onClear;

  const _SearchFilterBar({
    required this.controller,
    required this.docTypeFilters,
    required this.onSearch,
    required this.selectedDocType,
    required this.onDocTypeChanged,
    required this.onlyFavorites,
    required this.onToggleFavorites,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tài liệu...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.star_rounded,
                      color: onlyFavorites ? Colors.amber : Colors.grey,
                    ),
                    onPressed: onToggleFavorites,
                    tooltip: 'Yêu thích',
                  ),
                  if (controller.text.isNotEmpty ||
                      selectedDocType != null ||
                      onlyFavorites)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: onClear,
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: docTypeFilters.length,
            itemBuilder: (ctx, i) {
              final f = docTypeFilters[i];
              final isSelected = selectedDocType == f['key'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                    f['label'] as String,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                  onSelected: (_) => onDocTypeChanged(f['key'] as String?),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Document List ──
class _DocumentList extends StatelessWidget {
  final List<CloudDocument> documents;
  final bool isLoading;
  final String emptyMessage;
  final String currentUserUid;
  final Future<void> Function() onRefresh;

  const _DocumentList({
    required this.documents,
    required this.isLoading,
    required this.emptyMessage,
    required this.currentUserUid,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 4, left: 12, right: 12),
        itemCount: documents.length,
        itemBuilder: (ctx, i) => _CloudDocumentCard(
          document: documents[i],
          isOwner: documents[i].ownerUid == currentUserUid,
        ),
      ),
    );
  }
}

// ── Cloud Document Card ──
class _CloudDocumentCard extends StatelessWidget {
  final CloudDocument document;
  final bool isOwner;

  const _CloudDocumentCard({required this.document, required this.isOwner});

  static const _colors = {
    'lecture': Color(0xFF3949AB),
    'assignment': Color(0xFF2E7D32),
    'reference': Color(0xFFE65100),
    'exam': Color(0xFFC62828),
  };

  static const _icons = {
    'lecture': Icons.class_rounded,
    'assignment': Icons.assignment_rounded,
    'reference': Icons.book_rounded,
    'exam': Icons.quiz_rounded,
  };

  Color get _color => _colors[document.docType] ?? AppColors.primary;
  IconData get _icon => _icons[document.docType] ?? Icons.description_rounded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CloudDocumentDetailPage(document: document),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon, color: _color, size: 24),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (document.isFavorite)
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${document.subject}${document.description.isNotEmpty ? " • ${document.description.substring(0, document.description.length > 40 ? 40 : document.description.length)}..." : ""}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (document.fileName.isNotEmpty) ...[
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            document.formattedFileSize,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOwner
                                ? Colors.green.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOwner ? 'Của tôi' : 'Được chia sẻ',
                            style: TextStyle(
                              fontSize: 10,
                              color: isOwner ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (isOwner)
                IconButton(
                  icon: const Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareDocumentPage(document: document),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
