import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/app_colors.dart';
import '../language/app_language.dart';
import '../services/api_service.dart';
import '../models/filter_option.dart';
import 'product_detail_screen.dart';
import '../widgets/async_state.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/language_button.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/search_bar_button.dart';
import '../widgets/product_card.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    this.initialCategoryId,
    this.initialSearchword,
    this.requestSeq = 0,
    this.onSearch,
  });
  final String? initialCategoryId;
  final String? initialSearchword;
  final int requestSeq;
  final void Function(String query)? onSearch;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<ProductPage> _future;

  int _page = 1; // ตอนนี้อยู่หน้าไหน

  // คุมการเลื่อนของตาราง เปลี่ยนหน้าแล้วต้องพากลับขึ้นบนสุด
  // ไม่งั้นผู้ใช้จะค้างอยู่กลางรายการของหน้าใหม่โดยไม่รู้ตัว
  final ScrollController _gridController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchword = widget.initialSearchword;
    _filters = _filtersForRequest();
    _future = _fetch();
    ApiService()
        .fetchFilters()
        .then((options) {
          if (mounted) setState(() => _options = options);
        })
        .catchError((Object _) {}); // โหลดตัวกรองพังก็ยังดูสินค้าได้ตามปกติ
  }

  // ตัวกรองเริ่มต้นของคำสั่งล่าสุดจาก MainScreen
  // หมวดที่กดมาจากหน้าแรกถูกยัดเป็น "ตัวกรองที่ติ๊กไว้ให้แล้ว" ไม่ใช่เงื่อนไขซ่อน
  // ผู้ใช้จึงเห็นเป็นชิปและกดกากบาทเอาออกได้เหมือนติ๊กเอง (เหมือนเว็บ)
  ProductFilters _filtersForRequest() {
    final categoryId = widget.initialCategoryId;
    return ProductFilters.initial(isSearch: _isSearch)
        .copyWith(categoryIds: categoryId == null ? null : {categoryId});
  }

  // หน้านี้อยู่ใน IndexedStack จึงไม่ถูกสร้างใหม่ตอนสลับแท็บ
  // การกดหมวดหมู่ครั้งใหม่มาถึงที่นี่แทน initState
  @override
  void didUpdateWidget(ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ดูที่ตัวนับ ไม่ใช่ค่าหมวด เพราะกดหมวดเดิมซ้ำค่าไม่เปลี่ยนแต่ต้องทำงาน
    if (widget.requestSeq == oldWidget.requestSeq) return;
    setState(() {
      _searchword = widget.initialSearchword;
      _searchedAs = null;
      _suggestions = [];
      _filters = _filtersForRequest(); // แทนที่ของเดิม ไม่สะสมทับกันไปเรื่อยๆ
      _page = 1;
      _future = _fetch();
    });
    if (_gridController.hasClients) _gridController.jumpTo(0);
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  // คำที่ระบบใช้ค้นจริงเมื่อกู้คำพิมพ์ผิดแป้นให้ (null = ใช้คำที่ผู้ใช้พิมพ์)
  String? _searchedAs;

  // คำแนะนำ "คุณหมายถึง…?" — มีค่าเฉพาะตอนค้นแล้วไม่เจอ
  List<SearchSuggestion> _suggestions = [];

  late ProductFilters _filters;
  FilterOptions? _options; // โหลดครั้งเดียวพอ ตัวเลือกไม่เปลี่ยนบ่อย
  int _total = 0;

  Future<void> _openFilters() async {
    final options = _options;
    if (options == null) return; // ยังโหลดตัวเลือกไม่เสร็จ
    final result = await showFilterSheet(
      context,
      options: options,
      current: _filters,
      isSearch: _isSearch,
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result;
      _page = 1; // เปลี่ยนตัวกรองแล้วต้องกลับหน้า 1 เสมอ
      // ไม่งั้นอาจค้างอยู่หน้า 5 ของผลลัพธ์ที่มีแค่ 2 หน้า แล้วเจอหน้าว่าง
      _future = _fetch();
    });
    if (_gridController.hasClients) _gridController.jumpTo(0);
  }

  void _removeFilter({String? categoryId, String? tag}) {
    setState(() {
      _filters = _filters.copyWith(
        categoryIds: categoryId == null
            ? null
            : ({..._filters.categoryIds}..remove(categoryId)),
        tags: tag == null ? null : ({..._filters.tags}..remove(tag)),
      );
      _page = 1;
      _future = _fetch();
    });
  }

  // คำค้นที่หน้านี้กำลังแสดงผลอยู่ (null = โหมดสินค้าทั้งหมด)
  // เป็น state ไม่ใช่ prop เพราะผู้ใช้ล้างคำค้นทิ้งจากชิปได้เอง
  String? _searchword;

  // ออกจากโหมดผลการค้นหา กลับไปแสดงสินค้าทั้งหมด (ตัวกรองที่ติ๊กไว้ยังอยู่)
  void _clearSearch() {
    setState(() {
      _searchword = null;
      _searchedAs = null;
      _suggestions = [];
      // การเรียงของสองโหมดใช้คนละชุด: 'relevance' ใช้ได้เฉพาะตอนมีคำค้น
      // ถ้าปล่อยค้างไว้ backend จะไม่รู้จักแล้วเงียบๆ ตกไปเป็นค่าอื่น
      if (_filters.sort == 'relevance') {
        _filters = _filters.copyWith(sort: 'newest');
      }
      _page = 1;
      _future = _fetch();
    });
    if (_gridController.hasClients) _gridController.jumpTo(0);
  }

  bool get _isSearch => (_searchword ?? '').trim().isNotEmpty;

  Future<ProductPage> _fetch() {
    final future = _isSearch
        ? ApiService()
              .searchProducts(
                _searchword!.trim(),
                page: _page,
                categoryIds: _filters.categoryIds,
                tags: _filters.tags,
                sort: _filters.sort,
              )
              .then((result) {
                // เก็บไว้ก่อนแปลงเป็น ProductPage เพราะ ProductPage ไม่มีช่องนี้
                if (mounted) {
                  setState(() {
                    _searchedAs = result.searchedAs;
                    _suggestions = result.suggestions;
                  });
                }
                return ProductPage(
                  products: result.products,
                  page: result.page,
                  totalPages: result.totalPages,
                  total: result.total, // ไม่ส่งมาด้วย แถบจะขึ้น "0 รายการ"
                );
              })
        : ApiService().fetchProducts(
            page: _page,
            categoryIds: _filters.categoryIds,
            tags: _filters.tags,
            sort: _filters.sort,
          );
    // จำนวนรายการโชว์อยู่บนแถบตัวกรอง ซึ่งวาดก่อน body จึงอ่านจาก snapshot
    // ของ FutureBuilder ไม่ได้ ต้องเก็บใส่ State ไว้ต่างหากเมื่อข้อมูลมาถึง
    future
        .then((result) {
          if (mounted) {
            setState(() {
              _total = result.total;
            });
          }
        })
        .catchError((Object _) {}); // ข้อผิดพลาดมี FutureBuilder จัดการอยู่แล้ว
    return future;
  }

  void _goToPage(int page) {
    setState(() {
      _page = page;
      _future = _fetch();
    });
    if (_gridController.hasClients) _gridController.jumpTo(0);
  }

  // หัวรายการตาม wireframe: ช่องค้นหา → ปุ่มตัวกรอง/เรียง + จำนวนรายการ
  // → ชิปของที่เลือกไว้ (กดกากบาทเอาออกได้ทันที)
  Widget _filterHeader() {
    final hasChips =
        _isSearch ||
        _filters.categoryIds.isNotEmpty ||
        _filters.tags.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      // พื้นขาวแบบเดียวกับหัว (ผู้ใช้ขอ) — แถบนี้เลื่อนหายไปกับรายการ
      // เส้นใต้หัวจึงยังต้องอยู่ ไม่งั้นตอนเลื่อน/ตอนโหลด หัวจะกลืนกับเนื้อหา
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ปุ่มสองตัวหดตัวอยู่ใน Expanded ร่วมกัน เหลือเท่าไรหลังหักจำนวนรายการออก
              // จอแคบ + ป้ายเรียงยาวๆ (ราคาน้อย → มาก) จะย่อด้วย … แทนที่จะล้นขอบ
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: _options == null ? null : _openFilters,
                        icon: const Icon(
                          LucideIcons.slidersHorizontal,
                          size: 16,
                        ),
                        label: Text(
                          _filters.activeCount > 0
                              ? langs('filtersWithCount', {
                                  'count': _filters.activeCount,
                                })
                              : langs('filters'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.navy900,
                          side: const BorderSide(color: AppColors.button),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: OutlinedButton(
                        onPressed: _options == null ? null : _openFilters,
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AppColors.navy900,
                          side: const BorderSide(color: AppColors.button),
                        ),
                        child: Text(
                          langs('sortPrefix', {
                            'label': langs(sortLabels[_filters.sort] ?? ''),
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isSearch
                    ? langs('foundItems', {'count': _total})
                    : langs('totalItems', {'count': _total}),
                maxLines: 1,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          if (hasChips) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // คำค้นมาก่อนเสมอ เป็นทางออกจากโหมดผลการค้นหาโดยไม่ต้องกดย้อนกลับ
                // (หน้านี้เป็นแท็บแล้ว กดย้อนกลับคือออกจากแอป ไม่ใช่ล้างคำค้น)
                if (_isSearch)
                  Chip(
                    label: Text(
                      langs('searchChip', {'word': _searchword!.trim()}),
                    ),
                    onDeleted: _clearSearch,
                  ),
                ..._filters.categoryIds.map(
                  (id) => Chip(
                    label: Text(_categoryLabel(id)),
                    onDeleted: () => _removeFilter(categoryId: id),
                  ),
                ),
                ..._filters.tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    onDeleted: () => _removeFilter(tag: tag),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String id) {
    final options = _options?.categories ?? const <FilterOption>[];
    for (final option in options) {
      if (option.value == id) return option.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ไม่มีเส้นใต้หัว (ทับค่าใน appBarTheme) — ผู้ใช้ขอ ให้หัวต่อกับแถบตัวกรองสีขาวเป็นผืนเดียว
        shape: const Border(),
        title: Text(langs('productsTitle'), overflow: TextOverflow.ellipsis),
        actions: [LanguageButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            // โหมดผลการค้นหา: โชว์คำที่ค้นอยู่ในช่อง กดแล้วแก้คำต่อได้เลย
            child: SearchBarButton(
              query: _isSearch ? _searchword!.trim() : null,
              onSearch: widget.onSearch,
            ),
          ),
        ),
        // ปุ่มสลับภาษาแทนตัวเปลี่ยนหน้าที่เคยอยู่ตรงนี้ — การเปลี่ยนหน้า
        // มีแถบเลขหน้าท้ายรายการอยู่แล้ว ไม่ต้องมีสองที่
      ),
      body: FutureBuilder<ProductPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error);
          }

          final result = snapshot.data!;
          final products = result.products;

          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(overscroll: false),
            // CustomScrollView: หัวแถบ ตาราง และแถบเลขหน้า อยู่ในสิ่งที่เลื่อน
            // อันเดียวกัน แถบเลขหน้าจึงโผล่ตอนเลื่อนถึงล่างสุด ไม่ตรึงทับจอ
            child: CustomScrollView(
              controller: _gridController,
              slivers: [
                SliverToBoxAdapter(child: _filterHeader()),
                if (_searchedAs != null)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      color: AppColors.brand50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        langs('searchedAs', {'word': _searchedAs ?? ''}),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.brand700,
                        ),
                      ),
                    ),
                  ),
                if (products.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.searchX,
                            size: 44,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            langs('noProducts'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ค้นไม่เจอ → เสนอชื่อที่ใกล้เคียง กดแล้วค้นด้วยชื่อนั้นทันที
                if (products.isEmpty && _suggestions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langs('didYouMean'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ..._suggestions.map(
                            (s) => Card(
                              margin: const EdgeInsets.only(top: 8),
                              child: ListTile(
                                title: Text(s.productName),
                                trailing: const Icon(LucideIcons.chevronRight),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                      productId: s.productId,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid.builder(
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 300,
                        ),
                    itemBuilder: (context, index) => ProductCard(
                      product: products[index],
                      query: _isSearch ? _searchword : null,
                    ),
                  ),
                ),
                // แถบเลขหน้าเต็ม อยู่ท้ายรายการ เลื่อนลงมาถึงจึงเห็น
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    child: PaginationBar(
                      page: result.page,
                      totalPages: result.totalPages,
                      onChanged: _goToPage,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
