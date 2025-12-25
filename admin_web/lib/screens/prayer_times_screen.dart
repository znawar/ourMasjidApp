import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/providers/prayer_times_provider.dart';
import 'package:admin_web/widgets/settings_summary_card.dart';
import 'package:admin_web/models/prayer_settings_model.dart';
import 'package:admin_web/services/prayer_api_service.dart';
import 'package:admin_web/utils/admin_theme.dart';

enum _PrayerWizardPage {
  editChooser,
  athanChoice,
  athanAutomatic,
  athanImport,
  iqamahChoice,
  iqamahDelays,
  iqamahImport,
}

class _WizardStepper extends StatelessWidget {
  final _PrayerWizardPage page;

  const _WizardStepper({required this.page});

  bool get _isAthan =>
      page == _PrayerWizardPage.athanChoice ||
      page == _PrayerWizardPage.athanAutomatic ||
      page == _PrayerWizardPage.athanImport;

  bool get _isIqamah =>
      page == _PrayerWizardPage.iqamahChoice ||
      page == _PrayerWizardPage.iqamahDelays ||
      page == _PrayerWizardPage.iqamahImport;

  int get _activeIndex {
    switch (page) {
      case _PrayerWizardPage.editChooser:
        return 0;
      case _PrayerWizardPage.athanChoice:
        return 0;
      case _PrayerWizardPage.athanAutomatic:
        return 1;
      case _PrayerWizardPage.athanImport:
        return 1;
      case _PrayerWizardPage.iqamahChoice:
        return 0;
      case _PrayerWizardPage.iqamahDelays:
        return 1;
      case _PrayerWizardPage.iqamahImport:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAthan && !_isIqamah) {
      return const SizedBox.shrink();
    }

    final steps = _isAthan
        ? const [
            _StepDef(Icons.settings, 'Setting'),
            _StepDef(Icons.calculate_outlined, 'Calculation'),
            _StepDef(Icons.list_alt_outlined, 'Method'),
            _StepDef(Icons.fact_check_outlined, 'Checking'),
            _StepDef(Icons.tune, 'Adjustment'),
          ]
        : const [
            _StepDef(Icons.settings, 'Setting'),
            _StepDef(Icons.calculate_outlined, 'Calculation'),
            _StepDef(Icons.schedule, 'Delays'),
          ];

    final activeColor = AdminTheme.accentEmerald;
    final inactiveColor = Colors.grey.shade400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isActive = index == _activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                step.icon,
                size: 22,
                color: isActive ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StepDef {
  final IconData icon;
  final String label;

  const _StepDef(this.icon, this.label);
}

class _SpecialTimeSummary extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _SpecialTimeSummary({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AdminTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                'min.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Icon(icon, size: 56, color: Colors.grey.shade600),
                  const SizedBox(height: 18),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String? helperText;

  const _LabeledDropdown({
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(e),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _ToggleChoiceButton extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _ToggleChoiceButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.blueGrey.shade200 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AdminTheme.textPrimary : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  int _selectedTab = 0;
  final Map<String, TextEditingController> _adhanControllers = {};
  final Map<String, TextEditingController> _iqamahControllers = {};
  final Map<String, TextEditingController> _delayControllers = {};
  final Map<String, bool> _useDelayControllers = {};

  DateTime? _lastSyncedLastUpdated;
  
  // Location controllers
  late TextEditingController _cityController;
  late TextEditingController _countryController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeLocationControllers();
  }

  void _initializeLocationControllers() {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    
    _cityController = TextEditingController(
      text: provider.prayerSettings?.location.city ?? '',
    );
    _countryController = TextEditingController(
      text: provider.prayerSettings?.location.country ?? '',
    );
    _latitudeController = TextEditingController(
      text: (provider.prayerSettings?.location.latitude ?? 0.0) != 0.0
          ? (provider.prayerSettings?.location.latitude ?? 0.0).toString()
          : '',
    );
    _longitudeController = TextEditingController(
      text: (provider.prayerSettings?.location.longitude ?? 0.0) != 0.0
          ? (provider.prayerSettings?.location.longitude ?? 0.0).toString()
          : '',
    );
  }

  void _initializeControllers() {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    
    try {
      final prayerSettings = provider.prayerSettings;
      if (prayerSettings != null && prayerSettings.prayerTimes.isNotEmpty) {
        prayerSettings.prayerTimes.forEach((prayer, time) {
          _adhanControllers[prayer] = TextEditingController(text: time.adhan);
          _iqamahControllers[prayer] = TextEditingController(text: time.iqamah);
          _delayControllers[prayer] = TextEditingController(text: time.delay.toString());
          _useDelayControllers[prayer] = prayerSettings.iqamahUseDelay[prayer] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing controllers: $e');
    }
  }

  void _updateControllers() {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);
    
    try {
      final prayerSettings = provider.prayerSettings;
      if (prayerSettings != null && prayerSettings.prayerTimes.isNotEmpty) {
        prayerSettings.prayerTimes.forEach((prayer, time) {
          _adhanControllers.putIfAbsent(prayer, () => TextEditingController());
          _iqamahControllers.putIfAbsent(prayer, () => TextEditingController());
          _delayControllers.putIfAbsent(prayer, () => TextEditingController());

          _adhanControllers[prayer]!.text = time.adhan;
          _iqamahControllers[prayer]!.text = time.iqamah;
          _delayControllers[prayer]!.text = time.delay.toString();

          _useDelayControllers[prayer] = prayerSettings.iqamahUseDelay[prayer] ?? true;
        });

        // Sync location controllers too.
        _cityController.text = prayerSettings.location.city;
        _countryController.text = prayerSettings.location.country;
        _latitudeController.text = prayerSettings.location.latitude != 0.0
            ? prayerSettings.location.latitude.toString()
            : '';
        _longitudeController.text = prayerSettings.location.longitude != 0.0
            ? prayerSettings.location.longitude.toString()
            : '';
      }
    } catch (e) {
      debugPrint('Error updating controllers: $e');
    }
  }

  @override
  void dispose() {
    _adhanControllers.forEach((key, controller) => controller.dispose());
    _iqamahControllers.forEach((key, controller) => controller.dispose());
    _delayControllers.forEach((key, controller) => controller.dispose());
    _cityController.dispose();
    _countryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrayerTimesProvider>(context);

    // Keep UI controllers synced with the latest loaded/saved settings.
    final currentLastUpdated = provider.prayerSettings?.lastUpdated;
    if (currentLastUpdated != null &&
        (_lastSyncedLastUpdated == null || currentLastUpdated.isAfter(_lastSyncedLastUpdated!))) {
      _lastSyncedLastUpdated = currentLastUpdated;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Prevent cursor jump while typing.
        if (FocusManager.instance.primaryFocus != null) return;
        _updateControllers();
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          if (provider.errorMessage != null && provider.errorMessage!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: provider.clearError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (provider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final gap = isWide ? 24.0 : 16.0;
                final cardWidth = isWide
                    ? (constraints.maxWidth - gap) / 2
                    : constraints.maxWidth;

                final settings = provider.prayerSettings;
                final method = settings?.calculationSettings.method ?? '--';
                final iqamahMode = _iqamahModeLabel(settings);
                final jumuah1 = (settings?.jumuahTimes.isNotEmpty ?? false)
                    ? settings!.jumuahTimes.first
                    : '--';
                final jumuah2 = (settings?.jumuahTimes.length ?? 0) > 1
                    ? settings!.jumuahTimes[1]
                    : jumuah1;

                final special = settings?.specialTimes ?? const SpecialTimes();

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: SettingsSummaryCard(
                        title: 'Prayer times calculation',
                        leftLabel: 'ATHAN (START)',
                        leftValue: method,
                        rightLabel: 'IQAMAH (JAMAAH)',
                        rightValue: iqamahMode,
                        actionLabel: 'Edit',
                        onAction: () => _openPrayerTimesWizard(provider),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: SettingsSummaryCard(
                        title: 'Jumuah times',
                        description: null,
                        body: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              jumuah1,
                              style: const TextStyle(
                                color: AdminTheme.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              jumuah2,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        leftLabel: '',
                        leftValue: '',
                        rightLabel: '',
                        rightValue: '',
                        actionLabel: 'Edit',
                        onAction: () => _openEditDialog(
                          title: 'Jumuah times',
                          child: _buildJumuahEditor(provider),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: SettingsSummaryCard(
                        title: 'Prayer times overwrites',
                        description:
                            'In some cases, you can decide to block the athan of\n'
                            'a prayer at a specific time or set a maximum or\n'
                            'minimum time.',
                        leftLabel: '',
                        leftValue: '',
                        rightLabel: '',
                        rightValue: '',
                        actionLabel: 'Edit',
                        onAction: () => _openEditDialog(
                          title: 'Prayer times overwrites',
                          child: _buildOverridesEditor(provider),
                        ),
                      ),
                    ),
                    // Ramadan Mode toggle card - always visible
                    SizedBox(
                      width: cardWidth,
                      child: _buildRamadanModeCard(provider, special),
                    ),
                    // Only show Imsak/Iftar/Taraweeh card when Ramadan mode is enabled
                    if (special.ramadanModeEnabled)
                      SizedBox(
                        width: cardWidth,
                        child: SettingsSummaryCard(
                          title: 'Imsak, Iftar and Taraweeh times',
                          description: null,
                          body: Row(
                            children: [
                              Expanded(
                                child: _SpecialTimeSummary(
                                  label: 'IMSAK',
                                  value: '${special.imsakOffsetMinutes}',
                                  caption: 'Relative to Fajr',
                                ),
                              ),
                              Expanded(
                                child: _SpecialTimeSummary(
                                  label: 'IFTAR',
                                  value: '${special.iftarOffsetMinutes}',
                                  caption: 'Relative to Maghrib',
                                ),
                              ),
                              Expanded(
                                child: _SpecialTimeSummary(
                                  label: 'TARAWEEH',
                                  value: '${special.taraweehOffsetMinutes}',
                                  caption: 'Relative to Isha',
                                ),
                              ),
                            ],
                          ),
                          leftLabel: '',
                          leftValue: '',
                          rightLabel: '',
                          rightValue: '',
                          actionLabel: 'Edit',
                          onAction: () => _openEditDialog(
                            title: 'Imsak, Iftar and Taraweeh times',
                            child: _buildSpecialTimesEditor(provider),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const PageHeader(
      icon: Icons.access_time,
      title: 'Prayer Times',
      subtitle: 'Configure adhan calculations, iqamah settings, and location',
    );
  }

  String _iqamahModeLabel(PrayerSettings? settings) {
    final values = (settings?.iqamahUseDelay.values.toList() ?? _useDelayControllers.values.toList());
    if (values.isEmpty) return 'Delays after Athan';
    final allDelay = values.every((v) => v == true);
    return allDelay ? 'Delays after Athan' : 'Fixed times';
  }

  Future<void> _openPrayerTimesWizard(PrayerTimesProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.85;
        _PrayerWizardPage page = _PrayerWizardPage.editChooser;
        bool athanAutoSelected = provider.prayerSettings?.calculationSettings.useAutoCalculation ?? true;
        bool iqamahDelaysSelected = _iqamahModeLabel(provider.prayerSettings) == 'Delays after Athan';

        return StatefulBuilder(
          builder: (context, setState) {
            final liveProvider = Provider.of<PrayerTimesProvider>(context);
            Widget content;

            switch (page) {
              case _PrayerWizardPage.editChooser:
                content = _buildEditChooser(
                  onAthan: () => setState(() => page = _PrayerWizardPage.athanChoice),
                  onIqamah: () => setState(() => page = _PrayerWizardPage.iqamahChoice),
                );
                break;
              case _PrayerWizardPage.athanChoice:
                content = _buildAthanChoice(
                  autoSelected: athanAutoSelected,
                  onAuto: () => setState(() {
                    athanAutoSelected = true;
                    page = _PrayerWizardPage.athanAutomatic;
                  }),
                  onImport: () => setState(() {
                    athanAutoSelected = false;
                    page = _PrayerWizardPage.athanImport;
                  }),
                );
                break;
              case _PrayerWizardPage.athanAutomatic:
                content = _buildAthanAutomatic(liveProvider);
                break;
              case _PrayerWizardPage.athanImport:
                content = _buildImportSection();
                break;
              case _PrayerWizardPage.iqamahChoice:
                content = _buildIqamahChoice(
                  delaysSelected: iqamahDelaysSelected,
                  onDelays: () => setState(() {
                    iqamahDelaysSelected = true;
                    page = _PrayerWizardPage.iqamahDelays;
                  }),
                  onImport: () => setState(() {
                    iqamahDelaysSelected = false;
                    page = _PrayerWizardPage.iqamahImport;
                  }),
                );
                break;
              case _PrayerWizardPage.iqamahDelays:
                content = _buildIqamahDelays(liveProvider);
                break;
              case _PrayerWizardPage.iqamahImport:
                content = _buildImportSection();
                break;
            }

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1040, maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Prayer times',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _WizardStepper(page: page),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(child: content),
                      ),
                      if (page != _PrayerWizardPage.editChooser)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                page = _PrayerWizardPage.editChooser;
                              });
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditChooser({
    required VoidCallback onAthan,
    required VoidCallback onIqamah,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          const Text(
            'You wish to set:',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final gap = 18.0;
              final itemWidth = isWide
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.mosque_outlined,
                      label: 'Athan times',
                      onTap: onAthan,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.groups_outlined,
                      label: 'Iqamah times',
                      onTap: onIqamah,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAthanChoice({
    required bool autoSelected,
    required VoidCallback onAuto,
    required VoidCallback onImport,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          const Text(
            'For the calculation of athan, you want to:',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final gap = 18.0;
              final itemWidth = isWide
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.timer_outlined,
                      label: 'Choose an automatic calculation method',
                      badge: autoSelected ? 'Current choice' : null,
                      onTap: onAuto,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.table_rows_outlined,
                      label: 'Import your timetable file',
                      badge: !autoSelected ? 'Current choice' : null,
                      onTap: onImport,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIqamahChoice({
    required bool delaysSelected,
    required VoidCallback onDelays,
    required VoidCallback onImport,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          const Text(
            'For the calculation of iqamah, you want to:',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 820;
              final gap = 18.0;
              final itemWidth = isWide
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.schedule,
                      label: 'Define delays after the athan or fixed times',
                      badge: delaysSelected ? 'Current choice' : null,
                      onTap: onDelays,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.table_rows_outlined,
                      label: 'Import your timetable file',
                      badge: !delaysSelected ? 'Current choice' : null,
                      onTap: onImport,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAthanAutomatic(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    final current = settings?.calculationSettings ?? CalculationSettings();

    String selectedMethod = current.method;
    String selectedAsr = current.asrMethod;
    String selectedHighLat = current.highLatitudeRule;

    final methods = PrayerApiService.getCalculationMethods();
    final asrOptions = const ['Shafi', 'Hanafi'];
    final highLatOptions = const ['AngleBased', 'Midnight', 'OneSeventh'];

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can choose a calculation method for the prayer times. You can also choose the custom method and define your own calculation parameters.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _LabeledDropdown(
              title: 'Calculation method',
              value: selectedMethod,
              items: methods,
              onChanged: (value) => setState(() => selectedMethod = value),
            ),
            const SizedBox(height: 14),
            _LabeledDropdown(
              title: 'Asr according to the school',
              value: selectedAsr,
              items: asrOptions,
              onChanged: (value) => setState(() => selectedAsr = value),
            ),
            const SizedBox(height: 14),
            _LabeledDropdown(
              title: 'High latitude rule',
              value: selectedHighLat,
              items: highLatOptions,
              onChanged: (value) => setState(() => selectedHighLat = value),
              helperText: 'Used to set a minimum time for Fajr and a max time for Isha',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _buildLocationSettings(provider),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: provider.isCalculating ? null : () async {
                  // Save settings first
                  final newSettings = current.copyWith(
                    method: selectedMethod,
                    asrMethod: selectedAsr,
                    highLatitudeRule: selectedHighLat,
                    useAutoCalculation: true,
                  );
                  await provider.updateCalculationSettings(newSettings);
                  
                  // Now auto-calculate prayer times
                  final location = provider.prayerSettings?.location;
                  if (location != null && 
                      ((location.city.isNotEmpty && location.country.isNotEmpty) ||
                       (location.latitude != 0.0 && location.longitude != 0.0))) {
                    await provider.calculatePrayerTimes();
                  }
                  
                  if (!mounted) return;
                  if (provider.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Prayer times calculated and saved!'),
                        backgroundColor: AdminTheme.accentEmerald,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: provider.isCalculating 
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Calculate & Save Prayer Times', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIqamahDelays(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    if (settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You can define delays after the athan or fixed times for the iqamah.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...settings.prayerTimes.entries.map((entry) {
          final prayer = entry.key;
          final useDelay = settings.iqamahUseDelay[prayer] ?? true;
          final delayController = _delayControllers[prayer] ?? TextEditingController(text: entry.value.delay.toString());
          _delayControllers[prayer] = delayController;

          return Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalizeFirst(prayer),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ToggleChoiceButton(
                        selected: useDelay,
                        label: 'Delay after the\nathan',
                        onTap: () async {
                          setState(() => _useDelayControllers[prayer] = true);
                          await provider.updateIqamahMode(prayer, true);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ToggleChoiceButton(
                        selected: !useDelay,
                        label: 'Fixed time',
                        onTap: () async {
                          setState(() => _useDelayControllers[prayer] = false);
                          await provider.updateIqamahMode(prayer, false);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (useDelay)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: delayController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          onChanged: (value) async {
                            final current = provider.prayerSettings?.prayerTimes[prayer];
                            if (current == null) return;
                            final minutes = int.tryParse(value) ?? current.delay;
                            await provider.updatePrayerTime(prayer, current.copyWith(delay: minutes));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Builder(
                            builder: (context) {
                              final current = provider.prayerSettings?.prayerTimes[prayer];
                              final computed = current == null
                                  ? '--:--'
                                  : PrayerApiService.calculateIqamah(current.adhan, current.delay);
                              return Text(
                                computed,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        )
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: _iqamahControllers[prayer],
                    decoration: InputDecoration(
                      hintText: 'HH:MM',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    onChanged: (value) async {
                      final current = provider.prayerSettings?.prayerTimes[prayer];
                      if (current == null) return;
                      await provider.updatePrayerTime(prayer, current.copyWith(iqamah: value));
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJumuahEditor(PrayerTimesProvider provider) {
    final times = provider.prayerSettings?.jumuahTimes ?? const ['13:30', '13:30'];
    final first = TextEditingController(text: times.isNotEmpty ? times.first : '13:30');
    final second = TextEditingController(text: times.length > 1 ? times[1] : (times.isNotEmpty ? times.first : '13:30'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set your Jumuah prayer times:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: first,
                decoration: const InputDecoration(
                  labelText: 'First Jumuah',
                  hintText: 'HH:MM',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: second,
                decoration: const InputDecoration(
                  labelText: 'Second Jumuah',
                  hintText: 'HH:MM',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              await provider.updateJumuahTimes([first.text.trim(), second.text.trim()]);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Jumuah times saved'),
                  backgroundColor: AdminTheme.accentEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.textPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildRamadanModeCard(PrayerTimesProvider provider, SpecialTimes special) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: special.ramadanModeEnabled
                    ? [const Color(0xFF1E3A5F), const Color(0xFF4A90A4)]
                    : [Colors.grey.shade400, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ramadan Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  special.ramadanModeEnabled
                      ? 'Suhoor & Iftar times shown on TV'
                      : 'Enable to show Suhoor & Iftar on TV',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: special.ramadanModeEnabled,
            activeColor: const Color(0xFF1E3A5F),
            onChanged: (value) async {
              final updated = special.copyWith(ramadanModeEnabled: value);
              await provider.updateSpecialTimes(updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialTimesEditor(PrayerTimesProvider provider) {
    final special = provider.prayerSettings?.specialTimes ?? const SpecialTimes();
    final imsak = TextEditingController(text: special.imsakOffsetMinutes.toString());
    final iftar = TextEditingController(text: special.iftarOffsetMinutes.toString());
    final tara = TextEditingController(text: special.taraweehOffsetMinutes.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ramadan Mode Section
        _buildRamadanSection(provider, special),
        
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        
        const Text(
          'Offsets in minutes (relative times):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: imsak,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Imsak (relative to Fajr)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: iftar,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Iftar (relative to Maghrib)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: tara,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Taraweeh (relative to Isha)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              final updated = special.copyWith(
                imsakOffsetMinutes: int.tryParse(imsak.text.trim()) ?? special.imsakOffsetMinutes,
                iftarOffsetMinutes: int.tryParse(iftar.text.trim()) ?? special.iftarOffsetMinutes,
                taraweehOffsetMinutes: int.tryParse(tara.text.trim()) ?? special.taraweehOffsetMinutes,
              );
              await provider.updateSpecialTimes(updated);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Special times saved'),
                  backgroundColor: AdminTheme.accentEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.textPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildRamadanSection(PrayerTimesProvider provider, SpecialTimes special) {
    final suhoorController = TextEditingController(text: special.suhoorEndTime ?? '');
    final iftarController = TextEditingController(text: special.iftarTime ?? '');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A5F).withOpacity(0.1),
            const Color(0xFF4A90A4).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF4A90A4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.nightlight_round, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ramadan Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Display Suhoor and Iftar times on TV',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: special.ramadanModeEnabled,
                activeColor: const Color(0xFF1E3A5F),
                onChanged: (value) async {
                  final updated = special.copyWith(ramadanModeEnabled: value);
                  await provider.updateSpecialTimes(updated);
                },
              ),
            ],
          ),
          
          if (special.ramadanModeEnabled) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wb_twilight, size: 18, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Suhoor Ends',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: suhoorController,
                        decoration: InputDecoration(
                          hintText: 'e.g., 05:30',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.dinner_dining, size: 18, color: Colors.deepOrange[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Iftar Time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: iftarController,
                        decoration: InputDecoration(
                          hintText: 'e.g., 18:45',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final updated = special.copyWith(
                    suhoorEndTime: suhoorController.text.trim().isNotEmpty 
                        ? suhoorController.text.trim() 
                        : null,
                    iftarTime: iftarController.text.trim().isNotEmpty 
                        ? iftarController.text.trim() 
                        : null,
                  );
                  await provider.updateSpecialTimes(updated);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Ramadan times saved'),
                      backgroundColor: AdminTheme.accentEmerald,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Ramadan Times', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverridesEditor(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    if (settings == null) return const SizedBox.shrink();

    final overrides = Map<String, PrayerTimeOverride>.from(settings.prayerTimeOverrides);
    final minControllers = <String, TextEditingController>{};
    final maxControllers = <String, TextEditingController>{};

    for (final key in settings.prayerTimes.keys) {
      final current = overrides[key];
      minControllers[key] = TextEditingController(text: current?.minTime ?? '');
      maxControllers[key] = TextEditingController(text: current?.maxTime ?? '');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optional min/max times per prayer (HH:MM):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        ...settings.prayerTimes.keys.map((prayer) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    _capitalizeFirst(prayer),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AdminTheme.textPrimary),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: minControllers[prayer],
                    decoration: const InputDecoration(
                      labelText: 'Min',
                      hintText: 'HH:MM',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxControllers[prayer],
                    decoration: const InputDecoration(
                      labelText: 'Max',
                      hintText: 'HH:MM',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              final updated = <String, PrayerTimeOverride>{};
              for (final prayer in settings.prayerTimes.keys) {
                final min = minControllers[prayer]?.text.trim();
                final max = maxControllers[prayer]?.text.trim();
                if ((min ?? '').isEmpty && (max ?? '').isEmpty) {
                  continue;
                }
                updated[prayer] = PrayerTimeOverride(
                  minTime: (min ?? '').isEmpty ? null : min,
                  maxTime: (max ?? '').isEmpty ? null : max,
                );
              }
              await provider.updatePrayerOverrides(updated);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Overrides saved'),
                  backgroundColor: AdminTheme.accentEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.textPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  String _locationSummary(PrayerSettings? settings) {
    if (settings == null) return '--';
    final loc = settings.location;
    final hasCoords = loc.latitude != 0.0 && loc.longitude != 0.0;
    if (hasCoords) return 'Coordinates';
    final hasCity = loc.city.trim().isNotEmpty;
    final hasCountry = loc.country.trim().isNotEmpty;
    if (hasCity || hasCountry) return 'City/Country';
    return 'Not set';
  }

  Future<void> _openEditDialog({
    required String title,
    required Widget child,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.85;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1040, maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AdminTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(child: child),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 0),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _selectedTab == 0
                        ? const LinearGradient(
                            colors: [AdminTheme.primaryBlueLight, AdminTheme.primaryBlue],
                          )
                        : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Adhan Times',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedTab == 0 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = 1),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _selectedTab == 1
                        ? const LinearGradient(
                            colors: [AdminTheme.primaryBlueLight, AdminTheme.primaryBlue],
                          )
                        : null,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Iqamah Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _selectedTab == 1 ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdhanTab(PrayerTimesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryBlueLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.mic_none,
                        color: AdminTheme.primaryBlueLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adhan Times Configuration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Set exact adhan times for each prayer',
                            style: TextStyle(
                              color: AdminTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Table Header
                Container(
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryBlueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Prayer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Adhan Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                
                // Prayer Rows
                if (provider.prayerSettings != null)
                  ...provider.prayerSettings!.prayerTimes.entries.map((entry) {
                    final prayer = entry.key;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: _getPrayerColor(prayer).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          _getPrayerIcon(prayer),
                                          color: _getPrayerColor(prayer),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _capitalizeFirst(prayer),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AdminTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _adhanControllers[prayer],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AdminTheme.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'HH:MM',
                                      hintStyle: TextStyle(color: Colors.grey.shade400),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: AdminTheme.primaryBlueLight, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      suffixIcon: Icon(
                                        Icons.schedule,
                                        color: Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ),
                                    // Do not save on each keystroke; save on button press.
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          
          // Save Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final settings = provider.prayerSettings;
                    if (settings == null) return;

                    final updatedPrayerTimes = Map<String, PrayerTime>.from(settings.prayerTimes);
                    for (final prayer in settings.prayerTimes.keys) {
                      final ctrl = _adhanControllers[prayer];
                      if (ctrl == null) continue;
                      final existing = updatedPrayerTimes[prayer];
                      if (existing == null) continue;
                      updatedPrayerTimes[prayer] = existing.copyWith(adhan: ctrl.text.trim());
                    }

                    await provider.savePrayerTimesBulk(
                      prayerTimes: updatedPrayerTimes,
                      iqamahUseDelay: Map<String, bool>.from(settings.iqamahUseDelay),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Adhan times saved successfully'),
                        backgroundColor: AdminTheme.accentEmerald,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryBlueLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildIqamahTab(PrayerTimesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AdminTheme.primaryBlueLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: AdminTheme.primaryBlueLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iqamah Configuration',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Set iqamah times or delays after adhan',
                            style: TextStyle(
                              color: AdminTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                if (provider.prayerSettings != null)
                  Column(
                    children: provider.prayerSettings!.prayerTimes.entries.map((entry) {
                      final prayer = entry.key;
                      final useDelay = _useDelayControllers[prayer] ?? true;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _getPrayerColor(prayer).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getPrayerIcon(prayer),
                                      color: _getPrayerColor(prayer),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _capitalizeFirst(prayer),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: AdminTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Mode Selection
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(() => _useDelayControllers[prayer] = true),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: useDelay ? AdminTheme.primaryBlueLight.withOpacity(0.1) : Colors.transparent,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                bottomLeft: Radius.circular(12),
                                              ),
                                              border: Border.all(
                                                color: useDelay ? AdminTheme.primaryBlueLight.withOpacity(0.3) : Colors.transparent,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Delay after Adhan',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: useDelay ? AdminTheme.primaryBlueLight : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => setState(() => _useDelayControllers[prayer] = false),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            decoration: BoxDecoration(
                                              color: !useDelay ? AdminTheme.primaryBlue.withOpacity(0.1) : Colors.transparent,
                                              borderRadius: const BorderRadius.only(
                                                topRight: Radius.circular(12),
                                                bottomRight: Radius.circular(12),
                                              ),
                                              border: Border.all(
                                                color: !useDelay ? AdminTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Fixed Time',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: !useDelay ? AdminTheme.primaryBlue : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Input Field
                              TextField(
                                controller: useDelay ? _delayControllers[prayer] : _iqamahControllers[prayer],
                                keyboardType: useDelay ? TextInputType.number : TextInputType.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AdminTheme.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  labelText: useDelay ? 'Delay after Adhan' : 'Iqamah Time',
                                  hintText: useDelay ? 'Enter minutes' : 'HH:MM',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AdminTheme.primaryBlueLight, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  suffixIcon: Icon(
                                    useDelay ? Icons.timer_outlined : Icons.schedule,
                                    color: Colors.grey.shade400,
                                    size: 20,
                                  ),
                                  suffixText: useDelay ? 'min' : null,
                                ),
                                // Do not save on each keystroke; save on button press.
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          
          // Save Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final settings = provider.prayerSettings;
                    if (settings == null) return;

                    final updatedPrayerTimes = Map<String, PrayerTime>.from(settings.prayerTimes);
                    final updatedUseDelay = <String, bool>{};

                    for (final prayer in settings.prayerTimes.keys) {
                      final useDelay = _useDelayControllers[prayer] ?? (settings.iqamahUseDelay[prayer] ?? true);
                      updatedUseDelay[prayer] = useDelay;

                      final existing = updatedPrayerTimes[prayer];
                      if (existing == null) continue;

                      if (useDelay) {
                        final delayCtrl = _delayControllers[prayer];
                        final delayMinutes = int.tryParse(delayCtrl?.text.trim() ?? '');
                        updatedPrayerTimes[prayer] = existing.copyWith(
                          delay: delayMinutes ?? existing.delay,
                        );
                      } else {
                        final iqamahCtrl = _iqamahControllers[prayer];
                        updatedPrayerTimes[prayer] = existing.copyWith(
                          iqamah: (iqamahCtrl?.text ?? '').trim(),
                        );
                      }
                    }

                    await provider.savePrayerTimesBulk(
                      prayerTimes: updatedPrayerTimes,
                      iqamahUseDelay: updatedUseDelay,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Iqamah times saved successfully'),
                        backgroundColor: AdminTheme.accentEmerald,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryBlueLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Iqamah Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildGeneralSettings(PrayerTimesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryBlueLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: AdminTheme.primaryBlueLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculation Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure prayer time calculation methods',
                        style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Calculation Method
            _buildDropdownSetting(
              title: 'Calculation Method',
              value: provider.prayerSettings?.calculationSettings.method ?? 'MWL',
              options: const [
                DropdownMenuItem(value: 'MWL', child: Text('Muslim World League')),
                DropdownMenuItem(value: 'ISNA', child: Text('Islamic Society of North America')),
                DropdownMenuItem(value: 'Egypt', child: Text('Egyptian General Authority')),
                DropdownMenuItem(value: 'Makkah', child: Text('Umm al-Qura University, Makkah')),
                DropdownMenuItem(value: 'Karachi', child: Text('University of Islamic Sciences, Karachi')),
                DropdownMenuItem(value: 'Custom', child: Text('Custom Method')),
              ],
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider.prayerSettings!.calculationSettings.copyWith(method: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Asr Method
            _buildDropdownSetting(
              title: 'Asr Calculation Method',
              value: provider.prayerSettings?.calculationSettings.asrMethod ?? 'Shafi',
              options: ['Shafi', 'Hanafi'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider.prayerSettings!.calculationSettings.copyWith(asrMethod: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // High Latitude Rule
            _buildDropdownSetting(
              title: 'High Latitude Rule',
              value: provider.prayerSettings?.calculationSettings.adjustmentMethod ?? 'AngleBased',
              options: const [
                DropdownMenuItem(value: 'Midnight', child: Text('Midnight')),
                DropdownMenuItem(value: 'OneSeventh', child: Text('One Seventh')),
                DropdownMenuItem(value: 'AngleBased', child: Text('Angle Based')),
              ],
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider.prayerSettings!.calculationSettings.copyWith(adjustmentMethod: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSettings(PrayerTimesProvider provider) {
    // Common cities for autocomplete
    final commonCities = [
      'New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix',
      'London', 'Birmingham', 'Manchester', 'Leeds', 'Glasgow',
      'Toronto', 'Montreal', 'Vancouver', 'Calgary', 'Ottawa',
      'Dubai', 'Abu Dhabi', 'Sharjah', 'Riyadh', 'Jeddah', 'Mecca', 'Medina',
      'Cairo', 'Alexandria', 'Giza', 'Casablanca', 'Rabat',
      'Karachi', 'Lahore', 'Islamabad', 'Dhaka', 'Chittagong',
      'Jakarta', 'Kuala Lumpur', 'Singapore', 'Istanbul', 'Ankara',
      'Paris', 'Berlin', 'Amsterdam', 'Brussels', 'Vienna',
      'Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Auckland',
      'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai',
    ];
    
    final commonCountries = [
      'USA', 'United States', 'UK', 'United Kingdom', 'Canada', 'Australia',
      'UAE', 'United Arab Emirates', 'Saudi Arabia', 'Egypt', 'Morocco',
      'Pakistan', 'Bangladesh', 'India', 'Indonesia', 'Malaysia', 'Singapore',
      'Turkey', 'France', 'Germany', 'Netherlands', 'Belgium', 'Austria',
      'South Africa', 'Nigeria', 'Kenya', 'New Zealand',
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.accentEmerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: AdminTheme.accentEmerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Set your masjid location for accurate calculations',
                        style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // City and Country Row with Autocomplete
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildAutocompleteField(
                    controller: _cityController,
                    label: 'City',
                    hint: 'e.g., New York',
                    icon: Icons.location_city,
                    suggestions: commonCities,
                    onChanged: (value) async {
                      if (provider.prayerSettings != null) {
                        final newLocation = provider.prayerSettings!.location.copyWith(city: value);
                        await provider.updateLocationSettings(newLocation);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildAutocompleteField(
                    controller: _countryController,
                    label: 'Country',
                    hint: 'e.g., USA',
                    icon: Icons.public,
                    suggestions: commonCountries,
                    onChanged: (value) async {
                      if (provider.prayerSettings != null) {
                        final newLocation = provider.prayerSettings!.location.copyWith(country: value);
                        await provider.updateLocationSettings(newLocation);
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Latitude and Longitude Row
            Row(
              children: [
                Expanded(
                  child: _buildLocationField(
                    controller: _latitudeController,
                    label: 'Latitude (Optional)',
                    hint: 'e.g., 40.7128',
                    icon: Icons.explore,
                    keyboardType: TextInputType.number,
                    onChanged: (value) async {
                      if (provider.prayerSettings != null) {
                        final latitude = double.tryParse(value) ?? 0.0;
                        final newLocation = provider.prayerSettings!.location.copyWith(latitude: latitude);
                        await provider.updateLocationSettings(newLocation);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildLocationField(
                    controller: _longitudeController,
                    label: 'Longitude (Optional)',
                    hint: 'e.g., -74.0060',
                    icon: Icons.explore,
                    keyboardType: TextInputType.number,
                    onChanged: (value) async {
                      if (provider.prayerSettings != null) {
                        final longitude = double.tryParse(value) ?? 0.0;
                        final newLocation = provider.prayerSettings!.location.copyWith(longitude: longitude);
                        await provider.updateLocationSettings(newLocation);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> suggestions,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: controller.text),
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return suggestions.where((option) =>
                option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (selection) {
            controller.text = selection;
            onChanged(selection);
          },
          fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
            // Sync the external controller with autocomplete controller
            if (controller.text.isNotEmpty && textController.text.isEmpty) {
              textController.text = controller.text;
            }
            return TextField(
              controller: textController,
              focusNode: focusNode,
              style: const TextStyle(fontSize: 15, color: AdminTheme.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AdminTheme.accentEmerald, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
              ),
              onChanged: (value) {
                controller.text = value;
                onChanged(value);
              },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecalculateSection(PrayerTimesProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.accentSkyBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: AdminTheme.accentSkyBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recalculate Prayer Times',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Update prayer times based on your settings',
                        style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Current Settings Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AdminTheme.primaryBlueLight.withOpacity(0.05),
                    AdminTheme.primaryBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.primaryBlueLight.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calculation Method:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AdminTheme.textSubtle,
                          fontSize: 14,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryBlueLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            provider.prayerSettings?.calculationSettings.method ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.primaryBlueLight,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Location:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AdminTheme.textSubtle,
                          fontSize: 14,
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AdminTheme.accentEmerald.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${provider.prayerSettings?.location.city ?? 'N/A'}, ${provider.prayerSettings?.location.country ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AdminTheme.accentEmerald,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isCalculating 
                  ? null 
                  : () async {
                    if (provider.prayerSettings == null || 
                        (provider.prayerSettings!.location.latitude == 0.0 && 
                         provider.prayerSettings!.location.longitude == 0.0 &&
                         provider.prayerSettings!.location.city.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(child: Text('Location not set! Please set location first.')),
                            ],
                          ),
                          backgroundColor: AdminTheme.accentRedLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    try {
                      await provider.calculatePrayerTimes();
                      _updateControllers();
                      setState(() {});
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Expanded(child: Text('Prayer times recalculated successfully!')),
                            ],
                          ),
                          backgroundColor: AdminTheme.accentEmerald,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Error: $e')),
                            ],
                          ),
                          backgroundColor: AdminTheme.accentRedLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryBlueLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: provider.isCalculating
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
                label: provider.isCalculating
                  ? const Text('Calculating...')
                  : const Text(
                      'Recalculate Prayer Times',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.upload_file,
                    color: AdminTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Timetable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Upload CSV or Excel file with prayer times',
                        style: TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade50,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Drag & drop your file here',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'or click to browse',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AdminTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text(
                  'Choose File',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            items: options,
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 15,
              color: AdminTheme.textPrimary,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AdminTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            color: AdminTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTheme.accentEmerald, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Icon(
              icon,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Color _getPrayerColor(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return AdminTheme.primaryBlue;
      case 'dhuhr':
        return AdminTheme.accentSkyBlue;
      case 'asr':
        return AdminTheme.accentEmerald;
      case 'maghrib':
        return AdminTheme.primaryBlueLight;
      case 'isha':
        return AdminTheme.primaryBlueLight;
      default:
        return AdminTheme.textMuted;
    }
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return Icons.wb_sunny;
      case 'dhuhr':
        return Icons.wb_twilight;
      case 'asr':
        return Icons.access_time;
      case 'maghrib':
        return Icons.nights_stay;
      case 'isha':
        return Icons.nightlight_round;
      default:
        return Icons.schedule;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

