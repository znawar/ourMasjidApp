import 'package:admin_web/providers/prayer_times_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/widgets/settings_summary_card.dart';
import 'package:admin_web/models/prayer_settings_model.dart';
import 'package:admin_web/services/prayer_api_service.dart';
import 'package:admin_web/services/location_autocomplete_service.dart';
import 'package:admin_web/services/timezone_service.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_picker_web/image_picker_web.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin_web/utils/admin_theme.dart';

enum _PrayerWizardPage {
  editChooser,
  athanChoice,
  athanAutomatic,
  athanManual,
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
      page == _PrayerWizardPage.athanManual ||
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
      case _PrayerWizardPage.athanManual:
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
            _StepDef(Icons.schedule, 'Times'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

// Reusable Location Picker Widget to eliminate redundancy
class LocationPickerWidget extends StatefulWidget {
  final LocationSettings location;
  final Function(LocationSettings) onLocationChanged;
  final VoidCallback? onLocationResolved;

  const LocationPickerWidget({
    required this.location,
    required this.onLocationChanged,
    this.onLocationResolved,
    super.key,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late TextEditingController _cityController;
  late TextEditingController _countryController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  TextEditingController? _cityAutocompleteController;

  List<String> _countries = [];
  bool _loadingCountries = false;
  List<String> _cityApiSuggestions = [];
  bool _loadingCitySuggestions = false;
  Timer? _cityDebounce;
  Timer? _coordDebounce;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCountries();
  }

  void _initializeControllers() {
    _cityController = TextEditingController(text: widget.location.city);
    _countryController = TextEditingController(text: widget.location.country);
    _latitudeController = TextEditingController(text: widget.location.latitude != 0.0 ? widget.location.latitude.toString() : '');
    _longitudeController = TextEditingController(text: widget.location.longitude != 0.0 ? widget.location.longitude.toString() : '');
  }

  Future<void> _loadCountries() async {
    setState(() => _loadingCountries = true);
    try {
      final countries = await LocationAutocompleteService.getCountries();
      if (mounted) {
        setState(() {
          _countries = countries;
          _loadingCountries = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading countries: $e');
      if (mounted) {
        setState(() => _loadingCountries = false);
      }
    }
  }

  void _searchCitiesDebounced(String query) {
    _cityDebounce?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _cityApiSuggestions = [];
          _loadingCitySuggestions = false;
        });
      }
      return;
    }
    _cityDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _loadingCitySuggestions = true);
      try {
        final currentCountry = _countryController.text.isEmpty ? null : _countryController.text;
        final cities = await LocationAutocompleteService.searchCities(
          query,
          country: currentCountry,
          limit: 20,
        );
        if (mounted) {
          setState(() {
            _cityApiSuggestions = cities;
            _loadingCitySuggestions = false;
          });
          // Trigger the autocomplete dropdown to refresh with new data by re-assigning value
          if (_cityAutocompleteController != null) {
            _cityAutocompleteController!.value = _cityAutocompleteController!.value;
          }
        }
      } catch (e) {
        debugPrint('Error searching cities: $e');
        if (mounted) {
          setState(() => _loadingCitySuggestions = false);
        }
      }
    });
  }

  void _onCoordinatesChangedDebounced() {
    _coordDebounce?.cancel();
    _coordDebounce = Timer(const Duration(milliseconds: 1000), () async {
      final lat = double.tryParse(_latitudeController.text);
      final lon = double.tryParse(_longitudeController.text);
      
      if (lat != null && lon != null) {
        var newLocation = widget.location.copyWith(
          latitude: lat,
          longitude: lon,
        );
        
        // Attempt to resolve timezone from coordinates
        final tzResult = await TimezoneService.getTimezoneFromFreeService(lat, lon);
        if (tzResult != null) {
          newLocation = newLocation.copyWith(timezone: tzResult.timezoneId);
        }
        
        widget.onLocationChanged(newLocation);
      }
    });
  }

  @override
  void dispose() {
    _cityDebounce?.cancel();
    _coordDebounce?.cancel();
    _cityController.dispose();
    _countryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Location Settings',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 16),
        
        // Country Input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Country',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Autocomplete<String>(
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                if (_countryController.text.isNotEmpty && textEditingController.text.isEmpty) {
                  textEditingController.text = _countryController.text;
                }
                
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Select country',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _loadingCountries 
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    _countryController.text = value;
                    widget.onLocationChanged(widget.location.copyWith(country: value));
                  },
                );
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _countries;
                }
                return _countries.where((country) =>
                    country.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                _countryController.text = selection;
                widget.onLocationChanged(widget.location.copyWith(country: selection));
                setState(() => _cityApiSuggestions = []);
                _cityController.text = '';
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Material(
                  elevation: 4,
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
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
                );
              },
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // City Input
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'City',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Autocomplete<String>(
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                _cityAutocompleteController = textEditingController;
                if (_cityController.text.isNotEmpty && textEditingController.text.isEmpty) {
                  textEditingController.text = _cityController.text;
                }
                
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Start typing city name...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _loadingCitySuggestions 
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    _cityController.text = value;
                    _searchCitiesDebounced(value);
                    widget.onLocationChanged(widget.location.copyWith(city: value));
                  },
                );
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return _cityApiSuggestions;
              },
              onSelected: (String selection) async {
                _cityController.text = selection.split(',').first.trim();
                
                final coords = await LocationAutocompleteService.resolveToCoordinates(
                  selection,
                  country: _countryController.text.isEmpty ? null : _countryController.text,
                );
                
                var newLocation = widget.location.copyWith(city: _cityController.text);
                
                if (coords != null) {
                  final lat = coords['lat'] ?? 0.0;
                  final lon = coords['lon'] ?? 0.0;
                  newLocation = newLocation.copyWith(
                    latitude: lat,
                    longitude: lon,
                  );
                  _latitudeController.text = lat.toString();
                  _longitudeController.text = lon.toString();

                  // Attempt to resolve timezone from coordinates
                  final tzResult = await TimezoneService.getTimezoneFromFreeService(lat, lon);
                  if (tzResult != null) {
                    newLocation = newLocation.copyWith(timezone: tzResult.timezoneId);
                  }
                }
                
                widget.onLocationChanged(newLocation);
                widget.onLocationResolved?.call();
                
                setState(() => _cityApiSuggestions = []);
              },
              optionsViewBuilder: (context, onSelected, options) {
                if (options.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Material(
                  elevation: 4,
                  child: SizedBox(
                    height: 300,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
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
                );
              },
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Text(
          'OR',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        
        const SizedBox(height: 16),
        
        // Latitude and Longitude
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latitude',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _latitudeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g., -33.8688',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      _onCoordinatesChangedDebounced();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Longitude',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _longitudeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'e.g., 151.2093',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) {
                      _onCoordinatesChangedDebounced();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
    // --- Calculation helpers for Ramadan summary ---
    String? _calculateSuhoorEndTime(PrayerTimesProvider provider, SpecialTimes special) {
      final fajr = provider.prayerSettings?.prayerTimes['Fajr']?.adhan;
      final offset = special.imsakOffsetMinutes;
      if (fajr == null || fajr.isEmpty) return null;
      return _addMinutesToTime(fajr, offset);
    }

    String? _calculateIftarTime(PrayerTimesProvider provider, SpecialTimes special) {
      final maghrib = provider.prayerSettings?.prayerTimes['Maghrib']?.adhan;
      final offset = special.iftarOffsetMinutes;
      if (maghrib == null || maghrib.isEmpty) return null;
      return _addMinutesToTime(maghrib, offset);
    }

    String _addMinutesToTime(String time, int minutesToAdd) {
      // time is expected in HH:mm
      final parts = time.split(':');
      if (parts.length != 2) return time;
      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = int.tryParse(parts[1]) ?? 0;
      int totalMinutes = hour * 60 + minute + minutesToAdd;
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      totalMinutes = totalMinutes % (24 * 60);
      final newHour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
      final newMinute = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$newHour:$newMinute';
    }
  int _selectedTab = 0;
  final Map<String, TextEditingController> _adhanControllers = {};
  final Map<String, TextEditingController> _iqamahControllers = {};
  final Map<String, TextEditingController> _delayControllers = {};
  final Map<String, bool> _useDelayControllers = {};

  DateTime? _lastSyncedLastUpdated;

  // Iqamah background image state
  Uint8List? _selectedImageBytes;
  bool _uploadingImage = false;
  String? _previewImageBase64;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final provider = Provider.of<PrayerTimesProvider>(context, listen: false);

    try {
      final prayerSettings = provider.prayerSettings;
      if (prayerSettings != null && prayerSettings.prayerTimes.isNotEmpty) {
        prayerSettings.prayerTimes.forEach((prayer, time) {
          _adhanControllers[prayer] = TextEditingController(text: time.adhan);
          _iqamahControllers[prayer] = TextEditingController(text: time.iqamah);
          _delayControllers[prayer] =
              TextEditingController(text: time.delay.toString());
          _useDelayControllers[prayer] =
              prayerSettings.iqamahUseDelay[prayer] ?? true;
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

          _useDelayControllers[prayer] =
              prayerSettings.iqamahUseDelay[prayer] ?? true;
        });
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
    super.dispose();
  }

  /// Pick an image file from the user's device and convert to base64
  Future<void> _pickIqamahImage() async {
    try {
      final result = await ImagePickerWeb.getImageAsBytes();
      if (result != null) {
        final imageBase64 = 'data:image/jpeg;base64,${base64Encode(result)}';
        setState(() {
          _selectedImageBytes = result;
          _previewImageBase64 = imageBase64;
        });
        debugPrint('✅ Image selected: ${result.length} bytes');
      }
    } catch (e) {
      debugPrint('❌ Image picker error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Save the selected image to Firestore as base64
  Future<void> _saveIqamahImage(PrayerTimesProvider provider) async {
    if (_previewImageBase64 == null || _previewImageBase64!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image first'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _uploadingImage = true);

    try {
      // Save to Firestore under masjid document
      final masjidId = provider.prayerSettings?.masjidId;
      if (masjidId == null || masjidId.isEmpty) {
        throw 'Masjid ID not found. Please save location first.';
      }

      await FirebaseFirestore.instance.collection('masjids').doc(masjidId).update({
        'iqamahBackgroundImage': _previewImageBase64,
      });

      setState(() {
        _uploadingImage = false;
        _selectedImageBytes = null;
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Iqamah background image saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PrayerTimesProvider>(context);

    // Keep UI controllers synced with the latest loaded/saved settings.
    final currentLastUpdated = provider.prayerSettings?.lastUpdated;
    if (currentLastUpdated != null &&
        (_lastSyncedLastUpdated == null ||
            currentLastUpdated.isAfter(_lastSyncedLastUpdated!))) {
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
          if (provider.errorMessage != null &&
              provider.errorMessage!.trim().isNotEmpty) ...[
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
                final jumuah = (settings?.jumuahTimes.isNotEmpty ?? false)
                    ? settings!.jumuahTimes.first
                    : '--';

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
                        body: Text(
                          jumuah,
                          style: const TextStyle(
                            color: AdminTheme.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
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
                    // Ramadan Mode toggle card - always visible
                    SizedBox(
                      width: cardWidth,
                      child: _buildRamadanModeCard(provider, special),
                    ),
                    // Only show Suhoor End/Iftar card when Ramadan mode is enabled
                    if (special.ramadanModeEnabled)
                      SizedBox(
                        width: cardWidth,
                        child: SettingsSummaryCard(
                          title: 'Suhoor End and Iftar times',
                          description: null,
                          body: Row(
                            children: [
                              Expanded(
                                child: _SpecialTimeSummary(
                                  label: 'SUHOOR END',
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
                            ],
                          ),
                          leftLabel: '',
                          leftValue: '',
                          rightLabel: '',
                          rightValue: '',
                          actionLabel: 'Edit',
                          onAction: () => _openEditDialog(
                            title: 'Suhoor End and Iftar times',
                            child: _buildSpecialTimesEditor(provider),
                          ),
                        ),
                      ),
                    // Iqamah background image card
                    SizedBox(
                      width: cardWidth,
                      child: _buildIqamahImageCard(provider),
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
    return PageHeader(
      icon: Icons.access_time,
      title: 'Prayer Times',
      subtitle: 'Configure adhan calculations, iqamah settings, and location',
    );
  }

  Widget _buildIqamahImageCard(PrayerTimesProvider provider) {
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminTheme.accentEmerald.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: AdminTheme.accentEmerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Iqamah Background Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AdminTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose an image for the iqamah timer screens',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Image preview
            if (_previewImageBase64 != null && _previewImageBase64!.isNotEmpty && _selectedImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Image.memory(
                    _selectedImageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No image selected',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Button group
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _uploadingImage ? null : _pickIqamahImage,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Choose Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryBlueLight,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _uploadingImage || _previewImageBase64 == null
                      ? null
                      : () => _saveIqamahImage(provider),
                  icon: _uploadingImage
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_uploadingImage ? 'Saving...' : 'Save Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.accentEmerald,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _iqamahModeLabel(PrayerSettings? settings) {
    final values = (settings?.iqamahUseDelay.values.toList() ??
        _useDelayControllers.values.toList());
    if (values.isEmpty) return 'Delays after Athan';
    final allDelay = values.every((v) => v == true);
    return allDelay ? 'Delays after Athan' : 'Fixed times';
  }

  bool _isAthanManualMode(PrayerSettings? settings) {
    // Manual mode if: not auto calculation AND has overrides for all prayers
    if (settings == null) return false;
    if (settings.calculationSettings.useAutoCalculation) return false;
    // Check if we have manual overrides (not using import)
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final hasAllOverrides = prayers.every((p) => settings.prayerTimeOverrides.containsKey(p));
    return hasAllOverrides;
  }

  Future<void> _openPrayerTimesWizard(PrayerTimesProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.85;
        _PrayerWizardPage page = _PrayerWizardPage.editChooser;
        bool athanAutoSelected =
            provider.prayerSettings?.calculationSettings.useAutoCalculation ??
                true;
        bool athanManualSelected = _isAthanManualMode(provider.prayerSettings);
        bool iqamahDelaysSelected =
            _iqamahModeLabel(provider.prayerSettings) == 'Delays after Athan';

        return StatefulBuilder(
          builder: (context, setState) {
            final liveProvider = Provider.of<PrayerTimesProvider>(context);
            Widget content;

            switch (page) {
              case _PrayerWizardPage.editChooser:
                content = _buildEditChooser(
                  onAthan: () =>
                      setState(() => page = _PrayerWizardPage.athanChoice),
                  onIqamah: () =>
                      setState(() => page = _PrayerWizardPage.iqamahChoice),
                );
                break;
              case _PrayerWizardPage.athanChoice:
                content = _buildAthanChoice(
                  autoSelected: athanAutoSelected,
                  manualSelected: athanManualSelected,
                  onAuto: () => setState(() {
                    athanAutoSelected = true;
                    athanManualSelected = false;
                    page = _PrayerWizardPage.athanAutomatic;
                  }),
                  onManual: () => setState(() {
                    athanAutoSelected = false;
                    athanManualSelected = true;
                    page = _PrayerWizardPage.athanManual;
                  }),
                  onImport: () => setState(() {
                    athanAutoSelected = false;
                    athanManualSelected = false;
                    page = _PrayerWizardPage.athanImport;
                  }),
                );
                break;
              case _PrayerWizardPage.athanAutomatic:
                content = _buildAthanAutomatic(liveProvider);
                break;
              case _PrayerWizardPage.athanManual:
                content = _buildAthanManual(liveProvider);
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
                constraints:
                    BoxConstraints(maxWidth: 1040, maxHeight: maxHeight),
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
    required bool manualSelected,
    required VoidCallback onAuto,
    required VoidCallback onManual,
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
              final isWide = constraints.maxWidth >= 1100;
              final gap = 18.0;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 2 * gap) / 3
                  : isWide ? (constraints.maxWidth - gap) / 2
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
                      icon: Icons.schedule,
                      label: 'Define times manually',
                      badge: manualSelected ? 'Current choice' : null,
                      onTap: onManual,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ChoiceCard(
                      icon: Icons.table_rows_outlined,
                      label: 'Import your timetable file',
                      badge: (!autoSelected && !manualSelected) ? 'Current choice' : null,
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
    return _AthanAutomaticSection(provider: provider);
  }

  Widget _buildAthanManual(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    if (settings == null) return const SizedBox.shrink();

    // Ensure useAutoCalculation is set to false when in manual mode
    if (settings.calculationSettings.useAutoCalculation) {
      Future.microtask(() async {
        await provider.updateCalculationSettings(
          settings.calculationSettings.copyWith(useAutoCalculation: false),
        );
      });
    }

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
                  'Define the athan times manually for each prayer.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...settings.prayerTimes.entries.map((entry) {
          final prayer = entry.key;
          final prayerTime = entry.value;
          final controller = _adhanControllers[prayer] ??
              TextEditingController(text: prayerTime.adhan);
          _adhanControllers[prayer] = controller;

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
                TextField(
                  controller: controller,
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
                    // Update the prayer time with the manual athan time
                    await provider.updatePrayerTime(
                      prayer,
                      prayerTime.copyWith(adhan: value),
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildAthanAutomatic_deprecated(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    final current = settings?.calculationSettings ?? CalculationSettings();

    final methods = PrayerApiService.getCalculationMethods();
    final asrOptions = const ['Shafi', 'Hanafi'];
    final highLatOptions = const ['AngleBased', 'Midnight', 'OneSeventh'];

    // Use a mutable state holder to persist values across rebuilds
    final stateHolder = <String, String>{
      'selectedMethod': current.method,
      'selectedAsr': current.asrMethod,
      'selectedHighLat': current.highLatitudeRule,
    };

    return StatefulBuilder(
      builder: (context, setState) {
        String selectedMethod = stateHolder['selectedMethod'] ?? current.method;
        String selectedAsr = stateHolder['selectedAsr'] ?? current.asrMethod;
        String selectedHighLat = stateHolder['selectedHighLat'] ?? current.highLatitudeRule;

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
              onChanged: (value) => setState(() => stateHolder['selectedMethod'] = value),
            ),
            const SizedBox(height: 14),
            _LabeledDropdown(
              title: 'Asr according to the school',
              value: selectedAsr,
              items: asrOptions,
              onChanged: (value) => setState(() => stateHolder['selectedAsr'] = value),
            ),
            const SizedBox(height: 14),
            _LabeledDropdown(
              title: 'High latitude rule',
              value: selectedHighLat,
              items: highLatOptions,
              onChanged: (value) => setState(() => stateHolder['selectedHighLat'] = value),
              helperText:
                  'Used to set a minimum time for Fajr and a max time for Isha',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: LocationPickerWidget(
                location: provider.prayerSettings?.location ?? LocationSettings(country: '', city: '', latitude: 0.0, longitude: 0.0),
                onLocationChanged: (newLocation) async {
                  await provider.updateLocationSettings(newLocation);
                },
                onLocationResolved: () async {
                  final location = provider.prayerSettings?.location;
                  if (location != null &&
                      ((location.city.isNotEmpty && location.country.isNotEmpty) ||
                          (location.latitude != 0.0 && location.longitude != 0.0))) {
                    await provider.calculatePrayerTimes();
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: provider.isCalculating
                        ? null
                        : () async {
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
                                ((location.city.isNotEmpty &&
                                        location.country.isNotEmpty) ||
                                    (location.latitude != 0.0 &&
                                        location.longitude != 0.0))) {
                              await provider.calculatePrayerTimes();
                            }

                            if (!mounted) return;
                            if (provider.errorMessage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Prayer times calculated and saved!'),
                                  backgroundColor: AdminTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentEmerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: provider.isCalculating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Calculate & Save Prayer Times',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
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
          final delayController = _delayControllers[prayer] ??
              TextEditingController(text: entry.value.delay.toString());
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
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          onChanged: (value) async {
                            final current =
                                provider.prayerSettings?.prayerTimes[prayer];
                            if (current == null) return;
                            final minutes =
                                int.tryParse(value) ?? current.delay;
                            await provider.updatePrayerTime(
                                prayer, current.copyWith(delay: minutes));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Builder(
                          builder: (context) {
                            final current =
                                provider.prayerSettings?.prayerTimes[prayer];
                            final computed = current == null
                                ? '--:--'
                                : PrayerApiService.calculateIqamah(
                                    current.adhan, current.delay);
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
                      )),
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
                      final current =
                          provider.prayerSettings?.prayerTimes[prayer];
                      if (current == null) return;
                      await provider.updatePrayerTime(
                          prayer, current.copyWith(iqamah: value));
                    },
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final settings = provider.prayerSettings;
                  if (settings == null) return;

                  final updatedPrayerTimes =
                      Map<String, PrayerTime>.from(settings.prayerTimes);
                  final updatedUseDelay = <String, bool>{};

                  for (final prayer in settings.prayerTimes.keys) {
                    final useDelay = _useDelayControllers[prayer] ??
                        (settings.iqamahUseDelay[prayer] ?? true);
                    updatedUseDelay[prayer] = useDelay;

                    final existing = updatedPrayerTimes[prayer];
                    if (existing == null) continue;

                    if (useDelay) {
                      final delayCtrl = _delayControllers[prayer];
                      final delayMinutes =
                          int.tryParse(delayCtrl?.text.trim() ?? '');
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
                  ); // FIX: Replace with savePrayerTimes if that's the correct method

                  // Try calling savePrayerTimes instead if savePrayerTimesBulk does not exist
                  // await provider.savePrayerTimes(prayerTimes: updatedPrayerTimes, iqamahUseDelay: updatedUseDelay);

                  if (!mounted) return;
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
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Iqamah Settings',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJumuahEditor(PrayerTimesProvider provider) {
    final times =
        provider.prayerSettings?.jumuahTimes ?? const ['13:30'];
    final jumuahController =
        TextEditingController(text: times.isNotEmpty ? times.first : '13:30');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set your Jumuah prayer time:',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: jumuahController,
          decoration: const InputDecoration(
            labelText: 'Jumuah Time',
            hintText: 'HH:MM',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: () async {
              await provider
                  .updateJumuahTimes([jumuahController.text.trim()]);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Jumuah times saved'),
                  backgroundColor: AdminTheme.accentEmerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.textPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildRamadanModeCard(
      PrayerTimesProvider provider, SpecialTimes special) {
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
            child: const Icon(Icons.nightlight_round,
                color: Colors.white, size: 26),
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
              final updated = value
                  ? special.copyWith(ramadanModeEnabled: value, suhoorEndTime: null, iftarTime: null)
                  : special.copyWith(ramadanModeEnabled: value);
              await provider.updateSpecialTimes(updated);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialTimesEditor(PrayerTimesProvider provider) {
    final special = provider.prayerSettings?.specialTimes ?? const SpecialTimes();
    return _buildRamadanSection(provider, special);
  }

  Widget _buildRamadanSection(
      PrayerTimesProvider provider, SpecialTimes special) {
    return Consumer<PrayerTimesProvider>(
      builder: (context, provider, _) {
        final special = provider.prayerSettings?.specialTimes ?? const SpecialTimes();
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
                      final updated = value
                          ? special.copyWith(ramadanModeEnabled: value, suhoorEndTime: null, iftarTime: null)
                          : special.copyWith(ramadanModeEnabled: value);
                      await provider.updateSpecialTimes(updated);
                    },
                  ),
                ],
              ),
              if (special.ramadanModeEnabled) ...[
                const SizedBox(height: 20),
                // Toggle between Manual and Calculated times
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Source',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final updated = special.copyWith(useManualRamadanTimes: false);
                                await provider.updateSpecialTimes(updated);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: !special.useManualRamadanTimes 
                                      ? const Color(0xFF1E3A5F) 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calculate,
                                      size: 18,
                                      color: !special.useManualRamadanTimes 
                                          ? Colors.white 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Calculated',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: !special.useManualRamadanTimes 
                                            ? Colors.white 
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final updated = special.copyWith(useManualRamadanTimes: true);
                                await provider.updateSpecialTimes(updated);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: special.useManualRamadanTimes 
                                      ? const Color(0xFF1E3A5F) 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: special.useManualRamadanTimes 
                                          ? Colors.white 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Manual',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: special.useManualRamadanTimes 
                                            ? Colors.white 
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        special.useManualRamadanTimes 
                            ? 'Enter Suhoor and Iftar times manually below'
                            : 'Suhoor = Fajr + Imsak offset, Iftar = Maghrib + Iftar offset',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      if (!special.useManualRamadanTimes) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Suhoor Ends',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AdminTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (_calculateSuhoorEndTime(provider, special) ?? special.suhoorEndTime) ?? 'Choose suhur and iftar timings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Iftar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AdminTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (_calculateIftarTime(provider, special) ?? special.iftarTime) ?? 'Choose suhur and iftar timings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepOrange[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final computedSuhoor = _calculateSuhoorEndTime(provider, special);
                              final computedIftar = _calculateIftarTime(provider, special);

                              if ((computedSuhoor == null || computedSuhoor.isEmpty) &&
                                  (computedIftar == null || computedIftar.isEmpty)) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Could not compute Ramadan times (missing prayer times).'),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              final updated = special.copyWith(
                                suhoorEndTime: computedSuhoor ?? special.suhoorEndTime,
                                iftarTime: computedIftar ?? special.iftarTime,
                                useManualRamadanTimes: false,
                              );

                              await provider.updateSpecialTimes(updated);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Calculated Ramadan times saved — TV will update shortly.'),
                                  backgroundColor: AdminTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.save, size: 18),
                            label: const Text('Save Calculated Ramadan Times', style: TextStyle(fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Manual time inputs (only shown when manual mode is selected)
                if (special.useManualRamadanTimes) ...[
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
                        if (!context.mounted) return;
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
            ],
          ),
        );
      },
    );
    // Removed stray duplicated code
  }
  Widget _buildOverridesEditor(PrayerTimesProvider provider) {
    final settings = provider.prayerSettings;
    if (settings == null) return const SizedBox.shrink();

    final overrides =
        Map<String, PrayerTimeOverride>.from(settings.prayerTimeOverrides);
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
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminTheme.textPrimary),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.textPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
                            colors: [
                              AdminTheme.primaryBlueLight,
                              AdminTheme.primaryBlue
                            ],
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
                        color: _selectedTab == 0
                            ? Colors.white
                            : Colors.grey.shade700,
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
                            colors: [
                              AdminTheme.primaryBlueLight,
                              AdminTheme.primaryBlue
                            ],
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
                        color: _selectedTab == 1
                            ? Colors.white
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
                        // (moved) Save button appears directly in Calculated block below
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
                    ...provider.prayerSettings!.prayerTimes.entries
                        .map((entry) {
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
                                            color: _getPrayerColor(prayer)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                        hintStyle: TextStyle(
                                            color: Colors.grey.shade400),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color:
                                                  AdminTheme.primaryBlueLight,
                                              width: 2),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
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

                      final updatedPrayerTimes =
                          Map<String, PrayerTime>.from(settings.prayerTimes);
                      for (final prayer in settings.prayerTimes.keys) {
                        final ctrl = _adhanControllers[prayer];
                        if (ctrl == null) continue;
                        final existing = updatedPrayerTimes[prayer];
                        if (existing == null) continue;
                        updatedPrayerTimes[prayer] =
                            existing.copyWith(adhan: ctrl.text.trim());
                      }

                      await provider.savePrayerTimesBulk(
                        prayerTimes: updatedPrayerTimes,
                        iqamahUseDelay: Map<String, bool>.from(settings.iqamahUseDelay),
                      ); // FIX: Replace with savePrayerTimes if that's the correct method

                      // Try calling savePrayerTimes instead if savePrayerTimesBulk does not exist
                      // await provider.savePrayerTimes(prayerTimes: updatedPrayerTimes, iqamahUseDelay: Map<String, bool>.from(settings.iqamahUseDelay));

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
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
                      children: provider.prayerSettings!.prayerTimes.entries
                          .map((entry) {
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
                                        color: _getPrayerColor(prayer)
                                            .withOpacity(0.1),
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
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => setState(() =>
                                                _useDelayControllers[prayer] =
                                                    true),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              bottomLeft: Radius.circular(12),
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                              decoration: BoxDecoration(
                                                color: useDelay
                                                    ? AdminTheme
                                                        .primaryBlueLight
                                                        .withOpacity(0.1)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                  bottomLeft:
                                                      Radius.circular(12),
                                                ),
                                                border: Border.all(
                                                  color: useDelay
                                                      ? AdminTheme
                                                          .primaryBlueLight
                                                          .withOpacity(0.3)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Delay after Adhan',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: useDelay
                                                        ? AdminTheme
                                                            .primaryBlueLight
                                                        : Colors.grey.shade600,
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
                                            onTap: () => setState(() =>
                                                _useDelayControllers[prayer] =
                                                    false),
                                            borderRadius:
                                                const BorderRadius.only(
                                              topRight: Radius.circular(12),
                                              bottomRight: Radius.circular(12),
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 14),
                                              decoration: BoxDecoration(
                                                color: !useDelay
                                                    ? AdminTheme.primaryBlue
                                                        .withOpacity(0.1)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topRight: Radius.circular(12),
                                                  bottomRight:
                                                      Radius.circular(12),
                                                ),
                                                border: Border.all(
                                                  color: !useDelay
                                                      ? AdminTheme.primaryBlue
                                                          .withOpacity(0.3)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Fixed Time',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: !useDelay
                                                        ? AdminTheme.primaryBlue
                                                        : Colors.grey.shade600,
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
                                  controller: useDelay
                                      ? _delayControllers[prayer]
                                      : _iqamahControllers[prayer],
                                  keyboardType: useDelay
                                      ? TextInputType.number
                                      : TextInputType.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: AdminTheme.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: useDelay
                                        ? 'Delay after Adhan'
                                        : 'Iqamah Time',
                                    hintText:
                                        useDelay ? 'Enter minutes' : 'HH:MM',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AdminTheme.primaryBlueLight,
                                          width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                    suffixIcon: Icon(
                                      useDelay
                                          ? Icons.timer_outlined
                                          : Icons.schedule,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AdminTheme.textPrimary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final settings = provider.prayerSettings;
                      if (settings == null) return;

                      final updatedPrayerTimes =
                          Map<String, PrayerTime>.from(settings.prayerTimes);
                      final updatedUseDelay = <String, bool>{};

                      for (final prayer in settings.prayerTimes.keys) {
                        final useDelay = _useDelayControllers[prayer] ??
                            (settings.iqamahUseDelay[prayer] ?? true);
                        updatedUseDelay[prayer] = useDelay;

                        final existing = updatedPrayerTimes[prayer];
                        if (existing == null) continue;

                        if (useDelay) {
                          final delayCtrl = _delayControllers[prayer];
                          final delayMinutes =
                              int.tryParse(delayCtrl?.text.trim() ?? '');
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
                          content:
                              const Text('Iqamah times saved successfully'),
                          backgroundColor: AdminTheme.accentEmerald,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryBlueLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
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
              value:
                  provider.prayerSettings?.calculationSettings.method ?? 'MWL',
              options: const [
                DropdownMenuItem(
                    value: 'MWL', child: Text('Muslim World League')),
                DropdownMenuItem(
                    value: 'ISNA',
                    child: Text('Islamic Society of North America')),
                DropdownMenuItem(
                    value: 'Egypt', child: Text('Egyptian General Authority')),
                DropdownMenuItem(
                    value: 'Makkah',
                    child: Text('Umm al-Qura University, Makkah')),
                DropdownMenuItem(
                    value: 'Karachi',
                    child: Text('University of Islamic Sciences, Karachi')),
                DropdownMenuItem(value: 'Custom', child: Text('Custom Method')),
              ],
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider
                      .prayerSettings!.calculationSettings
                      .copyWith(method: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
            ),

            const SizedBox(height: 24),

            // Asr Method
            _buildDropdownSetting(
              title: 'Asr Calculation Method',
              value: provider.prayerSettings?.calculationSettings.asrMethod ??
                  'Shafi',
              options: ['Shafi', 'Hanafi'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider
                      .prayerSettings!.calculationSettings
                      .copyWith(asrMethod: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
            ),

            const SizedBox(height: 24),

            // High Latitude Rule
            _buildDropdownSetting(
              title: 'High Latitude Rule',
              value: provider
                      .prayerSettings?.calculationSettings.highLatitudeRule ??
                  'AngleBased',
              options: const [
                DropdownMenuItem(value: 'Midnight', child: Text('Midnight')),
                DropdownMenuItem(
                    value: 'OneSeventh', child: Text('One Seventh')),
                DropdownMenuItem(
                    value: 'AngleBased', child: Text('Angle Based')),
              ],
              onChanged: (value) async {
                if (value != null && provider.prayerSettings != null) {
                  final newSettings = provider
                      .prayerSettings!.calculationSettings
                      .copyWith(highLatitudeRule: value);
                  await provider.updateCalculationSettings(newSettings);
                }
              },
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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

  Color _getPrayerColor(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return AdminTheme.primaryBlue;
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

// Separate StatefulWidget for Athan Automatic section to properly manage state
class _AthanAutomaticSection extends StatefulWidget {
  final PrayerTimesProvider provider;

  const _AthanAutomaticSection({required this.provider});

  @override
  State<_AthanAutomaticSection> createState() => _AthanAutomaticSectionState();
}

class _AthanAutomaticSectionState extends State<_AthanAutomaticSection> {
  _AthanAutomaticSectionState();
  late String selectedMethod;
  late String selectedAsr;
  late String selectedHighLat;

  @override
  void initState() {
    super.initState();
    final current = widget.provider.prayerSettings?.calculationSettings ?? CalculationSettings();
    selectedMethod = current.method;
    selectedAsr = current.asrMethod;
    selectedHighLat = current.highLatitudeRule;
  }

  Future<void> _updateLocationAndCalculate(LocationSettings newLocation) async {
    try {
      await widget.provider.updateLocationSettings(newLocation);
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.provider.prayerSettings?.calculationSettings ?? CalculationSettings();
    final methods = PrayerApiService.getCalculationMethods();
    final asrOptions = const ['Shafi', 'Hanafi'];
    final highLatOptions = const ['AngleBased', 'Midnight', 'OneSeventh'];

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
          child: LocationPickerWidget(
            location: widget.provider.prayerSettings?.location ?? LocationSettings(country: '', city: '', latitude: 0.0, longitude: 0.0),
            onLocationChanged: (newLocation) async {
              await _updateLocationAndCalculate(newLocation);
            },
            onLocationResolved: () async {
              // Recalculate after location is resolved
              final location = widget.provider.prayerSettings?.location;
              if (location != null &&
                  ((location.city.isNotEmpty && location.country.isNotEmpty) ||
                      (location.latitude != 0.0 && location.longitude != 0.0))) {
                await widget.provider.calculatePrayerTimes();
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.provider.isCalculating
                    ? null
                    : () async {
                        final newSettings = current.copyWith(
                          method: selectedMethod,
                          asrMethod: selectedAsr,
                          highLatitudeRule: selectedHighLat,
                          useAutoCalculation: true,
                        );
                        await widget.provider.updateCalculationSettings(newSettings);

                        final location = widget.provider.prayerSettings?.location;
                        if (location != null &&
                            ((location.city.isNotEmpty &&
                                    location.country.isNotEmpty) ||
                                (location.latitude != 0.0 &&
                                    location.longitude != 0.0))) {
                          await widget.provider.calculatePrayerTimes();
                        }

                        if (!mounted) return;
                        if (widget.provider.errorMessage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Prayer times calculated and saved!'),
                              backgroundColor: AdminTheme.accentEmerald,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: widget.provider.isCalculating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Calculate & Save Prayer Times',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
