import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/storefront_api.dart';
import '../theme/app_theme.dart';
import 'track_order_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _ticketTitleController = TextEditingController();
  final _ticketDescController = TextEditingController();
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  String _selectedTicketCategory = "Product Advisory";
  String? _otpChallenge;
  bool _authSubmitting = false;

  @override
  void dispose() {
    _ticketTitleController.dispose();
    _ticketDescController.dispose();
    _identifierController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Hardcoded routine lists matching Stitch specification
    final List<Map<String, String>> dayRoutine = [];

    final List<Map<String, String>> nightRoutine = [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY APOTHECARY RITUALS'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
            left: 24.0, right: 24.0, top: 24.0, bottom: 120.0),
        children: [
          // Customer profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE9E2D0), Color(0xFFF8FAF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border, width: 0.8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary,
                  child: const Icon(Icons.spa_outlined,
                      size: 24, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.profileName,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appState.isCustomerSignedIn
                            ? appState.profileEmail
                            : 'Sign in to sync orders, addresses, and support.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: appState.isCustomerSignedIn
                      ? () => appState.signOutCustomer()
                      : () => _showCustomerAuthDialog(context, appState),
                  child: Text(
                    appState.isCustomerSignedIn ? 'SIGN OUT' : 'SIGN IN',
                    style: GoogleFonts.manrope(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (appState.isLoadingCustomerData) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(color: AppTheme.primary),
          ],

          const SizedBox(height: 32),

          // Saved routines section
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'MY DAILY SKINCARE RITUALS',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custom collapsible routines layout
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading:
                  const Icon(Icons.wb_sunny_outlined, color: Color(0xFFE5B556)),
              title: Text(
                'Morning Favorites',
                style: GoogleFonts.ebGaramond(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '${dayRoutine.length} steps - Hydrate & Protect',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: AppTheme.secondary),
              ),
              children: dayRoutine.isEmpty
                  ? [
                      ListTile(
                        dense: true,
                        title: Text(
                          "No ritual steps recorded yet.",
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                        ),
                      )
                    ]
                  : dayRoutine.map((r) {
                      return ListTile(
                        dense: true,
                        title: Text(r['name']!,
                            style: GoogleFonts.ebGaramond(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(r['step']!,
                            style: GoogleFonts.manrope(fontSize: 10)),
                        trailing: Icon(Icons.circle_outlined,
                            size: 14, color: AppTheme.border),
                      );
                    }).toList(),
            ),
          ),

          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(Icons.dark_mode_outlined, color: AppTheme.primary),
              title: Text(
                'Evening Favorites',
                style: GoogleFonts.ebGaramond(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '${nightRoutine.length} steps - Double Cleanse & Repair',
                style: GoogleFonts.manrope(
                    fontSize: 11, color: AppTheme.secondary),
              ),
              children: nightRoutine.isEmpty
                  ? [
                      ListTile(
                        dense: true,
                        title: Text(
                          "No ritual steps recorded yet.",
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: AppTheme.secondary,
                          ),
                        ),
                      )
                    ]
                  : nightRoutine.map((r) {
                      return ListTile(
                        dense: true,
                        title: Text(r['name']!,
                            style: GoogleFonts.ebGaramond(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(r['step']!,
                            style: GoogleFonts.manrope(fontSize: 10)),
                        trailing: Icon(Icons.circle_outlined,
                            size: 14, color: AppTheme.border),
                      );
                    }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          if (appState.checkoutEnabled) ...[
            Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'ORDER & SHIPMENT HISTORY',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondary,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (appState.orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    'No past orders recorded.',
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppTheme.secondary),
                  ),
                ),
              )
            else
              Column(
                children: appState.orders.map((order) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.id,
                            style: GoogleFonts.manrope(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Total: \$${order.total.toStringAsFixed(2)} - Tap to Track Progress',
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: AppTheme.secondary),
                        ),
                      ),
                      trailing: Icon(Icons.keyboard_arrow_right,
                          size: 16, color: AppTheme.primary),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TrackOrderScreen(orderId: order.id),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
          ],

          const SizedBox(height: 32),

          if (appState.supportEnabled) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent_outlined,
                        color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'APOTHECARY EXPERT ASSISTANCE',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.add, color: AppTheme.primary, size: 18),
                  onPressed: () => _showCreateTicketDialog(context, appState),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (appState.tickets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    'No active requests.',
                    style: GoogleFonts.manrope(
                        fontSize: 12, color: AppTheme.secondary),
                  ),
                ),
              )
            else
              Column(
                children: appState.tickets.map((ticket) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ticket.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.ebGaramond(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ticket.status == "Open"
                                  ? AppTheme.accent.withValues(alpha: 0.4)
                                  : AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ticket.status,
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: ticket.status == "Open"
                                    ? AppTheme.primary
                                    : AppTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Category: ${ticket.category} - ${ticket.messages.length} messages',
                          style: GoogleFonts.manrope(
                              fontSize: 11, color: AppTheme.secondary),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios,
                          size: 12, color: AppTheme.primary),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                TicketThreadScreen(ticket: ticket),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }

  void _showCustomerAuthDialog(BuildContext context, AppState state) {
    _otpChallenge = null;
    _otpController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Customer Sign In',
                style: GoogleFonts.ebGaramond(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.manrope(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Email or phone',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                  ),
                  if (_otpChallenge != null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.manrope(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'Verification code',
                        prefixIcon: Icon(Icons.password_outlined, size: 18),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      _authSubmitting ? null : () => Navigator.pop(context),
                  child: Text('CANCEL',
                      style: GoogleFonts.manrope(
                          color: AppTheme.secondary, fontSize: 12)),
                ),
                ElevatedButton(
                  onPressed: _authSubmitting
                      ? null
                      : () async {
                          final identifier = _identifierController.text.trim();
                          if (identifier.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Enter an email or phone number.')),
                            );
                            return;
                          }

                          setDialogState(() => _authSubmitting = true);
                          try {
                            if (_otpChallenge == null) {
                              final response =
                                  await state.requestCustomerOtp(identifier);
                              final challenge =
                                  response['challenge']?.toString() ??
                                      response['otp_challenge']?.toString() ??
                                      response['token']?.toString();
                              if (challenge == null || challenge.isEmpty) {
                                throw const StorefrontApiException(
                                    'The server did not return an OTP challenge.');
                              }
                              setDialogState(() => _otpChallenge = challenge);
                            } else {
                              await state.verifyCustomerOtp(
                                identifier: identifier,
                                challenge: _otpChallenge!,
                                code: _otpController.text.trim(),
                              );
                              if (context.mounted) Navigator.pop(context);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => _authSubmitting = false);
                            }
                          }
                        },
                  child: Text(_otpChallenge == null ? 'SEND CODE' : 'VERIFY'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Create Ticket Dialog
  void _showCreateTicketDialog(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(
                'File Skincare Ticket',
                style: GoogleFonts.ebGaramond(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request Category',
                      style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTicketCategory,
                          isExpanded: true,
                          items: [
                            "Product Advisory",
                            "Product Issue",
                            "Fulfillment Case",
                            "Other"
                          ].map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat,
                                  style: GoogleFonts.manrope(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(
                                  () => _selectedTicketCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ticket Title',
                      style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ticketTitleController,
                      style: GoogleFonts.manrope(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "e.g. Irritation advisory question",
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Question / Description',
                      style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _ticketDescController,
                      maxLines: 3,
                      style: GoogleFonts.manrope(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "Describe your skin concerns or request...",
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL',
                      style: GoogleFonts.manrope(
                          color: AppTheme.secondary, fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    minimumSize: const Size(80, 36),
                  ),
                  onPressed: () {
                    if (_ticketTitleController.text.trim().isEmpty ||
                        _ticketDescController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill out all fields.')),
                      );
                      return;
                    }
                    state.createTicket(
                      _ticketTitleController.text.trim(),
                      _selectedTicketCategory,
                      _ticketDescController.text.trim(),
                    );
                    _ticketTitleController.clear();
                    _ticketDescController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('SUBMIT'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Support Ticket Thread Details
class TicketThreadScreen extends StatefulWidget {
  final SupportTicket ticket;

  const TicketThreadScreen({super.key, required this.ticket});

  @override
  State<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends State<TicketThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final ticket = appState.tickets.firstWhere((t) => t.id == widget.ticket.id,
        orElse: () => widget.ticket);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.title),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Case Reference: ${ticket.id}',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppTheme.secondary,
                  ),
                ),
                Text(
                  ticket.category.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: ticket.messages.length,
              itemBuilder: (context, index) {
                final message = ticket.messages[index];
                final isCustomer = message.sender == "customer";
                return Align(
                  alignment:
                      isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCustomer ? AppTheme.primary : Colors.white,
                      border: isCustomer
                          ? null
                          : Border.all(color: AppTheme.border, width: 0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isCustomer
                            ? const Radius.circular(12)
                            : const Radius.circular(0),
                        bottomRight: isCustomer
                            ? const Radius.circular(0)
                            : const Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCustomer ? appState.profileName : "Store Advisor",
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCustomer
                                ? AppTheme.accent
                                : AppTheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message.content,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: isCustomer ? Colors.white : AppTheme.primary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.manrope(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: "Type your message to the store advisor...",
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      if (_messageController.text.trim().isEmpty) return;
                      appState.sendMessageToTicket(
                          ticket.id, _messageController.text.trim());
                      _messageController.clear();
                      _scrollToBottom();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
