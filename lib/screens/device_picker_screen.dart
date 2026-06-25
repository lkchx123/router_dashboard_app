import 'package:flutter/material.dart';
import '../models/device.dart';

class DevicePickerScreen extends StatefulWidget {
  final String title;
  final List<Device> devices;
  final bool multi;
  final Set<String> selected;

  const DevicePickerScreen({
    super.key,
    required this.title,
    required this.devices,
    required this.multi,
    required this.selected,
  });

  @override
  State<DevicePickerScreen> createState() => _DevicePickerScreenState();
}

class _DevicePickerScreenState extends State<DevicePickerScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              if (widget.multi) {
                Navigator.pop(context, _selected);
              } else {
                Navigator.pop(context, _selected.isEmpty ? '' : _selected.first);
              }
            },
            child: const Text('完成'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.devices.length,
        itemBuilder: (ctx, i) {
          final d = widget.devices[i];
          final checked = _selected.contains(d.mac);
          return CheckboxListTile(
            value: checked,
            title: Text(d.rawDisplayName),
            subtitle: Text('${d.mac} · ${d.active ? "在线" : "离线"}'),
            onChanged: (v) {
              setState(() {
                if (!widget.multi) _selected.clear();
                if (v == true) {
                  _selected.add(d.mac);
                } else {
                  _selected.remove(d.mac);
                }
              });
            },
          );
        },
      ),
    );
  }
}
