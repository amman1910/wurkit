import 'package:flutter_test/flutter_test.dart';
import 'package:wurkit/shared/utils/address_format_utils.dart';

void main() {
  test('removes an English Israel suffix', () {
    expect(
      formatAddressForDisplay('HaBossem St 2, Abu Ghosh, Israel'),
      'HaBossem St 2, Abu Ghosh',
    );
  });

  test('removes a Hebrew Israel suffix', () {
    expect(
      formatAddressForDisplay('רחוב השלום 2, אבו גוש, ישראל'),
      'רחוב השלום 2, אבו גוש',
    );
  });

  test('keeps locality and street details intact', () {
    expect(
      formatAddressForDisplay('Village Road 4, Regional Council'),
      'Village Road 4, Regional Council',
    );
  });
}
