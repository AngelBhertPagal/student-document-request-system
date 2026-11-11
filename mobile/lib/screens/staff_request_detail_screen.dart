import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class StaffRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const StaffRequestDetailScreen({super.key, required this.requestId});

  @override
  State<StaffRequestDetailScreen> createState() => _StaffRequestDetailScreenState();
}

class _StaffRequestDetailScreenState extends State<StaffRequestDetailScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  Map<String, dynamic>? _details;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.fetchRequestDetails(widget.requestId);
      setState(() {
        _details = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _performAction({
    required String newStatus,
    String remarks = '',
    String rejectionReason = '',
    String? deliveryMethod,
    String? recipientName,
    String? releaseNotes,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await ApiService.updateRequestStatus(
        requestId: widget.requestId,
        newStatus: newStatus,
        remarks: remarks,
        rejectionReason: rejectionReason,
        deliveryMethod: deliveryMethod,
        recipientName: recipientName,
        releaseNotes: releaseNotes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus successfully!')),
      );
      _loadDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Deficient Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter reason for deficiency (student will be notified):'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g., Unsettled library dues, missing clearance',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              _performAction(
                newStatus: 'REJECTED',
                rejectionReason: controller.text.trim(),
              );
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  void _showReleaseDialog() {
    final student = _details!['student'] ?? {};
    final recipientController = TextEditingController(
      text: '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
    );
    final notesController = TextEditingController(
      text: 'Verified student ID and released at Counter 2.',
    );
    String method = _details!['delivery_method'] ?? 'PICKUP';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Document Release'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: recipientController,
                  decoration: const InputDecoration(labelText: 'Recipient Full Name'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Delivery Method'),
                  items: const [
                    DropdownMenuItem(value: 'PICKUP', child: Text('Personal Counter Pickup')),
                    DropdownMenuItem(value: 'COURIER', child: Text('Courier / Mail Delivery')),
                    DropdownMenuItem(value: 'DIGITAL_COPY', child: Text('Digital / Soft Copy')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => method = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Release Notes / Counter #'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                if (recipientController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _performAction(
                  newStatus: 'RELEASED',
                  recipientName: recipientController.text.trim(),
                  deliveryMethod: method,
                  releaseNotes: notesController.text.trim(),
                );
              },
              child: const Text('Complete Release'),
            ),
          ],
        ),
      ),
    );
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

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_details != null ? 'Process: ${_details!['tracking_number']}' : 'Staff Review'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetails),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final status = _details!['status'] ?? 'SUBMITTED';
    final statusColor = _getStatusColor(status);
    final docType = _details!['document_type'] ?? {};
    final student = _details!['student'] ?? {};
    final studentProfile = student['student_profile'] ?? {};
    final history = (_details!['history'] as List<dynamic>?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header status card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _details!['tracking_number'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          _details!['status_display'] ?? status,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(docType['name'] ?? 'Document', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Copies: ${_details!['copies']} • Fee: PHP ${docType['fee']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Workflow Panel
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Records Office Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),

                  if (_isProcessing)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else ...[
                    if (status == 'SUBMITTED')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Start Verification'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white),
                        onPressed: () => _performAction(
                          newStatus: 'UNDER_VERIFICATION',
                          remarks: 'Initiated requirement and clearance verification.',
                        ),
                      ),

                    if (status == 'UNDER_VERIFICATION') ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Send to Processing & Printing'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        onPressed: () => _performAction(
                          newStatus: 'FOR_PROCESSING',
                          remarks: 'Requirements verified. Sent for document printing and signature.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Reject Deficient Request', style: TextStyle(color: Colors.red)),
                        onPressed: _showRejectDialog,
                      ),
                    ],

                    if (status == 'FOR_PROCESSING')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.inbox),
                        label: const Text('Mark Ready for Release / Pickup'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () => _performAction(
                          newStatus: 'READY_FOR_RELEASE',
                          remarks: 'Document printed, stamped, and ready for release at Counter 2.',
                        ),
                      ),

                    if (status == 'READY_FOR_RELEASE')
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Record Official Release Transaction'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: _showReleaseDialog,
                      ),

                    if (status == 'RELEASED')
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Document has been released. Transaction is completed.',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),

                    if (status == 'REJECTED')
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Rejected: ${_details!['rejection_reason']}',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Student Information Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Student Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text('Name: ${student['first_name'] ?? ''} ${student['last_name'] ?? ''} (${student['username']})'),
                  Text('Student ID: ${studentProfile['student_id'] ?? 'N/A'}'),
                  Text('Course: ${studentProfile['course'] ?? 'N/A'} (Year ${studentProfile['year_level'] ?? 1})'),
                  Text('Contact: ${studentProfile['contact_number'] ?? 'N/A'}'),
                  Text('Email: ${student['email'] ?? 'N/A'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Request Purpose
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stated Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_details!['purpose'] ?? 'None provided'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Audit History
          const Text('Audit History & State Transitions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final h = history[index];
              final toCol = _getStatusColor(h['to_status']);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: toCol.withValues(alpha: 0.2),
                    child: Icon(Icons.history, color: toCol, size: 20),
                  ),
                  title: Text(h['to_status'], style: TextStyle(fontWeight: FontWeight.bold, color: toCol)),
                  subtitle: Text('${h['remarks'] ?? ''}\n${_formatDate(h['timestamp'])} by ${h['changed_by_name']}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
