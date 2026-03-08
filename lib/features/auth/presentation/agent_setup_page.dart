import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../navigation/main_navigation.dart';

// ═══════════════════════════════════════════════════════════════
//  AGENT SETUP PAGE
//
//  Step 1 — Personal details (name, city)
//  Step 2 — Add vehicles (can add multiple)
//  Step 3 — Pending verification screen
// ═══════════════════════════════════════════════════════════════

class AgentSetupPage extends StatefulWidget {
  final String userId;
  const AgentSetupPage({super.key, required this.userId});

  @override
  State<AgentSetupPage> createState() => _AgentSetupPageState();
}

class _AgentSetupPageState extends State<AgentSetupPage> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  int _step = 0; // 0=personal, 1=vehicles, 2=pending
  bool _loading = false;
  String? _error;

  final List<DeliveryVehicle> _vehicles = [];
  final _uuid = const Uuid();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      _nameCtrl.text.trim().length >= 2 &&
          _cityCtrl.text.trim().length >= 2;

  bool get _step2Valid => _vehicles.isNotEmpty;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<DeliveryRepository>().registerAgent(
        userId: widget.userId,
        name: _nameCtrl.text.trim(),
        phone: '',
        city: _cityCtrl.text.trim(),
        vehicles: _vehicles,
      );
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _error = 'Registration failed. Please try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _addVehicle(VehicleType type, String plate, String description) {
    setState(() {
      _vehicles.add(DeliveryVehicle(
        id: _uuid.v4(),
        type: type,
        plate: plate,
        description: description,
        isVerified: false,
        addedAt: DateTime.now(),
      ));
    });
  }

  void _removeVehicle(String id) {
    setState(() => _vehicles.removeWhere((v) => v.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: _step == 2
            ? _PendingScreen(isDark: isDark)
            : Column(
          children: [
            _TopBar(
              step: _step,
              onBack: _step == 1
                  ? () => setState(() => _step = 0)
                  : null,
              isDark: isDark,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Header
                    Text(
                      _step == 0
                          ? 'Tell us about you'
                          : 'Your vehicles',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _step == 0
                          ? 'This is your delivery agent profile'
                          : 'Add all vehicles you own. More vehicles = more jobs.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.darkTextTertiary
                            : AppTheme.lightTextTertiary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    if (_step == 0)
                      _Step1Personal(
                        nameCtrl: _nameCtrl,
                        cityCtrl: _cityCtrl,
                        isDark: isDark,
                      )
                    else
                      _Step2Vehicles(
                        vehicles: _vehicles,
                        isDark: isDark,
                        onAdd: (type, plate, desc) =>
                            _addVehicle(type, plate, desc),
                        onRemove: _removeVehicle,
                      ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.error, size: 14),
                        const SizedBox(width: 6),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.error)),
                      ]),
                    ],

                    const SizedBox(height: 32),

                    // CTA
                    GestureDetector(
                      onTap: () {
                        if (_step == 0 && _step1Valid) {
                          HapticFeedback.lightImpact();
                          setState(() => _step = 1);
                        } else if (_step == 1 &&
                            _step2Valid &&
                            !_loading) {
                          HapticFeedback.mediumImpact();
                          _submit();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: (_step == 0
                              ? _step1Valid
                              : _step2Valid)
                              ? AppTheme.primaryGradient
                              : null,
                          color: (_step == 0
                              ? _step1Valid
                              : _step2Valid)
                              ? null
                              : (isDark
                              ? AppTheme.darkSurface
                              : AppTheme.lightSurface),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: (_step == 0
                              ? _step1Valid
                              : _step2Valid)
                              ? [
                            BoxShadow(
                              color:
                              AppTheme.blue.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ]
                              : null,
                        ),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white),
                          )
                              : Text(
                            _step == 0
                                ? 'Continue'
                                : 'Submit for Review',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: (_step == 0
                                  ? _step1Valid
                                  : _step2Valid)
                                  ? Colors.white
                                  : (isDark
                                  ? AppTheme.darkTextTertiary
                                  : AppTheme.lightTextTertiary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final bool isDark;

  const _TopBar(
      {required this.step, required this.onBack, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: onBack != null ? 1 : 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.lightTextPrimary),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: List.generate(2, (i) {
              final isActive = i == step;
              final isDone = i < step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(left: 6),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: isActive || isDone
                      ? AppTheme.primaryGradient
                      : null,
                  color: isActive || isDone
                      ? null
                      : (isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1)),
                ),
              );
            }),
          ),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border:
              Border.all(color: AppTheme.blue.withOpacity(0.3)),
            ),
            child: Text(
              '${step + 1} of 2',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 1 — PERSONAL DETAILS
// ─────────────────────────────────────────────────────────────

class _Step1Personal extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final bool isDark;

  const _Step1Personal({
    required this.nameCtrl,
    required this.cityCtrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Field(
          controller: nameCtrl,
          label: 'Full Name',
          hint: 'Emeka Johnson',
          isDark: isDark,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _Field(
          controller: cityCtrl,
          label: 'City',
          hint: 'Lagos, Abuja, Kano...',
          isDark: isDark,
          capitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.blue.withOpacity(0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppTheme.blue, size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your city is used to match you with nearby delivery jobs.',
                  style: TextStyle(fontSize: 12, color: AppTheme.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 2 — VEHICLE REGISTRATION
// ─────────────────────────────────────────────────────────────

class _Step2Vehicles extends StatelessWidget {
  final List<DeliveryVehicle> vehicles;
  final bool isDark;
  final Function(VehicleType, String, String) onAdd;
  final Function(String) onRemove;

  const _Step2Vehicles({
    required this.vehicles,
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle type cards
        ...VehicleType.values.map((type) {
          final owned = vehicles.where((v) => v.type == type).toList();
          return _VehicleTypeCard(
            type: type,
            ownedVehicles: owned,
            isDark: isDark,
            onAdd: (plate, desc) => onAdd(type, plate, desc),
            onRemove: onRemove,
          );
        }),

        if (vehicles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: AppTheme.green.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.green, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${vehicles.length} vehicle${vehicles.length > 1 ? 's' : ''} registered. More vehicles = more job opportunities.',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.green),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

class _VehicleTypeCard extends StatefulWidget {
  final VehicleType type;
  final List<DeliveryVehicle> ownedVehicles;
  final bool isDark;
  final Function(String plate, String desc) onAdd;
  final Function(String id) onRemove;

  const _VehicleTypeCard({
    required this.type,
    required this.ownedVehicles,
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_VehicleTypeCard> createState() => _VehicleTypeCardState();
}

class _VehicleTypeCardState extends State<_VehicleTypeCard> {
  bool _expanded = false;
  final _plateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _plateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.type) {
      case VehicleType.bike: return AppTheme.bikeColor;
      case VehicleType.car: return AppTheme.carColor;
      case VehicleType.pickup: return AppTheme.pickupColor;
      case VehicleType.truck: return AppTheme.truckColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVehicles = widget.ownedVehicles.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasVehicles
              ? _typeColor.withOpacity(0.4)
              : (widget.isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.07)),
          width: hasVehicles ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(widget.type.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.type.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.lightTextPrimary,
                          ),
                        ),
                        Text(
                          widget.type.weightRange,
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? AppTheme.darkTextTertiary
                                : AppTheme.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasVehicles)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.ownedVehicles.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _typeColor,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.isDark
                        ? AppTheme.darkTextTertiary
                        : AppTheme.lightTextTertiary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            Divider(
              height: 1,
              color: widget.isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.07),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Existing vehicles
                  ...widget.ownedVehicles.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.plate,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: widget.isDark
                                    ? AppTheme.darkTextPrimary
                                    : AppTheme.lightTextPrimary,
                              ),
                            ),
                            if (v.description.isNotEmpty)
                              Text(
                                v.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDark
                                      ? AppTheme.darkTextTertiary
                                      : AppTheme.lightTextTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onRemove(v.id),
                        child: const Icon(Icons.remove_circle_rounded,
                            color: AppTheme.error, size: 20),
                      ),
                    ]),
                  )),

                  // Add new vehicle form
                  _Field(
                    controller: _plateCtrl,
                    label: 'Plate Number',
                    hint: 'LAG-234-AB',
                    isDark: widget.isDark,
                    capitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 10),
                  _Field(
                    controller: _descCtrl,
                    label: 'Description (optional)',
                    hint: 'Red Honda CB125',
                    isDark: widget.isDark,
                    capitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () {
                      if (_plateCtrl.text.trim().length >= 3) {
                        widget.onAdd(
                          _plateCtrl.text.trim(),
                          _descCtrl.text.trim(),
                        );
                        _plateCtrl.clear();
                        _descCtrl.clear();
                        setState(() => _expanded = false);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _typeColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded,
                              color: _typeColor, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Add ${widget.type.label}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PENDING VERIFICATION SCREEN
// ─────────────────────────────────────────────────────────────

class _PendingScreen extends StatelessWidget {
  final bool isDark;
  const _PendingScreen({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppTheme.amber, size: 38),
            ),
            const SizedBox(height: 24),
            Text(
              'Under Review',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your application is being reviewed by our team. We\'ll notify you within 24 hours once you\'re verified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
              ),
            ),
            const SizedBox(height: 32),

            // What happens next
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What happens next',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NextStep('1', 'Our team reviews your application'),
                  const SizedBox(height: 8),
                  _NextStep('2', 'You receive a verification notification'),
                  const SizedBox(height: 8),
                  _NextStep('3', 'Start accepting delivery jobs and earning'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Check status button
            GestureDetector(
              onTap: () {
                // They can reopen app to check — splash will route correctly
                SystemNavigator.pop();
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  final String number;
  final String text;
  const _NextStep(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.blue,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
//  SHARED INPUT FIELD
// ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;
  final TextCapitalization capitalization;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
    this.capitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppTheme.darkTextSecondary
                : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color:
            isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
            ),
          ),
          child: TextField(
            controller: controller,
            textCapitalization: capitalization,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : AppTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.lightTextTertiary,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
