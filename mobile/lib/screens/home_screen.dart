import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'request_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getSavedUser();
    setState(() {
      _user = user;
    });
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
          _MyRequestsTab(onNavigateToNew: () => setState(() => _currentIndex = 1)),
          _NewRequestTab(onRequestCreated: () => setState(() => _currentIndex = 0)),
          const _NotificationsTab(),
          _ProfileTab(user: _user, onLogout: _handleLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'New Request',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: MY REQUESTS
// ==========================================
class _MyRequestsTab extends StatefulWidget {
  final VoidCallback onNavigateToNew;
  const _MyRequestsTab({required this.onNavigateToNew});

  @override
  State<_MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<_MyRequestsTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _requests = [];
  String _selectedFilter = '';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.fetchMyRequests(
        statusFilter: _selectedFilter.isNotEmpty ? _selectedFilter : null,
      );
      setState(() {
        _requests = data;
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
        title: const Text('My Document Requests'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', ''),
                _buildFilterChip('Submitted', 'SUBMITTED'),
                _buildFilterChip('Under Verification', 'UNDER_VERIFICATION'),
                _buildFilterChip('For Processing', 'FOR_PROCESSING'),
                _buildFilterChip('Ready for Release', 'READY_FOR_RELEASE'),
                _buildFilterChip('Released', 'RELEASED'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Request List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_errorMessage!),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _loadRequests, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _requests.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                const Text('No document requests found.'),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: widget.onNavigateToNew,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Submit a Request'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRequests,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _requests.length,
                              itemBuilder: (context, index) {
                                final req = _requests[index];
                                final status = req['status'] ?? 'SUBMITTED';
                                final statusDisplay = req['status_display'] ?? status;
                                final color = _getStatusColor(status);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    title: Text(
                                      req['document_type_name'] ?? 'Document',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Tracking: ${req['tracking_number']}'),
                                        Text('Copies: ${req['copies']} • Fee: PHP ${req['document_type_fee']}'),
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: color),
                                          ),
                                          child: Text(
                                            statusDisplay,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RequestDetailScreen(requestId: req['id']),
                                        ),
                                      ).then((_) => _loadRequests());
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
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : '';
          });
          _loadRequests();
        },
      ),
    );
  }
}

// ==========================================
// TAB 2: NEW REQUEST
// ==========================================
class _NewRequestTab extends StatefulWidget {
  final VoidCallback onRequestCreated;
  const _NewRequestTab({required this.onRequestCreated});

  @override
  State<_NewRequestTab> createState() => _NewRequestTabState();
}

class _NewRequestTabState extends State<_NewRequestTab> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  int _copies = 1;
  String _deliveryMethod = 'PICKUP';
  int? _selectedDocTypeId;

  List<dynamic> _docTypes = [];
  bool _isLoadingTypes = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTypes();
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _fetchTypes() async {
    try {
      final types = await ApiService.fetchDocumentTypes();
      setState(() {
        _docTypes = types;
        if (_docTypes.isNotEmpty) {
          _selectedDocTypeId = _docTypes.first['id'];
        }
        _isLoadingTypes = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load document catalog.';
        _isLoadingTypes = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedDocTypeId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.createRequest(
        documentTypeId: _selectedDocTypeId!,
        copies: _copies,
        purpose: _purposeController.text.trim(),
        deliveryMethod: _deliveryMethod,
      );

      if (!mounted) return;

      // Show success dialog with tracking code
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request Submitted!',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your request has been successfully recorded.'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tracking Number:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    SelectableText(
                      result['tracking_number'] ?? 'N/A',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('You will be notified as records office processes your document.', style: TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _purposeController.clear();
                _copies = 1;
                widget.onRequestCreated();
              },
              child: const Text('View Requests'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTypes) {
      return const Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: SizedBox(),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final selectedDoc = _docTypes.firstWhere(
      (d) => d['id'] == _selectedDocTypeId,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Academic Document'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ),

              // Document Selection
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _selectedDocTypeId,
                decoration: const InputDecoration(
                  labelText: 'Select Document Type',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _docTypes.map<DropdownMenuItem<int>>((doc) {
                  return DropdownMenuItem<int>(
                    value: doc['id'],
                    child: Text(
                      '${doc['name']} (PHP ${doc['fee']})',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDocTypeId = val);
                },
              ),
              const SizedBox(height: 12),

              // Document info card
              if (selectedDoc != null)
                Card(
                  color: Colors.blue[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Processing: ${selectedDoc['processing_days']} business days',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requirements: ${selectedDoc['requirements_info']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Copies counter
              Row(
                children: [
                  const Text('Number of Copies:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _copies > 1 ? () => setState(() => _copies--) : null,
                  ),
                  Text('$_copies', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _copies < 5 ? () => setState(() => _copies++) : null,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Delivery Method
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _deliveryMethod,
                decoration: const InputDecoration(
                  labelText: 'Preferred Release / Delivery Method',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'PICKUP', child: Text('Personal Counter Pickup')),
                  DropdownMenuItem(value: 'COURIER', child: Text('Courier / Mail Delivery')),
                  DropdownMenuItem(value: 'DIGITAL_COPY', child: Text('Digital / E-Mail Soft Copy')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _deliveryMethod = val);
                },
              ),
              const SizedBox(height: 16),

              // Purpose text field
              TextFormField(
                controller: _purposeController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Request',
                  hintText: 'e.g., Scholarship application, Employment, Graduate school requirement',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please specify purpose' : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitRequest,
                icon: const Icon(Icons.send_rounded),
                label: _isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TAB 3: NOTIFICATIONS
// ==========================================
class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchNotifications();
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Notifications'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadNotifications),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No notifications yet.'))
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['is_read'] ?? false;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isRead ? Colors.grey[200] : Colors.blue[100],
                          child: Icon(
                            isRead ? Icons.notifications_none : Icons.notifications_active,
                            color: isRead ? Colors.grey : Colors.blue[800],
                          ),
                        ),
                        title: Text(
                          notif['title'] ?? '',
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notif['message'] ?? ''),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(notif['created_at']),
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ==========================================
// TAB 4: PROFILE
// ==========================================
class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onLogout;

  const _ProfileTab({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final profile = user?['student_profile'] ?? {};
    final fullName = '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              fullName.isNotEmpty ? fullName : (user?['username'] ?? 'Student'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              user?['email'] ?? '',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Student ID'),
                    subtitle: Text(profile['student_id'] ?? 'N/A'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Course / Program'),
                    subtitle: Text(profile['course'] ?? 'N/A'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.stairs_outlined),
                    title: const Text('Year Level'),
                    subtitle: Text('${profile['year_level'] ?? 1} Year'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Contact Number'),
                    subtitle: Text(profile['contact_number'] ?? 'N/A'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

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
