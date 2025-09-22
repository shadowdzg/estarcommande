import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_order_provider.dart';

class PaginationControls extends ConsumerWidget {
  const PaginationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);
    final totalPages = ref.watch(totalPagesProvider);
    final isLoading = ref.watch(paginationLoadingProvider);
    final totalCount = ref.watch(totalOrdersCountProvider);

    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          Text(
            'Page ${currentPage + 1} of $totalPages ($totalCount items)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),

          // Navigation controls
          Row(
            children: [
              // First page
              IconButton(
                onPressed: currentPage > 0 && !isLoading
                    ? () => _goToPage(ref, 0)
                    : null,
                icon: const Icon(Icons.first_page),
                tooltip: 'First page',
              ),

              // Previous page
              IconButton(
                onPressed: currentPage > 0 && !isLoading
                    ? () => _goToPage(ref, currentPage - 1)
                    : null,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
              ),

              // Page numbers (show current and adjacent pages)
              ..._buildPageNumbers(ref, currentPage, totalPages, isLoading),

              // Next page
              IconButton(
                onPressed: currentPage < totalPages - 1 && !isLoading
                    ? () => _goToPage(ref, currentPage + 1)
                    : null,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                tooltip: 'Next page',
              ),

              // Last page
              IconButton(
                onPressed: currentPage < totalPages - 1 && !isLoading
                    ? () => _goToPage(ref, totalPages - 1)
                    : null,
                icon: const Icon(Icons.last_page),
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(
    WidgetRef ref,
    int currentPage,
    int totalPages,
    bool isLoading,
  ) {
    final List<Widget> pageNumbers = [];

    // Show current page and 2 pages on each side
    final startPage = (currentPage - 2).clamp(0, totalPages - 1);
    final endPage = (currentPage + 2).clamp(0, totalPages - 1);

    for (int i = startPage; i <= endPage; i++) {
      pageNumbers.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _buildPageButton(ref, i, i == currentPage, isLoading),
        ),
      );
    }

    return pageNumbers;
  }

  Widget _buildPageButton(
    WidgetRef ref,
    int page,
    bool isCurrentPage,
    bool isLoading,
  ) {
    return SizedBox(
      width: 40,
      height: 40,
      child: isCurrentPage
          ? Container(
              decoration: BoxDecoration(
                color: Theme.of(ref.context).primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${page + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : TextButton(
              onPressed: !isLoading ? () => _goToPage(ref, page) : null,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('${page + 1}'),
            ),
    );
  }

  Future<void> _goToPage(WidgetRef ref, int page) async {
    ref.read(paginationLoadingProvider.notifier).state = true;
    try {
      await ref.read(purchaseOrdersProvider.notifier).goToPage(page);
    } finally {
      ref.read(paginationLoadingProvider.notifier).state = false;
    }
  }
}

