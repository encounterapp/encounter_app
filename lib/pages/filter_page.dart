import 'package:flutter/material.dart';
import 'package:encounter_app/utils/location_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});

  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  double _distance = 5.0; // Default distance in miles - maximum is 5.0
  RangeValues _ageRange = const RangeValues(18, 60); // Default age range
  String _selectedGender = "Everyone"; // Default gender selection
  bool _locationEnabled = false; // Track if location is enabled

  final List<String> _genderOptions = ["Female", "Male", "Other", "Everyone"];
  final LocationManager _locationManager = LocationManager();

  @override
  void initState() {
    super.initState();
    _loadFilterPreferences().then((_) {
      _checkLocationStatus();
    });
  }

  // Check if location services are available
  Future<void> _checkLocationStatus() async {
    final bool locationInitialized = await _locationManager.initialize();
    if (mounted) {
      setState(() {
        _locationEnabled = locationInitialized;
      });
    }
  }

  /// Loads filter preferences from SharedPreferences
  Future<void> _loadFilterPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // Only enable location filter on the main feed (not on user profiles)
      _locationEnabled = prefs.getBool('location_filter_enabled') ?? true;
      
      // Load distance but cap it at 5 miles and ensure it's at least 0.1 miles
      final savedDistance = prefs.getDouble('filter_distance') ?? 5.0;
      _distance = savedDistance > 5.0 ? 5.0 : (savedDistance < 0.1 ? 0.1 : savedDistance);
      // Round to nearest 0.1 to ensure consistency
      _distance = (_distance * 10).round() / 10;
      
      _ageRange = RangeValues(
        prefs.getDouble('filter_age_min') ?? 18,
        prefs.getDouble('filter_age_max') ?? 60,
      );
      
      // Load gender selection
      _selectedGender = prefs.getString('filter_gender') ?? "Everyone";
    });
  }

  // Save filter preferences
  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('filter_distance', _distance);
    await prefs.setDouble('filter_age_min', _ageRange.start);
    await prefs.setDouble('filter_age_max', _ageRange.end);
    await prefs.setString('filter_gender', _selectedGender);
    await prefs.setBool('location_filter_enabled', _locationEnabled);
  }

  void _applyFilters() async {
    await _saveFilters();
    Navigator.pop(context, {
      'distance': _distance,
      'ageRange': _ageRange,
      'gender': _selectedGender,
      'locationEnabled': _locationEnabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F6), // Light gray background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Filter', style: TextStyle(color: Colors.black, fontSize: 20)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Distance Section
            Row(
              children: [
                const Text("Distance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (!_locationEnabled)
                  Tooltip(
                    message: "Enable location to use distance filtering",
                    child: Icon(Icons.info_outline, color: Colors.orange, size: 18),
                  ),
              ],
            ),
            Slider(
              value: _distance,
              min: 0.1, // Changed minimum to 0.1 miles
              max: 5.0, // Maximum is 5 miles
              divisions: 49, // 49 divisions for increments of 0.1 mile (0.1 to 5.0)
              activeColor: _locationEnabled ? Colors.orange : Colors.grey,
              inactiveColor: Colors.white,
              onChanged: _locationEnabled 
                ? (value) {
                    setState(() {
                      // Round to nearest 0.1 to avoid floating point issues
                      _distance = (value * 10).round() / 10;
                    });
                  }
                : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${_distance.toStringAsFixed(1)} Miles", 
                  style: TextStyle(fontSize: 16, color: _locationEnabled ? Colors.black : Colors.grey)),
                if (!_locationEnabled)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.location_on, size: 16),
                    label: const Text("Enable Location"),
                    onPressed: () async {
                      final initialized = await _locationManager.initialize();
                      if (mounted) {
                        setState(() {
                          _locationEnabled = initialized;
                        });
                        
                        if (!initialized) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Location services are not available"))
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Text("Age", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            RangeSlider(
              values: _ageRange,
              min: 18,
              max: 100,
              divisions: 82,
              activeColor: Colors.orange,
              inactiveColor: Colors.white,
              onChanged: (values) {
                setState(() {
                  _ageRange = values;
                });
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text("${_ageRange.start.toInt()} - ${_ageRange.end.toInt()}", style: const TextStyle(fontSize: 16)),
            ),

            const SizedBox(height: 20),
            const Text("Gender", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10, // horizontal space between chips
              runSpacing: 10, // vertical space between lines
              alignment: WrapAlignment.start,
              children: _genderOptions.map((gender) {
                return ChoiceChip(
                  label: Text(gender),
                  selected: _selectedGender == gender,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _selectedGender = gender;
                      });
                    }
                  },
                  selectedColor: Colors.orange,
                  backgroundColor: Colors.grey[300],
                  labelStyle: TextStyle(
                    color: _selectedGender == gender ? Colors.white : Colors.black,
                  ),
                );
              }).toList(),
            ),

            const Spacer(), // Push the save button to the bottom
            ElevatedButton(
              onPressed: _applyFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Save", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}