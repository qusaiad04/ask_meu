import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Map<String, List<String>> _buildingData = {
    'B': ['Basement', '1'],
    'H': ['1', '2'],
    'N': ['1', '3'],
  };

  String _selectedBuilding = 'B';
  String _selectedFloor = 'Basement';

  Widget _dropdownSection(String label, String sublabel, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(sublabel, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(8)),
          child: DropdownButton<String>(
            value: value,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF2C2C2C),
            icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF888888), size: 20),
            isDense: true,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String imagePath = 'assets/images/map_${_selectedBuilding}_$_selectedFloor.jpg';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdownSection('Building', 'Select the building', _selectedBuilding, _buildingData.keys.toList(), (v) {
                  if (v != null) {
                    setState(() {
                      _selectedBuilding = v;
                      _selectedFloor = _buildingData[v]!.first;
                    });
                  }
                }),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _dropdownSection('Floor', 'Select the floor', _selectedFloor, _buildingData[_selectedBuilding]!, (v) {
                  if (v != null) setState(() => _selectedFloor = v);
                }),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F0), borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text('Missing Image:\n$imagePath', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Building $_selectedBuilding  |  Floor $_selectedFloor',
                        style: const TextStyle(color: Color(0xFF555555), fontSize: 10, fontWeight: FontWeight.bold),
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