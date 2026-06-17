// lib/pages/transaction_history_page.dart
//
// Historique des transactions --- Ma Billetterie Sereine

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../providers/auth_provider.dart';
import '../services/transaction_service.dart';
import 'ticket_detail_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Date inconnue';
    if (timestamp is! Timestamp) return timestamp.toString();

    final date = timestamp.toDate();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).user?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Historique')),
        body: const Center(
          child: Text(
            'Connectez-vous pour voir votre historique.',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Vendus', icon: Icon(Icons.arrow_upward)),
            Tab(text: 'Achetés', icon: Icon(Icons.arrow_downward)),
            Tab(text: 'En attente', icon: Icon(Icons.hourglass_empty)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Onglet VENDUS ───────────────────────────────────
          _buildSoldTab(currentUserId),
          // ── Onglet ACHETÉS ──────────────────────────────────
          _buildBoughtTab(currentUserId),
          // ── Onglet EN ATTENTE ───────────────────────────────
          _buildPendingTab(currentUserId),
        ],
      ),
    );
  }

  // ── VENDUS ────────────────────────────────────────────────────
  Widget _buildSoldTab(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _transactionService.getSoldTickets(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.sell_outlined,
            title: 'Aucune vente',
            subtitle: 'Les billets que vous vendrez apparaîtront ici.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final ticket = item['ticket'] as TicketModel;
            final date = _formatDate(item['date']);

            return _TransactionCard(
              ticket: ticket,
              date: date,
              type: 'vendu',
              onTap: () => _showTicketDetail(ticket),
            );
          },
        );
      },
    );
  }

  // ── ACHETÉS ───────────────────────────────────────────────────
  Widget _buildBoughtTab(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _transactionService.getBoughtTickets(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'Aucun achat',
            subtitle: 'Les billets que vous achèterez apparaîtront ici.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final ticket = item['ticket'] as TicketModel;
            final date = _formatDate(item['date']);

            return _TransactionCard(
              ticket: ticket,
              date: date,
              type: 'achete',
              onTap: () => _showTicketDetail(ticket),
            );
          },
        );
      },
    );
  }

  // ── EN ATTENTE ────────────────────────────────────────────────
  Widget _buildPendingTab(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _transactionService.getPendingRequests(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.hourglass_empty,
            title: 'Aucune demande',
            subtitle: 'Les demandes d\'achat en attente apparaîtront ici.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.pending_actions,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req['eventName'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Demandé par : ${req['buyerEmail']}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              _formatDate(req['createdAt']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptRequest(req),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accepter'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectRequest(req['id']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Refuser'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 70,
              color: AppTheme.primaryGold.withOpacity(0.5),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetail(TicketModel ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketDetailPage(ticket: ticket),
      ),
    );
  }

  Future<void> _acceptRequest(Map<String, dynamic> req) async {
    try {
      await _transactionService.acceptPurchaseRequest(
        requestId: req['id'],
        ticketId: req['ticketId'] ?? '',
        buyerUserId: req['buyerUserId'],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande acceptée ! Billet transféré.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _transactionService.rejectPurchaseRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande refusée.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}

// ── Card transaction ───────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final TicketModel ticket;
  final String date;
  final String type;
  final VoidCallback onTap;

  const _TransactionCard({
    required this.ticket,
    required this.date,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSold = type == 'vendu';
    final color = isSold ? AppTheme.successGreen : Colors.blue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSold ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.eventName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ticket.date} • ${ticket.place}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transféré le : $date',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}