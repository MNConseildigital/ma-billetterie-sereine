import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/ticket_model.dart';
import '../services/tickets_service.dart';

class TransferTicketPage extends StatefulWidget {
  final TicketModel ticket;

  const TransferTicketPage({
    super.key,
    required this.ticket,
  });

  @override
  State<TransferTicketPage> createState() => _TransferTicketPageState();
}

class _TransferTicketPageState extends State<TransferTicketPage> {
  final TextEditingController _emailController = TextEditingController();
  final TicketsService _ticketsService = TicketsService();

  bool _isSending = false;

  Future<void> _transferTicket() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un email')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _ticketsService.transferTicketToUser(
        ticketId: widget.ticket.id,
        targetEmail: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billet transmis avec succès')),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transmettre un billet'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.premiumBlack,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transmission sécurisée',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Vous allez transmettre ce billet : ${widget.ticket.eventName}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.ticket.date} • ${widget.ticket.time}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email du destinataire',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _transferTicket,
              icon: const Icon(Icons.send_outlined),
              label: _isSending
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
                  : const Text('Transmettre le billet'),
            ),
          ),
        ],
      ),
    );
  }
}