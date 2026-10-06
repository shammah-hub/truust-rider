import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../constants/delivery_cities.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/delivery_models.dart';
import '../../../data/repositories/delivery_repository.dart';
import '../../../navigation/main_navigation.dart';

// ═══════════════════════════════════════════════════════════════
//  AGENT SETUP PAGE
//
//  Step 1 — Personal details (name, city, optional agency code)
//  Step 2 — Add vehicles (can add multiple)
//  Step 3 — Guarantors
//  Step 4 — Verification documents (ID, selfie, rider's permit,
//           AMAC registration, bike + plate photo)
// ═══════════════════════════════════════════════════════════════

class AgentSetupPage extends StatefulWidget {
  final String userId;
  const AgentSetupPage({super.key, required this.userId});

  @override
  State<AgentSetupPage> createState() => _AgentSetupPageState();
}

class _AgentSetupPageState extends State<AgentSetupPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _agencyCodeCtrl = TextEditingController();

  final _g1NameCtrl = TextEditingController();
  final _g1PhoneCtrl = TextEditingController();
  final _g1RelCtrl = TextEditingController();
  final _g2NameCtrl = TextEditingController();
  final _g2PhoneCtrl = TextEditingController();
  final _g2RelCtrl = TextEditingController();

  int _step = 0; // 0=personal, 1=vehicles, 2=guarantors, 3=verification docs
  bool _loading = false;
  String? _error;

  final List<DeliveryVehicle> _vehicles = [];
  final _uuid = const Uuid();

  String _idType = 'drivers_license';
  File? _idDocument;
  File? _selfie;
  File? _riderPermit;
  File? _amacRegistration;
  File? _bikeWithPlate;

  // Riders joining through an agency invite code skip guarantors and
  // document uploads — their agency vouches for them.
  bool get _viaAgency => _agencyCodeCtrl.text.trim().isNotEmpty;
  int get _lastStep => _viaAgency ? 1 : 3;
  String? _agencyName;  // filled in once the backend has checked the code
  String? _checkedCode; // the code _agencyName belongs to

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _agencyCodeCtrl.dispose();
    _g1NameCtrl.dispose();
    _g1PhoneCtrl.dispose();
    _g1RelCtrl.dispose();
    _g2NameCtrl.dispose();
    _g2PhoneCtrl.dispose();
    _g2RelCtrl.dispose();
    super.dispose();
  }

  bool get _step1Valid =>
      _nameCtrl.text.trim().length >= 2 &&
          _emailCtrl.text.trim().contains('@') &&
          _addressCtrl.text.trim().length >= 5 &&
          kDeliveryCities.contains(_cityCtrl.text.trim());

  // Agency riders can skip this: the agency may be the one giving them the bike.
  bool get _step2Valid => _viaAgency || _vehicles.isNotEmpty;

  // Only the first guarantor is required — a second is optional
  // but if any of its fields are filled, all three must be, so we
  // never save a half-complete second guarantor.
  bool get _currentStepValid {
    switch (_step) {
      case 0: return _step1Valid;
      case 1: return _step2Valid;
      case 2: return _step3Valid;
      default: return _step4Valid;
    }
  }

  bool get _step3Valid {
    final g1Complete = _g1NameCtrl.text.trim().isNotEmpty &&
        _g1PhoneCtrl.text.trim().length >= 10 &&
        _g1RelCtrl.text.trim().isNotEmpty;
    final g2Started = _g2NameCtrl.text.trim().isNotEmpty ||
        _g2PhoneCtrl.text.trim().isNotEmpty ||
        _g2RelCtrl.text.trim().isNotEmpty;
    final g2Complete = _g2NameCtrl.text.trim().isNotEmpty &&
        _g2PhoneCtrl.text.trim().length >= 10 &&
        _g2RelCtrl.text.trim().isNotEmpty;
    return g1Complete && (!g2Started || g2Complete);
  }

  bool get _step4Valid =>
      _idDocument != null &&
          _selfie != null &&
          _riderPermit != null &&
          _amacRegistration != null &&
          _bikeWithPlate != null;

  // Step 1 -> 2. If an invite code was typed, check it with the backend first
  // so a wrong or inactive code is caught right here.
  Future<void> _continueFromPersonal() async {
    HapticFeedback.lightImpact();
    final code = _agencyCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() {
        _agencyName = null;
        _checkedCode = null;
        _step = 1;
      });
      return;
    }
    if (_checkedCode == code && _agencyName != null) {
      setState(() => _step = 1);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final name = await context.read<DeliveryRepository>().validateAgencyCode(code);
      if (!mounted) return;
      setState(() {
        _agencyName = name;
        _checkedCode = code;
        _step = 1;
      });
    } catch (e) {
      debugPrint('validateAgencyCode failed for "$code": $e');
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final guarantors = _viaAgency ? <Guarantor>[] : <Guarantor>[
      Guarantor(
        name: _g1NameCtrl.text.trim(),
        phone: _g1PhoneCtrl.text.trim(),
        relationship: _g1RelCtrl.text.trim(),
      ),
      if (_g2NameCtrl.text.trim().isNotEmpty)
        Guarantor(
          name: _g2NameCtrl.text.trim(),
          phone: _g2PhoneCtrl.text.trim(),
          relationship: _g2RelCtrl.text.trim(),
        ),
    ];

    try {
      await context.read<DeliveryRepository>().registerAgent(
        userId: widget.userId,
        name: _nameCtrl.text.trim(),
        phone: '',
        email: _emailCtrl.text.trim(),
        homeAddress: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        vehicles: _vehicles,
        guarantors: guarantors,
        idType: _idType,
        idDocument: _viaAgency ? null : _idDocument,
        selfie: _viaAgency ? null : _selfie,
        riderPermit: _viaAgency ? null : _riderPermit,
        amacRegistration: _viaAgency ? null : _amacRegistration,
        bikeWithPlate: _viaAgency ? null : _bikeWithPlate,
        agencyCode: _agencyCodeCtrl.text.trim().isEmpty ? null : _agencyCodeCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MainNavigation(userId: widget.userId),
          ),
              (route) => false,
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('registerAgent FirebaseException: ${e.code} — ${e.message}');
      setState(() => _error = _friendlyFirebaseError(e));
    } catch (e, st) {
      debugPrint('registerAgent failed: $e');
      debugPrint('$st');
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'not-found':
        return 'Something went wrong setting up your profile. Please try again.';
      case 'permission-denied':
        return 'You don\'t have permission to do this. Please contact support.';
      case 'unavailable':
        return 'No internet connection. Please check your network and try again.';
      case 'unauthenticated':
        return 'Your session expired. Please log in again.';
      default:
        return 'Something went wrong (${e.code}). Please try again.';
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
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              step: _step,
              total: _viaAgency ? 2 : 4,
              onBack: _step > 0
                  ? () => setState(() => _step -= 1)
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
                          : _step == 1
                          ? (_viaAgency ? 'Your vehicle' : 'Your vehicles')
                          : _step == 2
                          ? 'Guarantors'
                          : 'Verify your identity',
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
                          : _step == 1
                          ? (_viaAgency
                          ? 'Joining ${_agencyName ?? 'your agency'}. Add the vehicle you ride, or skip this if your agency gives you the bike.'
                          : 'Add all vehicles you own. More vehicles = more jobs.')
                          : _step == 2
                          ? 'At least 1 person we can contact if needed. Kept on file, contacted only if something serious comes up.'
                          : 'Our team manually reviews these before you can go online.',
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
                        emailCtrl: _emailCtrl,
                        addressCtrl: _addressCtrl,
                        cityCtrl: _cityCtrl,
                        agencyCodeCtrl: _agencyCodeCtrl,
                        isDark: isDark,
                        onChange: () => setState(() {}),
                      )
                    else if (_step == 1)
                      _Step2Vehicles(
                        vehicles: _vehicles,
                        isDark: isDark,
                        onAdd: (type, plate, desc) =>
                            _addVehicle(type, plate, desc),
                        onRemove: _removeVehicle,
                      )
                    else if (_step == 2)
                        _Step3Guarantors(
                          g1NameCtrl: _g1NameCtrl,
                          g1PhoneCtrl: _g1PhoneCtrl,
                          g1RelCtrl: _g1RelCtrl,
                          g2NameCtrl: _g2NameCtrl,
                          g2PhoneCtrl: _g2PhoneCtrl,
                          g2RelCtrl: _g2RelCtrl,
                          isDark: isDark,
                          onChange: () => setState(() {}),
                        )
                      else
                        _Step4Verification(
                          idType: _idType,
                          idDocument: _idDocument,
                          selfie: _selfie,
                          riderPermit: _riderPermit,
                          amacRegistration: _amacRegistration,
                          bikeWithPlate: _bikeWithPlate,
                          isDark: isDark,
                          onIdTypeChanged: (v) => setState(() => _idType = v),
                          onIdDocumentPicked: (f) => setState(() => _idDocument = f),
                          onSelfiePicked: (f) => setState(() => _selfie = f),
                          onRiderPermitPicked: (f) => setState(() => _riderPermit = f),
                          onAmacRegistrationPicked: (f) => setState(() => _amacRegistration = f),
                          onBikeWithPlatePicked: (f) => setState(() => _bikeWithPlate = f),
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

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () {
                          if (_step == 0 && _step1Valid) {
                            _continueFromPersonal();
                          } else if (_step == 1 && _step2Valid) {
                            if (_viaAgency) {
                              HapticFeedback.mediumImpact();
                              _submit();
                            } else {
                              HapticFeedback.lightImpact();
                              setState(() => _step = 2);
                            }
                          } else if (_step == 2 && _step3Valid) {
                            HapticFeedback.lightImpact();
                            setState(() => _step = 3);
                          } else if (_step == 3 && _step4Valid) {
                            HapticFeedback.mediumImpact();
                            _submit();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          shape: const StadiumBorder(), // outer shape is the pill
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.ink(isDark).withOpacity(_currentStepValid ? 1.0 : 0.3),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          alignment: Alignment.center,
                          width: double.infinity,
                          height: 56,
                          child: _loading
                              ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.inkInverse(isDark)),
                          )
                              : Text(
                            _step < _lastStep ? 'Continue' : (_viaAgency ? 'Join Agency' : 'Submit for Review'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.inkInverse(isDark),
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
  final int total;
  final VoidCallback? onBack;
  final bool isDark;

  const _TopBar(
      {required this.step, required this.total, required this.onBack, required this.isDark});

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
            children: List.generate(total, (i) {
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
              '${step + 1} of $total',
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
  final TextEditingController emailCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController agencyCodeCtrl;
  final bool isDark;
  final VoidCallback onChange;

  const _Step1Personal({
    required this.nameCtrl,
    required this.emailCtrl,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.agencyCodeCtrl,
    required this.isDark,
    required this.onChange,
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
          controller: emailCtrl,
          label: 'Email Address',
          hint: 'emeka@email.com',
          isDark: isDark,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _Field(
          controller: addressCtrl,
          label: 'Home Address',
          hint: '12 Allen Avenue, Ikeja',
          isDark: isDark,
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        _CityField(
          controller: cityCtrl,
          isDark: isDark,
          onChange: onChange,
        ),
        const SizedBox(height: 16),
        _Field(
          controller: agencyCodeCtrl,
          label: 'Agency Invite Code (optional)',
          hint: 'Only if a fleet agency gave you one',
          isDark: isDark,
          capitalization: TextCapitalization.none,
          onChanged: onChange,
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
              Icon(Iconsax.info_circle, color: AppTheme.blue, size: 16),
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
//  STEP 3 — GUARANTORS
// ─────────────────────────────────────────────────────────────

class _Step3Guarantors extends StatelessWidget {
  final TextEditingController g1NameCtrl;
  final TextEditingController g1PhoneCtrl;
  final TextEditingController g1RelCtrl;
  final TextEditingController g2NameCtrl;
  final TextEditingController g2PhoneCtrl;
  final TextEditingController g2RelCtrl;
  final bool isDark;
  final VoidCallback onChange;

  const _Step3Guarantors({
    required this.g1NameCtrl,
    required this.g1PhoneCtrl,
    required this.g1RelCtrl,
    required this.g2NameCtrl,
    required this.g2PhoneCtrl,
    required this.g2RelCtrl,
    required this.isDark,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuarantorGroup(
          title: 'Guarantor 1 (required)',
          nameCtrl: g1NameCtrl,
          phoneCtrl: g1PhoneCtrl,
          relCtrl: g1RelCtrl,
          isDark: isDark,
          onChange: onChange,
        ),
        const SizedBox(height: 20),
        _GuarantorGroup(
          title: 'Guarantor 2 (optional)',
          nameCtrl: g2NameCtrl,
          phoneCtrl: g2PhoneCtrl,
          relCtrl: g2RelCtrl,
          isDark: isDark,
          onChange: onChange,
        ),
      ],
    );
  }
}

class _GuarantorGroup extends StatelessWidget {
  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relCtrl;
  final bool isDark;
  final VoidCallback onChange;

  const _GuarantorGroup({
    required this.title,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.relCtrl,
    required this.isDark,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _Field(
          controller: nameCtrl,
          label: 'Full Name',
          hint: 'Full name',
          isDark: isDark,
          capitalization: TextCapitalization.words,
          onChanged: onChange,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: phoneCtrl,
          label: 'Phone Number',
          hint: '08012345678',
          isDark: isDark,
          keyboardType: TextInputType.phone,
          onChanged: onChange,
        ),
        const SizedBox(height: 10),
        _Field(
          controller: relCtrl,
          label: 'Relationship',
          hint: 'e.g. Brother, Employer, Pastor',
          isDark: isDark,
          capitalization: TextCapitalization.words,
          onChanged: onChange,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  STEP 4 — VERIFICATION DOCUMENTS
//  Manually reviewed by admin today. Structured so an automated
//  provider (Smile ID) can slot in later — the upload/capture UX
//  stays identical either way; only what happens after submit
//  (human review vs API call) would change.
//
//  Local-compliance documents (rider's permit, AMAC registration,
//  bike + plate photo) follow the same manual-review model — no
//  verification API exists for these, so they're reviewed by the
//  same human who checks the ID/selfie match.
// ─────────────────────────────────────────────────────────────

class _Step4Verification extends StatelessWidget {
  final String idType;
  final File? idDocument;
  final File? selfie;
  final File? riderPermit;
  final File? amacRegistration;
  final File? bikeWithPlate;
  final bool isDark;
  final ValueChanged<String> onIdTypeChanged;
  final ValueChanged<File> onIdDocumentPicked;
  final ValueChanged<File> onSelfiePicked;
  final ValueChanged<File> onRiderPermitPicked;
  final ValueChanged<File> onAmacRegistrationPicked;
  final ValueChanged<File> onBikeWithPlatePicked;

  const _Step4Verification({
    required this.idType,
    required this.idDocument,
    required this.selfie,
    required this.riderPermit,
    required this.amacRegistration,
    required this.bikeWithPlate,
    required this.isDark,
    required this.onIdTypeChanged,
    required this.onIdDocumentPicked,
    required this.onSelfiePicked,
    required this.onRiderPermitPicked,
    required this.onAmacRegistrationPicked,
    required this.onBikeWithPlatePicked,
  });

  Future<void> _pickFromSheet(BuildContext context, ValueChanged<File> onPicked, {int maxWidth = 1600}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.camera, imageQuality: 85, maxWidth: maxWidth.toDouble(),
                );
                if (picked != null) onPicked(File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery, imageQuality: 85, maxWidth: maxWidth.toDouble(),
                );
                if (picked != null) onPicked(File(picked.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickId(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked != null) onIdDocumentPicked(File(picked.path));
  }

  Future<void> _pickSelfie() async {
    // Front camera preferred for a genuine "hold phone to your own
    // face" capture rather than a photo of a photo — this is the
    // same signal a live liveness check would eventually use.
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked != null) onSelfiePicked(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _IdTypeChip(
              label: "Driver's License",
              selected: idType == 'drivers_license',
              isDark: isDark,
              onTap: () => onIdTypeChanged('drivers_license'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _IdTypeChip(
              label: "Voter's Card",
              selected: idType == 'voters_card',
              isDark: isDark,
              onTap: () => onIdTypeChanged('voters_card'),
            ),
          ),
        ]),

        const SizedBox(height: 22),

        _UploadCard(
          title: 'ID Document Photo',
          subtitle: 'Clear photo of the front of your ID',
          file: idDocument,
          isDark: isDark,
          icon: Iconsax.card,
          onTap: () => _showPickerSheet(context, _pickId),
        ),

        const SizedBox(height: 16),

        _UploadCard(
          title: 'Live Selfie',
          subtitle: 'Take a clear photo of your face — camera only, no gallery',
          file: selfie,
          isDark: isDark,
          icon: Iconsax.user,
          onTap: _pickSelfie,
        ),

        const SizedBox(height: 16),

        _UploadCard(
          title: "Rider's Permit",
          subtitle: 'Clear photo of your commercial rider\'s permit',
          file: riderPermit,
          isDark: isDark,
          icon: Iconsax.document,
          onTap: () => _pickFromSheet(context, onRiderPermitPicked),
        ),

        const SizedBox(height: 16),

        _UploadCard(
          title: 'AMAC Registration',
          subtitle: 'Clear photo of your AMAC registration paper',
          file: amacRegistration,
          isDark: isDark,
          icon: Iconsax.document_text,
          onTap: () => _pickFromSheet(context, onAmacRegistrationPicked),
        ),

        const SizedBox(height: 16),

        _UploadCard(
          title: 'Bike & Plate Number',
          subtitle: 'Photo of your bike, with the plate number clearly visible',
          file: bikeWithPlate,
          isDark: isDark,
          icon: Iconsax.gallery,
          onTap: () => _pickFromSheet(context, onBikeWithPlatePicked),
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.blue.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.blue.withOpacity(0.2)),
          ),
          child: const Row(children: [
            Icon(Iconsax.info_circle, color: AppTheme.blue, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Our team reviews these manually and compares your selfie to your ID before approving your account.',
                style: TextStyle(fontSize: 12, color: AppTheme.blue, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  void _showPickerSheet(BuildContext context, void Function(ImageSource) onPick) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                onPick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _IdTypeChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.blue.withOpacity(0.1)
              : (isDark ? AppTheme.darkSurface : AppTheme.lightSurface),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.blue
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppTheme.blue
                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? file;
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _UploadCard({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? AppTheme.green.withOpacity(0.4)
                : (isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.07)),
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          if (hasFile)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(file!, width: 52, height: 52, fit: BoxFit.cover),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppTheme.blue, size: 24),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasFile ? 'Tap to retake' : subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (hasFile)
            const Icon(Iconsax.tick_circle, color: AppTheme.green, size: 20)
          else
            Icon(Icons.chevron_right_rounded,
                color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary),
        ]),
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


class _CityField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onChange;

  const _CityField({
    required this.controller,
    required this.isDark,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'City',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.text.isEmpty ? null : controller.text,
              isExpanded: true,
              hint: Text(
                'Select your city',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary,
                ),
              ),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: isDark ? AppTheme.darkTextTertiary : AppTheme.lightTextTertiary),
              dropdownColor: isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
              items: kDeliveryCities
                  .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                  .toList(),
              onChanged: (value) {
                controller.text = value ?? '';
                onChange();
              },
            ),
          ),
        ),
      ],
    );
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
  final TextInputType? keyboardType;
  final VoidCallback? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.isDark,
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.onChanged,
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
            keyboardType: keyboardType,
            onChanged: onChanged == null ? null : (_) => onChanged!(),
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
