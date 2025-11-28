import 'package:flutter/material.dart';

void main() {
  runApp(const BullstradeApp());
}

class BullstradeApp extends StatelessWidget {
  const BullstradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bullstrade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D4EDB),
          background: const Color(0xFFF4F6FA),
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1633),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0A1633),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4F5B76),
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _indices = const [
    MarketIndex('NIFTY 50', 24256.65, -502.10, -0.96),
    MarketIndex('SENSEX', 44256.65, 502.10, 0.25),
    MarketIndex('BANKNIFTY', 44256.65, 502.10, 0.25),
    MarketIndex('MIDCAP 100', 33712.40, 122.45, 0.36),
  ];

  final _tradeShortcuts = const [
    _Shortcut('InstaOptions', Icons.token_outlined, Color(0xFF0CC26C)),
    _Shortcut('IB Algo', Icons.alt_route_outlined, Color(0xFF0D4EDB)),
    _Shortcut('Quantman', Icons.monitor_heart_outlined, Color(0xFF171717)),
    _Shortcut('TalkOptions', Icons.chat_bubble_outline, Color(0xFF0096FF)),
  ];

  final _marketMovers = const [
    MarketMover(
      'Tata Motors',
      'NSE',
      336.34,
      18.23,
      12.34,
      Icons.directions_car,
    ),
    MarketMover(
      'Dhani Services',
      'NSE',
      336.34,
      18.23,
      12.34,
      Icons.domain_outlined,
    ),
    MarketMover(
      'HDFC Life Insurance',
      'NSE',
      336.34,
      -18.23,
      -12.34,
      Icons.favorite_border,
    ),
    MarketMover(
      'HDFC Bank',
      'NSE',
      336.34,
      18.23,
      12.34,
      Icons.account_balance,
    ),
    MarketMover(
      'Cholamandalam Invest',
      'NSE',
      336.34,
      18.23,
      12.34,
      Icons.attach_money,
    ),
  ];

  final _newsItems = const [
    MarketNews(
      minutesAgo: 60,
      title:
          'Lorem ipsum dolor sit amet consectetur. Mauris id a vitae dignissim',
      source: 'RBL Bank Ltd',
      change: 1.27,
      positive: true,
    ),
    MarketNews(
      minutesAgo: 62,
      title:
          'Lorem ipsum dolor sit amet consectetur. Mauris id a vitae digni...',
      source: 'RBL Bank Ltd',
      change: 1.27,
      positive: true,
    ),
    MarketNews(
      minutesAgo: 63,
      title:
          'Lorem ipsum dolor sit amet consectetur. Mauris id a vitae dignissim',
      source: 'RBL Bank Ltd',
      change: -1.27,
      positive: false,
    ),
    MarketNews(
      minutesAgo: 64,
      title:
          'Lorem ipsum dolor sit amet consectetur. Mauris id a vitae dignissim',
      source: 'RBL Bank Ltd',
      change: 1.27,
      positive: true,
    ),
  ];

  int _tradeTab = 1;
  int _moversTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _buildBottomNav(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildIndices(),
              const SizedBox(height: 24),
              _PositionOverviewCard(),
              const SizedBox(height: 28),
              _buildTradeTabs(),
              const SizedBox(height: 28),
              _TradingBalanceCard(),
              const SizedBox(height: 28),
              _buildMarketMovers(),
              const SizedBox(height: 28),
              const _PromoCarousel(),
              const SizedBox(height: 28),
              _buildMarketNews(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello Vrundar!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Home page for investor / All time hidden',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: const Color(0xFF8A93A6),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search, color: Color(0xFF4F5B76)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(
            Icons.notifications_none_outlined,
            color: Color(0xFF4F5B76),
          ),
          onPressed: () {},
        ),
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFE4EAFF),
          child: Text(
            'V',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D4EDB),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Indices',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.circle, size: 10, color: Color(0xFF2CC47F)),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: Color(0xFF4F5B76),
              ),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final data = _indices[index];
              return _IndexCard(index: data);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemCount: _indices.length,
          ),
        ),
      ],
    );
  }

  Widget _buildTradeTabs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TabButton(
              label: 'Invest',
              selected: _tradeTab == 0,
              onTap: () => setState(() => _tradeTab = 0),
            ),
            const SizedBox(width: 18),
            _TabButton(
              label: 'Trade',
              selected: _tradeTab == 1,
              onTap: () => setState(() => _tradeTab = 1),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _tradeTab == 1
              ? _buildTradeGrid()
              : const _InvestPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildTradeGrid() {
    return Container(
      key: const ValueKey('trade'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1633).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 86,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _tradeShortcuts.length,
        itemBuilder: (context, index) {
          final data = _tradeShortcuts[index];
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: data.color.withOpacity(0.12),
                    child: Icon(data.icon, color: data.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      data.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A1633),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarketMovers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Market Movers',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final selected = index == _moversTab;
              return GestureDetector(
                onTap: () => setState(() => _moversTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0D4EDB) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF0D4EDB)
                          : const Color(0xFFE2E7F2),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0D4EDB).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    ['Gainers', 'Losers', '52W High', '52W Low'][index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF50607C),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: 4,
          ),
        ),
        const SizedBox(height: 18),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _marketMovers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = _marketMovers[index];
            final positive = data.changePercentage >= 0;
            final color = positive
                ? const Color(0xFF2CC47F)
                : const Color(0xFFD64545);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1633).withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE4EAFF),
                    child: Icon(data.icon, color: const Color(0xFF0D4EDB)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A1633),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.exchange,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8A9F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${data.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0A1633),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${positive ? '+' : ''}${data.changeValue.toStringAsFixed(2)} (${positive ? '+' : ''}${data.changePercentage.toStringAsFixed(2)}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMarketNews() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Market News',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 18),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.refresh, size: 18, color: Color(0xFF4F5B76)),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 18),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _newsItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _newsItems[index];
            final color = item.positive
                ? const Color(0xFF2CC47F)
                : const Color(0xFFD64545);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1633).withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4EAFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.photo, color: Color(0xFF0D4EDB)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About ${item.minutesAgo} hour ago',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7F8A9F),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A1633),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${item.source} ${item.positive ? '+' : ''}${item.change.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (_) {},
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.stacked_line_chart_outlined),
          label: 'Market',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.remove_red_eye_outlined),
          label: 'Watchlist',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart_outline),
          label: 'Portfolio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.savings_outlined),
          label: 'Mutual Funds',
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF0D4EDB)
                  : const Color(0xFF8A93A6),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: 44,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0D4EDB) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestPlaceholder extends StatelessWidget {
  const _InvestPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      key: const ValueKey('invest'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1633).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE4EAFF),
            child: Icon(Icons.auto_graph, color: Color(0xFF0D4EDB), size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            'Invest tools coming soon',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Discover curated baskets, smart alerts and\nlong-term planning features tailored for you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7F8A9F),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionOverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1633).withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Position Overview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.visibility_off_outlined,
                size: 18,
                color: Color(0xFF6C7A95),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('Today'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  foregroundColor: const Color(0xFF6C7A95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '₹ * * *',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A1633),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Account Value',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F8A9F)),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    '+2.09%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2CC47F),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Since yesterday',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F8A9F)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TradingBalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1633).withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Your Trading Balance',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F8A9F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '₹15,20,000.00',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A1633),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Add Funds',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCarousel extends StatelessWidget {
  const _PromoCarousel();

  @override
  Widget build(BuildContext context) {
    final promos = [
      _PromoData(
        title: 'FREE!! Strategy Builder with Instaoptions',
        button: 'Start Trading',
        gradient: const LinearGradient(
          colors: [Color(0xFF0D4EDB), Color(0xFF2CC47F)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        icon: Icons.candlestick_chart,
      ),
      _PromoData(
        title: 'Smart SIPs with Bullstrade',
        button: 'Explore SIPs',
        gradient: const LinearGradient(
          colors: [Color(0xFF6E3EF0), Color(0xFFB88AFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        icon: Icons.show_chart,
      ),
    ];

    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.88),
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final promo = promos[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: promo.gradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1633).withOpacity(0.12),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    promo.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D4EDB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(promo.button),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      promo.icon,
                      size: 40,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PromoData {
  const _PromoData({
    required this.title,
    required this.button,
    required this.gradient,
    required this.icon,
  });

  final String title;
  final String button;
  final LinearGradient gradient;
  final IconData icon;
}

class _Shortcut {
  const _Shortcut(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class MarketIndex {
  const MarketIndex(this.name, this.value, this.change, this.changePercent);

  final String name;
  final double value;
  final double change;
  final double changePercent;
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.index});

  final MarketIndex index;

  @override
  Widget build(BuildContext context) {
    final isPositive = index.change >= 0;
    final color = isPositive
        ? const Color(0xFF2CC47F)
        : const Color(0xFFD64545);
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1633).withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              index.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A1633),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              index.value.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A1633),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${isPositive ? '+' : ''}${index.change.toStringAsFixed(2)} (${isPositive ? '+' : ''}${index.changePercent.toStringAsFixed(2)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketMover {
  const MarketMover(
    this.name,
    this.exchange,
    this.price,
    this.changeValue,
    this.changePercentage,
    this.icon,
  );

  final String name;
  final String exchange;
  final double price;
  final double changeValue;
  final double changePercentage;
  final IconData icon;
}

class MarketNews {
  const MarketNews({
    required this.minutesAgo,
    required this.title,
    required this.source,
    required this.change,
    required this.positive,
  });

  final int minutesAgo;
  final String title;
  final String source;
  final double change;
  final bool positive;
}
