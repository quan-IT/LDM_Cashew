import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../colors.dart';
import '../struct/models/study_document.dart';
import '../struct/state/document_provider.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/stats_header_card.dart';
import '../widgets/subject_chip.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'subject_management_page.dart';
import 'sync_backup_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final documents = provider.filteredDocuments;
    final subjects = provider.subjects;
    final stats = provider.statistics;

    final hasActiveFilter = provider.searchQuery.isNotEmpty ||
        provider.selectedSubjectFk != null ||
        provider.selectedDocType != null ||
        provider.onlyFavorites;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              'Tài liệu Học tập',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmarks_rounded),
            tooltip: 'Quản lý Môn học',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubjectManagementPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded),
            tooltip: 'Đồng bộ & Kiến trúc Cashew',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncBackupPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddEditDocumentPage()),
          );
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm tài liệu'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. Thẻ thống kê tổng quan
                SliverToBoxAdapter(
                  child: StatsHeaderCard(
                    stats: stats,
                    selectedDocType: provider.selectedDocType,
                    onSelectDocType: (type) => provider.selectDocType(type),
                  ),
                ),

                // 2. Thanh tìm kiếm thời gian thực
                SliverToBoxAdapter(
                  child: SearchBarWidget(
                    initialValue: provider.searchQuery,
                    onChanged: (val) => provider.setSearchQuery(val),
                    onClear: () => provider.setSearchQuery(''),
                    onlyFavorites: provider.onlyFavorites,
                    onToggleFavorites: () => provider.toggleOnlyFavorites(),
                  ),
                ),

                // 3. Thanh cuộn chọn Môn học
                SliverToBoxAdapter(
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: subjects.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return SubjectChip(
                            subject: null,
                            isAll: true,
                            isSelected: provider.selectedSubjectFk == null,
                            onTap: () => provider.selectSubject(null),
                          );
                        }
                        final subject = subjects[index - 1];
                        return SubjectChip(
                          subject: subject,
                          isSelected: provider.selectedSubjectFk == subject.subjectPk,
                          onTap: () => provider.selectSubject(subject.subjectPk),
                        );
                      },
                    ),
                  ),
                ),

                // 4. Thanh báo trạng thái lọc (nếu có)
                if (hasActiveFilter)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Tìm thấy ${documents.length} kết quả',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => provider.clearFilters(),
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Bỏ lọc', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 5. Danh sách tài liệu hoặc Empty State
                if (documents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      title: hasActiveFilter
                          ? 'Không tìm thấy tài liệu phù hợp'
                          : 'Chưa có tài liệu nào',
                      message: hasActiveFilter
                          ? 'Hãy thử thay đổi từ khóa tìm kiếm hoặc bỏ bớt các tiêu chí lọc.'
                          : 'Nhấn nút "Thêm tài liệu" để bắt đầu lưu trữ bài giảng, bài tập hoặc tài liệu tham khảo.',
                      buttonText: hasActiveFilter ? 'Bỏ bộ lọc' : 'Thêm tài liệu đầu tiên',
                      onButtonPressed: () {
                        if (hasActiveFilter) {
                          provider.clearFilters();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddEditDocumentPage()),
                          );
                        }
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = documents[index];
                          final subject = provider.getSubjectByPk(doc.subjectFk);

                          return DocumentCard(
                            document: doc,
                            subject: subject,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DocumentDetailPage(documentPk: doc.documentPk),
                                ),
                              );
                            },
                            onToggleFavorite: () => provider.toggleFavorite(doc.documentPk),
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEditDocumentPage(document: doc),
                                ),
                              );
                            },
                            onDelete: () => _confirmDelete(context, provider, doc),
                          );
                        },
                        childCount: documents.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentProvider provider, StudyDocument doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa tài liệu?'),
        content: Text('Xóa "${doc.title}" khỏi cơ sở dữ liệu? Dữ liệu xóa sẽ được ghi nhận vào DeleteLogs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteDocument(doc.documentPk);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa tài liệu và tạo bản ghi Tombstone!')),
                );
              }
            },
            child: const Text('XÓA'),
          ),
        ],
      ),
    );
  }
}
