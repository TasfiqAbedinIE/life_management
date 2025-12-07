import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'couple_repository.dart';

/// TODO: replace this import/placeholder with your real dashboard page.
import 'coupled_dashboard_page.dart';

class CoupledRequestPage extends StatefulWidget {
  const CoupledRequestPage({super.key});

  @override
  State<CoupledRequestPage> createState() => _CoupledRequestPageState();
}

class _CoupledRequestPageState extends State<CoupledRequestPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final CoupleRepository _repo;
  bool _loadingStatus = true;
  bool _sending = false;
  bool _responding = false;

  Map<String, dynamic>? _existingCouple;
  String? _feedback;

  bool _isSenderPending = false;
  bool _isReceiverPending = false;
  String? _partnerName;
  String? _partnerEmail;

  bool _redirectingToDashboard = false;

  static const String _bgImage = 'assets/coupled_images/couple-2.png';

  @override
  void initState() {
    super.initState();
    _repo = CoupleRepository(Supabase.instance.client);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    final couple = await _repo.fetchExistingCouple();

    bool isSenderPending = false;
    bool isReceiverPending = false;
    String? partnerName;
    String? partnerEmail;
    String? statusLocal;

    if (couple != null && user != null) {
      final status = couple['status'] as String?;
      statusLocal = status;
      final user1Id = couple['user1_id'] as String?;
      final user2Id = couple['user2_id'] as String?;
      final invitedEmail = couple['invited_email'] as String?;

      if (status == 'pending') {
        if (user1Id == user.id) {
          isSenderPending = true;
          partnerEmail = invitedEmail;
        } else if (user2Id == user.id) {
          isReceiverPending = true;
          final otherId = user1Id;
          if (otherId != null) {
            final profileRes = await client
                .from('profiles')
                .select('email')
                .eq('id', otherId)
                .maybeSingle();

            if (profileRes != null) {
              partnerEmail = profileRes['email'] as String?;
            }
          }
        }
      } else if (status == 'active') {
        final otherId = user.id == user1Id ? user2Id : user1Id;
        if (otherId != null) {
          final profileRes = await client
              .from('profiles')
              .select('email')
              .eq('id', otherId)
              .maybeSingle();

          if (profileRes != null) {
            partnerEmail = profileRes['email'] as String?;
          }
        }
      }
    }

    setState(() {
      _existingCouple = couple;
      _isSenderPending = isSenderPending;
      _isReceiverPending = isReceiverPending;
      _partnerName = partnerName;
      _partnerEmail = partnerEmail;
      _loadingStatus = false;
    });

    // ⭐ If already active → go straight to coupled dashboard
    if (statusLocal == 'active') {
      _navigateToDashboard();
    }
  }

  Future<void> _onSend() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _feedback = null;
    });

    final msg = await _repo.sendCoupleRequest(_emailController.text);

    setState(() {
      _sending = false;
      _feedback = msg ?? 'Love request sent successfully! 💌';
    });

    if (msg == null) {
      _emailController.clear();
      _loadStatus();
    }
  }

  /// Receiver tapped "Accept" → show date picker, then save & navigate.
  Future<void> _onAccept() async {
    if (_existingCouple == null) return;

    // 1) Show anniversary date picker (modal)
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
      helpText: 'Select your anniversary date',
      confirmText: 'Save',
    );

    if (picked == null) {
      // User cancelled the date picker
      return;
    }

    // 2) Save to DB as relationship_date + status = 'active'
    setState(() {
      _responding = true;
      _feedback = null;
    });

    final msg = await _repo.acceptRequestWithDate(
      coupleId: _existingCouple!['id'] as String,
      anniversaryDate: picked,
    );

    setState(() {
      _responding = false;
      _feedback =
          msg ??
          'You are now officially coupled 💞\nAnniversary: ${picked.toLocal().toString().split(' ').first}';
    });

    if (msg != null) {
      // Some error happened – stay on this page and show message.
      return;
    }

    // 3) Navigate to Coupled Dashboard screen
    // You can change this to a named route if you prefer.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CoupledDashboardPage()),
    );
  }

  /// Receiver tapped "Decline".
  Future<void> _onDecline() async {
    if (_existingCouple == null) return;

    setState(() {
      _responding = true;
      _feedback = null;
    });

    final msg = await _repo.declineRequest(_existingCouple!['id'] as String);

    setState(() {
      _responding = false;
      _feedback =
          msg ?? 'Request declined. You can send or receive new requests now.';
    });

    if (msg == null) {
      _loadStatus();
    }
  }

  void _navigateToDashboard() {
    if (!mounted || _redirectingToDashboard) return;
    _redirectingToDashboard = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CoupledDashboardPage()),
      );
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔙 Back to dashboard
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.pink.shade700,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFC1CC), Color(0xFFFFE4E1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(
                  _bgImage,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: _loadingStatus
                      ? const CircularProgressIndicator()
                      : _existingCoupleView(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _existingCoupleView(BuildContext context) {
    final status = _existingCouple?['status'] as String?;

    // Case 1: Receiver sees Accept / Decline
    if (status == 'pending' && _isReceiverPending) {
      return _receiverPendingCard();
    }

    // Case 2: Sender sees "request sent"
    if (status == 'pending' && _isSenderPending) {
      return _romanticCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Love Request Sent 💌',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _partnerEmail != null
                  ? 'You already sent a couple request to\n$_partnerEmail.\n\nNow just wait for your better half to say “Yes” 💕'
                  : 'You already sent a couple request.\nNow just wait for your better half to say “Yes” 💕',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.pink.shade700),
            ),
          ],
        ),
      );
    }

    // Case 3: Active couple
    if (status == 'active') {
      return _romanticCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'You Are Already Coupled 💞',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _partnerEmail != null
                  ? 'You and $_partnerEmail are together now.\nNext step: enjoy your journey together! 🌙'
                  : 'You already have your person.\nNext step: enjoy your journey together! 🌙',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.pink.shade700),
            ),
          ],
        ),
      );
    }

    // Case 4: No active/pending → send form
    return _sendRequestForm(context);
  }

  Widget _receiverPendingCard() {
    final displayName = _partnerName ?? 'Someone special';
    final emailText = _partnerEmail != null ? '\n($_partnerEmail)' : '';

    return _romanticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Someone Chose You 💘',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '$displayName$emailText\n\nwants to be your partner.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.pink.shade700),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _responding ? null : _onAccept,
                  icon: const Icon(Icons.favorite),
                  label: Text(
                    _responding ? 'Processing...' : 'Accept 💞',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _responding ? null : _onDecline,
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    side: BorderSide(color: Colors.pink.shade300),
                    foregroundColor: Colors.pink.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_feedback != null)
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _feedback!.contains('now officially')
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sendRequestForm(BuildContext context) {
    return _romanticCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Find Your Better Half 💖',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a couple request and start counting\n'
            'every beautiful day together.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.pink.shade700),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Partner\'s Email',
                prefixIcon: const Icon(Icons.mail_outline),
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Please enter an email.';
                if (!v.contains('@')) return 'Enter a valid email.';
                return null;
              },
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _onSend,
              icon: const Icon(Icons.favorite_border),
              label: Text(
                _sending ? 'Sending Love...' : 'Send Love Request 💌',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                elevation: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_feedback != null)
            Text(
              _feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _feedback!.contains('successfully')
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite, size: 16, color: Colors.pink),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Your partner will see this request\nwhen they open the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _romanticCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.88),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 2,
            color: Colors.pink.withOpacity(0.25),
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.pinkAccent.withOpacity(0.5),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}
