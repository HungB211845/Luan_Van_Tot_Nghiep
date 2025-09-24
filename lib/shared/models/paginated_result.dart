// =============================================================================
// PAGINATED RESULT - SHARED MODEL CHO TẤT CẢ PAGINATION OPERATIONS
// =============================================================================

class PaginatedResult<T> {
  final List<T> items;
  final int totalCount;
  final int currentPage;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final int totalPages;

  const PaginatedResult({
    required this.items,
    required this.totalCount,
    required this.currentPage,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.totalPages,
  });

  factory PaginatedResult.fromSupabaseResponse({
    required List<T> items,
    required int totalCount,
    required int offset,
    required int limit,
  }) {
    final currentPage = (offset / limit).floor() + 1;
    final totalPages = (totalCount / limit).ceil();
    final hasNextPage = offset + limit < totalCount;
    final hasPreviousPage = offset > 0;

    return PaginatedResult<T>(
      items: items,
      totalCount: totalCount,
      currentPage: currentPage,
      pageSize: limit,
      hasNextPage: hasNextPage,
      hasPreviousPage: hasPreviousPage,
      totalPages: totalPages,
    );
  }

  factory PaginatedResult.empty() {
    return const PaginatedResult<Never>(
      items: [],
      totalCount: 0,
      currentPage: 1,
      pageSize: 20,
      hasNextPage: false,
      hasPreviousPage: false,
      totalPages: 0,
    );
  }

  // HELPER METHODS
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;

  // RANGE INFORMATION
  int get startIndex => ((currentPage - 1) * pageSize) + 1;
  int get endIndex => startIndex + itemCount - 1;

  // PAGE NAVIGATION
  int get nextPage => hasNextPage ? currentPage + 1 : currentPage;
  int get previousPage => hasPreviousPage ? currentPage - 1 : currentPage;
  int get nextOffset => hasNextPage ? currentPage * pageSize : (currentPage - 1) * pageSize;
  int get previousOffset => hasPreviousPage ? (currentPage - 2) * pageSize : 0;

  // MERGE RESULTS (for load more functionality)
  PaginatedResult<T> merge(PaginatedResult<T> newPage) {
    if (newPage.currentPage <= currentPage) {
      return this; // Don't merge if it's not a next page
    }

    return PaginatedResult<T>(
      items: [...items, ...newPage.items],
      totalCount: newPage.totalCount, // Use latest total count
      currentPage: newPage.currentPage,
      pageSize: pageSize,
      hasNextPage: newPage.hasNextPage,
      hasPreviousPage: hasPreviousPage, // Keep original
      totalPages: newPage.totalPages,
    );
  }

  // COPY WITH
  PaginatedResult<T> copyWith({
    List<T>? items,
    int? totalCount,
    int? currentPage,
    int? pageSize,
    bool? hasNextPage,
    bool? hasPreviousPage,
    int? totalPages,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      totalPages: totalPages ?? this.totalPages,
    );
  }

  @override
  String toString() {
    return 'PaginatedResult<$T>('
        'items: ${items.length}, '
        'totalCount: $totalCount, '
        'currentPage: $currentPage/$totalPages, '
        'hasNext: $hasNextPage, '
        'hasPrev: $hasPreviousPage'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaginatedResult<T> &&
        other.totalCount == totalCount &&
        other.currentPage == currentPage &&
        other.pageSize == pageSize &&
        other.hasNextPage == hasNextPage &&
        other.hasPreviousPage == hasPreviousPage &&
        other.totalPages == totalPages;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalCount,
      currentPage,
      pageSize,
      hasNextPage,
      hasPreviousPage,
      totalPages,
    );
  }
}

// =============================================================================
// PAGINATION PARAMETERS - HELPER CLASS CHO PAGINATION REQUESTS
// =============================================================================

class PaginationParams {
  final int page;
  final int pageSize;
  final int offset;
  final String? sortBy;
  final bool ascending;

  const PaginationParams({
    this.page = 1,
    this.pageSize = 20,
    this.sortBy,
    this.ascending = true,
  }) : offset = (page - 1) * pageSize;

  factory PaginationParams.first({int pageSize = 20}) {
    return PaginationParams(page: 1, pageSize: pageSize);
  }

  PaginationParams nextPage() {
    return PaginationParams(
      page: page + 1,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  PaginationParams previousPage() {
    return PaginationParams(
      page: page > 1 ? page - 1 : 1,
      pageSize: pageSize,
      sortBy: sortBy,
      ascending: ascending,
    );
  }

  PaginationParams copyWith({
    int? page,
    int? pageSize,
    String? sortBy,
    bool? ascending,
  }) {
    return PaginationParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'pageSize': pageSize,
      'offset': offset,
      'sortBy': sortBy,
      'ascending': ascending,
    };
  }

  @override
  String toString() {
    return 'PaginationParams(page: $page, pageSize: $pageSize, offset: $offset, sortBy: $sortBy)';
  }
}