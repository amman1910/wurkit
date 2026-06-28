import 'dart:async';

import 'package:flutter/material.dart';

import '../models/address_suggestion.dart';
import '../models/resolved_address.dart';
import '../services/google_places_service.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.onAddressChanged,
    this.initialAddress,
    this.enabled = true,
    this.decoration,
  });

  final TextEditingController controller;
  final ValueChanged<ResolvedAddress?> onAddressChanged;
  final ResolvedAddress? initialAddress;
  final bool enabled;
  final InputDecoration? decoration;

  @override
  State<AddressAutocompleteField> createState() =>
      AddressAutocompleteFieldState();
}

class AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _service = GooglePlacesService();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  ResolvedAddress? _selected;
  bool _loading = false;
  String? _error;
  bool _internalTextChange = false;

  bool get hasValidSelection => _selected != null;
  ResolvedAddress? get selectedAddress => _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialAddress;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
    if (widget.initialAddress != oldWidget.initialAddress &&
        _selected == null) {
      _selected = widget.initialAddress;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_internalTextChange) return;
    if (_selected != null) {
      _selected = null;
      widget.onAddressChanged(null);
    }
    _debounce?.cancel();
    final input = widget.controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _suggestions = const [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(input));
  }

  Future<void> _search(String input) async {
    if (!mounted || input != widget.controller.text.trim()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _service.fetchAddressSuggestions(input);
      if (!mounted || input != widget.controller.text.trim()) return;
      setState(() => _suggestions = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(AddressSuggestion suggestion) async {
    setState(() {
      _loading = true;
      _suggestions = const [];
      _error = null;
    });
    try {
      final address = await _service.fetchPlaceDetails(suggestion.placeId);
      if (!mounted) return;
      _internalTextChange = true;
      widget.controller.text = address.formattedAddress;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
      _internalTextChange = false;
      setState(() => _selected = address);
      widget.onAddressChanged(address);
      _focusNode.unfocus();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          decoration:
              (widget.decoration ?? const InputDecoration(labelText: 'Address'))
                  .copyWith(
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _selected == null
                        ? null
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
        ),
        if (_suggestions.isNotEmpty)
          Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(suggestion.mainText),
                  subtitle: suggestion.secondaryText.isEmpty
                      ? null
                      : Text(suggestion.secondaryText),
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
