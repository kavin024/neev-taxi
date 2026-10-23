import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:neev_shared/neev_shared.dart';

import '../state/captain_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final CaptainState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _requiredDocs = {
    'driving_license': 'Driving licence',
    'vehicle_rc': 'Vehicle RC',
    'insurance': 'Insurance',
    'profile_photo': 'Profile photo',
  };

  final _name = TextEditingController();
  final _dl = TextEditingController();
  final _email = TextEditingController();
  final _pan = TextEditingController();
  final _aadhaar = TextEditingController();
  final _reg = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _year = TextEditingController(text: '2022');

  String? _areaId;
  String _vehicleCategory = 'bike';
  bool _savingProfile = false;
  bool _addingVehicle = false;
  String? _uploadingDoc;
  String _error = '';
  String? _info;

  @override
  void initState() {
    super.initState();
    final areas = widget.state.config?.serviceAreas ?? const <ServiceArea>[];
    if (areas.isNotEmpty) _areaId = areas.first.id;
    final cats = widget.state.categories;
    if (cats.isNotEmpty) _vehicleCategory = cats.first.code;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _dl,
      _email,
      _pan,
      _aadhaar,
      _reg,
      _model,
      _color,
      _year,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_name.text.trim().isEmpty || _dl.text.trim().length < 6) {
      setState(() => _error = 'Enter your name and a valid licence number.');
      return;
    }
    setState(() {
      _savingProfile = true;
      _error = '';
    });
    try {
      await widget.state.api.captainOnboarding(
        name: _name.text.trim(),
        dlNumber: _dl.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        panNumber: _pan.text.trim().isEmpty ? null : _pan.text.trim(),
        aadhaarLast4: _aadhaar.text.trim().isEmpty ? null : _aadhaar.text.trim(),
        serviceAreaId: _areaId,
      );
      await widget.state.refreshProfile();
      setState(() => _info = 'Profile created. Add your vehicle and documents.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _addVehicle() async {
    if (_reg.text.trim().length < 5 || _model.text.trim().isEmpty) {
      setState(() => _error = 'Enter the registration number and make/model.');
      return;
    }
    setState(() {
      _addingVehicle = true;
      _error = '';
    });
    try {
      await widget.state.api.addVehicle(
        category: _vehicleCategory,
        regNumber: _reg.text.trim().toUpperCase(),
        makeModel: _model.text.trim(),
        color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        year: int.tryParse(_year.text.trim()),
      );
      await widget.state.refreshProfile();
      setState(() => _info = 'Vehicle added.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _addingVehicle = false);
    }
  }

  Future<void> _upload(String docType) async {
    setState(() {
      _uploadingDoc = docType;
      _error = '';
    });
    try {
      final label = _requiredDocs[docType] ?? docType;
      final bytes = await _renderDemoDocument(label);
      await widget.state.api.uploadDocument(
        docType: docType,
        bytes: bytes,
        filename: 'neev-demo-$docType.png',
        mimeType: 'image/png',
      );
      await widget.state.refreshProfile();
      setState(() => _info = '$label uploaded for review.');
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not generate the demo document: $error');
    } finally {
      if (mounted) setState(() => _uploadingDoc = null);
    }
  }

  /// Generates a clearly-labelled placeholder image. It exercises the real
  /// multipart upload, checksum, storage and admin-review flow, but it is not a
  /// forged document and cannot be mistaken for one.
  Future<Uint8List> _renderDemoDocument(String title) async {
    const width = 900.0;
    const height = 560.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = NeevColors.cream,
    );
    canvas.drawRect(
      const Rect.fromLTWH(26, 26, width - 52, height - 52),
      Paint()
        ..color = NeevColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawRect(
      const Rect.fromLTWH(26, 26, width - 52, 94),
      Paint()..color = NeevColors.green,
    );

    void text(
      String value,
      double x,
      double y, {
      double size = 22,
      Color color = NeevColors.ink,
      FontWeight weight = FontWeight.w500,
      double maxWidth = 800,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            height: 1.35,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(x, y));
    }

    text('NEEV CAPTAIN VERIFICATION',
        52, 48,
        size: 26,
        color: Colors.white,
        weight: FontWeight.w800,
        maxWidth: 700);
    text('DEMO PLACEHOLDER — NOT A REAL DOCUMENT',
        52, 82,
        size: 12,
        color: Colors.white70,
        weight: FontWeight.w600,
        maxWidth: 700);
    text(title, 52, 160, size: 38, weight: FontWeight.w800);
    text(
      'Generated locally by Neev Captain to exercise the document upload, '
      'checksum, private storage and admin review workflow. It contains no '
      'personal identity data and must never be accepted as proof of identity.',
      52,
      230,
      size: 18,
      color: NeevColors.inkSoft,
      maxWidth: 790,
    );
    text(
      'Demo build · ${DateTime.now().toIso8601String().split('T').first}',
      52,
      420,
      size: 14,
      color: NeevColors.muted,
    );
    text(
      'Reviewer: reject this file if it is submitted as a real document.',
      52,
      450,
      size: 14,
      color: NeevColors.danger,
      weight: FontWeight.w700,
      maxWidth: 790,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('PNG encoding failed.');
    return data.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.state.profile;
    final hasProfile = profile != null && !profile.onboardingRequired;
    final approved = profile?.verificationStatus == 'approved';
    final documents = profile?.documents ?? const [];
    final vehicles = profile?.vehicles ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain verification'),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: () => widget.state.refreshProfile(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
            children: [
              NeevCard(
                color: approved ? NeevColors.greenSoft : NeevColors.amberSoft,
                borderColor:
                    approved ? NeevColors.greenSoft : NeevColors.amber,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      approved
                          ? Icons.verified_outlined
                          : Icons.pending_actions_outlined,
                      color: approved ? NeevColors.green : const Color(0xFF7A5400),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            approved
                                ? 'Approved to drive'
                                : hasProfile
                                    ? 'Verification in progress'
                                    : 'Set up your captain profile',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            approved
                                ? 'You can go online from the Home tab.'
                                : hasProfile
                                    ? 'An admin reviews each document. The demo admin account can approve you immediately.'
                                    : 'New captains must be approved before receiving ride offers.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: NeevColors.inkSoft,
                            ),
                          ),
                          if (profile?.rejectionReason != null &&
                              profile!.rejectionReason!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Rejected: ${profile.rejectionReason}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: NeevColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusPill(
                      status: profile?.verificationStatus ?? 'draft',
                      label: profile?.verificationStatus == null
                          ? 'Draft'
                          : null,
                    ),
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error),
              ],
              if (_info != null) ...[
                const SizedBox(height: 12),
                NeevCard(
                  color: NeevColors.greenSoft,
                  child: Text(
                    _info!,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (!hasProfile) ...[
                SectionHeading(
                  title: '1 · Your details',
                  subtitle: 'Used on your captain profile and masked in storage.',
                ),
                const SizedBox(height: 10),
                NeevField(
                  label: 'Full name',
                  controller: _name,
                  hint: 'As on your driving licence',
                ),
                const SizedBox(height: 12),
                NeevField(
                  label: 'Driving licence number',
                  controller: _dl,
                  hint: 'KA0120220001234',
                  textCapitalization: TextCapitalization.characters,
                  helper: 'Only the last four characters are retained in the profile.',
                ),
                const SizedBox(height: 12),
                NeevField(
                  label: 'Email (optional)',
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: NeevField(
                        label: 'PAN (optional)',
                        controller: _pan,
                        hint: 'ABCDE1234F',
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeevField(
                        label: 'Aadhaar last 4 (optional)',
                        controller: _aadhaar,
                        hint: '1234',
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((widget.state.config?.serviceAreas ?? []).isNotEmpty) ...[
                  Text('Service area',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 7),
                  DropdownButtonFormField<String>(
                    initialValue: _areaId,
                    items: widget.state.config!.serviceAreas
                        .map(
                          (area) => DropdownMenuItem(
                            value: area.id,
                            child: Text('${area.name}, ${area.city}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _areaId = value,
                  ),
                ],
                const SizedBox(height: 16),
                NeevButton(
                  label: 'Create captain profile',
                  loading: _savingProfile,
                  onPressed: _saveProfile,
                  icon: Icons.arrow_forward,
                ),
              ] else ...[
                SectionHeading(
                  title: '2 · Your vehicle',
                  subtitle: 'At least one active vehicle is required to go online.',
                ),
                const SizedBox(height: 10),
                if (vehicles.isNotEmpty)
                  ...vehicles.map(
                    (vehicle) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NeevCard(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            const Icon(Icons.two_wheeler,
                                color: NeevColors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (vehicle['reg_number'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${humanize((vehicle['category'] ?? '').toString())} · ${vehicle['make_model']}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: NeevColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(
                              status: vehicle['is_active'] == true
                                  ? 'active'
                                  : 'inactive',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                NeevCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicles.isEmpty
                            ? 'Add your vehicle'
                            : 'Add another vehicle',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _vehicleCategory,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: widget.state.categories
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat.code,
                                child: Text(cat.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _vehicleCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      NeevField(
                        label: 'Registration number',
                        controller: _reg,
                        hint: 'KA 01 AB 1234',
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 10),
                      NeevField(
                        label: 'Make and model',
                        controller: _model,
                        hint: 'Honda Activa 6G',
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: NeevField(
                              label: 'Colour',
                              controller: _color,
                              hint: 'Grey',
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 100,
                            child: NeevField(
                              label: 'Year',
                              controller: _year,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      NeevButton(
                        label: 'Add vehicle',
                        loading: _addingVehicle,
                        onPressed: _addVehicle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SectionHeading(
                  title: '3 · Documents',
                  subtitle:
                      'Uploaded files are private, sniffed and checksummed. An admin reviews each one.',
                ),
                const SizedBox(height: 10),
                NeevCard(
                  color: NeevColors.amberSoft,
                  borderColor: NeevColors.amber,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This development build has no camera or document scanner configured. The button below generates a clearly-labelled placeholder PNG and uploads it through the real document pipeline so review can be tested end to end. Do not use it as a real credential.',
                        style: TextStyle(fontSize: 11.5, height: 1.45),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _upload('profile_photo'),
                        icon: const Icon(Icons.photo_camera_outlined, size: 16),
                        label: const Text('Try the placeholder upload'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ..._requiredDocs.entries.map((entry) {
                  final doc = documents.firstWhere(
                    (d) => d['doc_type'] == entry.key,
                    orElse: () => const {},
                  );
                  final status = (doc['status'] ?? '').toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: NeevCard(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          Icon(
                            status == 'approved'
                                ? Icons.check_circle_outline
                                : status == 'rejected'
                                    ? Icons.error_outline
                                    : Icons.description_outlined,
                            color: status == 'approved'
                                ? NeevColors.green
                                : status == 'rejected'
                                    ? NeevColors.danger
                                    : NeevColors.muted,
                            size: 21,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  doc.isEmpty
                                      ? 'Not uploaded'
                                      : '${humanize(status)} · ${doc['original_filename'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: NeevColors.muted,
                                  ),
                                ),
                                if ((doc['rejection_reason'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    (doc['rejection_reason'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: NeevColors.danger,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (status != 'approved')
                            _uploadingDoc == entry.key
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: _uploadingDoc == null
                                        ? () => _upload(entry.key)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 38),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                    child: Text(
                                      doc.isEmpty ? 'Upload' : 'Replace',
                                      style: const TextStyle(fontSize: 11.5),
                                    ),
                                  ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                if (vehicles.isNotEmpty &&
                    _requiredDocs.keys.every((type) => documents
                        .any((d) => d['doc_type'] == type)))
                  NeevButton(
                    label: 'Refresh verification status',
                    icon: Icons.refresh,
                    onPressed: () => widget.state.refreshProfile(),
                  ),
                const SizedBox(height: 12),
                Text(
                  approved
                      ? 'Approved. You can go online from the Home tab.'
                      : 'Waiting for an admin decision. Use the demo admin console to approve or reject documents during testing.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: NeevColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              NeevButton(
                label: 'Sign out',
                tone: NeevButtonTone.outline,
                onPressed: widget.state.signOut,
              ),
            ],
          );
        },
      ),
    );
  }
}
