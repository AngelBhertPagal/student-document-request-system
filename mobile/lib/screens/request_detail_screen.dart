import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final int requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  bool _isLoading = true;
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
        title: Text(_details != null ? _details!['tracking_number'] : 'Request Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadDetails, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final docType = _details!['document_type'] ?? {};
    final status = _details!['status'] ?? 'SUBMITTED';
    final statusDisplay = _details!['status_display'] ?? status;
    final statusColor = _getStatusColor(status);
    final history = (_details!['history'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadDetails,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                            statusDisplay,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      docType['name'] ?? 'Document',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Copies: ${_details!['copies']} • Fee: PHP ${docType['fee'] ?? '0.00'}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submitted: ${_formatDate(_details!['created_at'])}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rejection banner if rejected
            if (status == 'REJECTED')
              Card(
                color: Colors.red[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Request Deficient / Rejected', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            const SizedBox(height: 4),
                            Text(_details!['rejection_reason'] ?? 'Requirements not met.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Release info card
            if (status == 'RELEASED' || status == 'READY_FOR_RELEASE')
              Card(
                color: Colors.green[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(status == 'RELEASED' ? Icons.check_circle : Icons.inventory_2, color: Colors.green[800]),
                          const SizedBox(width: 8),
                          Text(
                            status == 'RELEASED' ? 'Document Released' : 'Ready for Claim / Delivery',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Delivery Method: ${_details!['delivery_method']}'),
                      if (_details!['recipient_name'] != null && _details!['recipient_name'].isNotEmpty)
                        Text('Recipient: ${_details!['recipient_name']}'),
                      if (_details!['released_at'] != null)
                        Text('Released on: ${_formatDate(_details!['released_at'])}'),
                      if (_details!['release_notes'] != null && _details!['release_notes'].isNotEmpty)
                        Text('Notes: ${_details!['release_notes']}'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Purpose & Requirements Details
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Request Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_details!['purpose'] ?? 'None provided'),
                    const Divider(height: 24),
                    const Text('Document Guidelines', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      docType['requirements_info'] ?? 'Standard university clearance applies.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Timeline / History section
            const Text(
              'Status Timeline & Audit History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (history.isEmpty)
              const Text('No status transitions recorded yet.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final h = history[index];
                  final toStatus = h['to_status'];
                  final col = _getStatusColor(toStatus);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (index < history.length - 1)
                            Container(
                              width: 2,
                              height: 44,
                              color: Colors.grey[300],
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                toStatus,
                                style: TextStyle(fontWeight: FontWeight.bold, color: col),
                              ),
                              if (h['remarks'] != null && h['remarks'].isNotEmpty)
                                Text(
                                  h['remarks'],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              Text(
                                '${_formatDate(h['timestamp'])} • by ${h['changed_by_name'] ?? 'System'}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
