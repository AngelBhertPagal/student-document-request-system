import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'staff_request_detail_screen.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getSavedUser();
    setState(() => _user = user);
  }

  void _handleLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _StaffQueueTab(),
          const _StaffAnalyticsTab(),
          _StaffProfileTab(user: _user, onLogout: _handleLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Staff Profile',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: STAFF QUEUE
// ==========================================
class _StaffQueueTab extends StatefulWidget {
  const _StaffQueueTab();

  @override
  State<_StaffQueueTab> createState() => _StaffQueueTabState();
}

class _StaffQueueTabState extends State<_StaffQueueTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _requests = [];
  String _selectedFilter = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.fetchMyRequests(
        statusFilter: _selectedFilter.isNotEmpty ? _selectedFilter : null,
      );

      final query = _searchController.text.trim().toLowerCase();
      final filtered = query.isEmpty
          ? list
          : list.where((item) {
              final tracking = (item['tracking_number'] ?? '').toString().toLowerCase();
              final student = (item['student_name'] ?? '').toString().toLowerCase();
              final doc = (item['document_type_name'] ?? '').toString().toLowerCase();
              return tracking.contains(query) || student.contains(query) || doc.contains(query);
            }).toList();

      setState(() {
        _requests = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.blue;
      case 'UNDER_VERIFICATION':
        return Colors.orange;
      case 'FOR_PROCESSING':
        return Colors.purple;
      case 'READY_FOR_RELEASE':
        return Colors.teal;
      case 'RELEASED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records Office Queue'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadQueue),
        ],
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tracking #, student, document...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadQueue();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => _loadQueue(),
            ),
          ),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All', ''),
                _buildFilterChip('Submitted', 'SUBMITTED'),
                _buildFilterChip('Under Verification', 'UNDER_VERIFICATION'),
                _buildFilterChip('For Processing', 'FOR_PROCESSING'),
                _buildFilterChip('Ready for Release', 'READY_FOR_RELEASE'),
                _buildFilterChip('Released', 'RELEASED'),
                _buildFilterChip('Rejected', 'REJECTED'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Requests List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!),
                            ElevatedButton(onPressed: _loadQueue, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _requests.isEmpty
                        ? const Center(child: Text('No requests in this queue.'))
                        : RefreshIndicator(
                            onRefresh: _loadQueue,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final req = _requests[index];
                                final status = req['status'] ?? 'SUBMITTED';
                                final statusDisplay = req['status_display'] ?? status;
                                final color = _getStatusColor(status);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(14),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            req['tracking_number'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: color),
                                          ),
                                          child: Text(
                                            statusDisplay,
                                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Text(
                                          'Student: ${req['student_name']} (${req['student_id'] ?? 'N/A'})',
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Text('Document: ${req['document_type_name']} • ${req['copies']} copy/ies'),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StaffRequestDetailScreen(requestId: req['id']),
                                        ),
                                      ).then((_) => _loadQueue());
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedFilter = selected ? value : '');
          _loadQueue();
        },
      ),
    );
  }
}

// ==========================================
// TAB 2: STAFF ANALYTICS
// ==========================================
class _StaffAnalyticsTab extends StatefulWidget {
  const _StaffAnalyticsTab();

  @override
  State<_StaffAnalyticsTab> createState() => _StaffAnalyticsTabState();
}

class _StaffAnalyticsTabState extends State<_StaffAnalyticsTab> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchStats();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Dashboard & Stats'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStats),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatCard('Total Requests', _stats?['total_requests'] ?? 0, Colors.blueGrey, Icons.folder),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Under Verification', _stats?['under_verification'] ?? 0, Colors.orange, Icons.search)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('For Processing', _stats?['for_processing'] ?? 0, Colors.purple, Icons.print)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('Ready for Release', _stats?['ready_for_release'] ?? 0, Colors.teal, Icons.inbox)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Officially Released', _stats?['released'] ?? 0, Colors.green, Icons.check_circle)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatCard('Rejected Deficient', _stats?['rejected'] ?? 0, Colors.red, Icons.cancel),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 3: STAFF PROFILE
// ==========================================
class _StaffProfileTab extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;

  const _StaffProfileTab({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final fullName = '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Color(0xFF1E3A8A),
              child: Icon(Icons.shield_outlined, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              fullName.isNotEmpty ? fullName : (user?['username'] ?? 'Staff'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Records Personnel', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_circle),
                    title: const Text('Username'),
                    subtitle: Text(user?['username'] ?? 'N/A'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.apartment),
                    title: const Text('Department'),
                    subtitle: const Text('Office of the University Registrar'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(user?['email'] ?? 'staff@univ.edu.ph'),
                  ),
                ],
              ),
            ),
            const Spacer(),

            OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
