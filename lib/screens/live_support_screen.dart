import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart'; // To use TicketThreadScreen
import '../widgets/app_refresh.dart';
import '../widgets/top_toast.dart';

class LiveSupportScreen extends StatefulWidget {
  const LiveSupportScreen({super.key});

  @override
  State<LiveSupportScreen> createState() => _LiveSupportScreenState();
}

class _LiveSupportScreenState extends State<LiveSupportScreen> {
  final _ticketTitleController = TextEditingController();
  final _ticketDescController = TextEditingController();
  String _selectedTicketCategory = "Product Advisory";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        if (appState.supportEnabled) {
          appState.loadSupportTickets();
        }
      }
    });
  }

  @override
  void dispose() {
    _ticketTitleController.dispose();
    _ticketDescController.dispose();
    super.dispose();
  }

  void _showCreateTicketBottomSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24,
                  MediaQuery.of(sheetContext).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NEW SKINCARE CONSULTATION',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ebGaramond(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primary,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'CONSULTATION CATEGORY',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTicketCategory,
                          isExpanded: true,
                          style: GoogleFonts.manrope(
                              fontSize: 13, color: AppTheme.primary),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          items: [
                            "Product Advisory",
                            "Product Issue",
                            "Fulfillment Case",
                            "Other"
                          ].map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(
                                  () => _selectedTicketCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'SUBJECT / TITLE',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ticketTitleController,
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText: "e.g. Skin routine advice",
                        prefixIcon: Icon(Icons.title,
                            size: 16, color: AppTheme.secondary),
                        filled: true,
                        fillColor: AppTheme.background.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.border.withValues(alpha: 0.6),
                              width: 0.8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 1.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'RITUAL ENQUIRY DETAILS',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ticketDescController,
                      maxLines: 4,
                      style: GoogleFonts.manrope(
                          fontSize: 13, color: AppTheme.primary),
                      decoration: InputDecoration(
                        hintText:
                            "Describe your skin concerns or request in detail...",
                        filled: true,
                        fillColor: AppTheme.background.withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.border.withValues(alpha: 0.6),
                              width: 0.8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 1.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: AppTheme.primary, width: 1.0),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: GoogleFonts.manrope(
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final title = _ticketTitleController.text.trim();
                              final desc = _ticketDescController.text.trim();

                              if (title.isEmpty || desc.isEmpty) {
                                showTopToast(
                                    context, 'Please fill out all fields.');
                                return;
                              }

                              state.createTicket(
                                  title, _selectedTicketCategory, desc);
                              _ticketTitleController.clear();
                              _ticketDescController.clear();
                              Navigator.pop(sheetContext);

                              showTopToast(context,
                                  'Consultation ticket created successfully!');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'SUBMIT',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tickets = appState.tickets;
    final colors = Theme.of(context).colorScheme;
    final supportEnabled = appState.supportEnabled;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'EXPERT CONSULTATION',
          style: GoogleFonts.ebGaramond(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: colors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: !supportEnabled
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'Customer support is unavailable for this store.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                ),
              )
            : AppRefresh(
                child: tickets.isEmpty
                    ? _buildEmptyState(context, appState, colors)
                    : _buildTicketsList(context, tickets),
              ),
      ),
      floatingActionButton: !supportEnabled || tickets.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateTicketBottomSheet(context, appState),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add_comment_outlined,
                  color: Colors.white, size: 20),
              label: Text(
                'ASK EXPERT',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, AppState appState, ColorScheme colors) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.support_agent_outlined,
                      color: AppTheme.secondary,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Inquiries Yet',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with our licensed advisors to receive premium advice, resolve orders, or customize your routines.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.secondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showCreateTicketBottomSheet(context, appState),
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: Text(
                      'Create a  New Ticket',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTicketsList(BuildContext context, List<dynamic> tickets) {
    return ListView.builder(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(24),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final ticket = tickets[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.border.withValues(alpha: 0.5), width: 0.8),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ticket.status.toLowerCase() == "open"
                        ? const Color(0xFFFEF2E5)
                        : ticket.status.toLowerCase() == "closed"
                            ? const Color(0xFFF0F0F0)
                            : const Color(0xFFE2F3E5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    ticket.status.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: ticket.status.toLowerCase() == "open"
                          ? const Color(0xFFB35E00)
                          : ticket.status.toLowerCase() == "closed"
                              ? const Color(0xFF888888)
                              : const Color(0xFF1E6C2E),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Category: ${ticket.category}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.secondary,
                    ),
                  ),
                  Text(
                    '${ticket.messages.length} messages',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 12, color: AppTheme.primary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketThreadScreen(ticket: ticket),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
