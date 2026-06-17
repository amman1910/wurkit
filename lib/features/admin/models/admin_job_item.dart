import 'package:cloud_firestore/cloud_firestore.dart';

class AdminJobItem {
  const AdminJobItem({
    required this.jobId,
    required this.title,
    required this.category,
    required this.employerName,
    required this.location,
    required this.wage,
    required this.status,
    required this.createdAt,
  });

  final String jobId;
  final String title;
  final String category;
  final String employerName;
  final String location;
  final String wage;
  final String status;
  final DateTime? createdAt;

  factory AdminJobItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdRaw = data['createdAt'];

    return AdminJobItem(
      jobId: doc.id,
      title: _stringFrom(data['title'], fallback: 'Untitled job'),
      category: _stringFrom(data['category']),
      employerName: _stringFrom(
        data['employerName'],
        fallback: _stringFrom(data['businessName']),
      ),
      location: _locationText(data['location']),
      wage: _wageText(data),
      status: _stringFrom(data['status'], fallback: 'open').toLowerCase(),
      createdAt: createdRaw is Timestamp ? createdRaw.toDate() : null,
    );
  }

  static String _stringFrom(dynamic value, {String fallback = '-'}) {
    if (value == null) return fallback;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();
      for (final key in const ['name', 'title', 'value']) {
        final nested = _stringFrom(map[key], fallback: '');
        if (nested.isNotEmpty) return nested;
      }
      return fallback;
    }
    return fallback;
  }

  static String _locationText(dynamic value) {
    if (value == null) return '-';
    if (value is String || value is num || value is bool) {
      return _stringFrom(value);
    }
    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();
      final address = _stringFrom(map['address'], fallback: '');
      final city = _stringFrom(map['city'], fallback: '');
      final name = _stringFrom(map['name'], fallback: '');

      if (address.isNotEmpty && city.isNotEmpty) return '$address, $city';
      if (address.isNotEmpty) return address;
      if (city.isNotEmpty) return city;
      if (name.isNotEmpty) return name;

      for (final key in const ['label', 'text']) {
        final fallback = _stringFrom(map[key], fallback: '');
        if (fallback.isNotEmpty) return fallback;
      }
    }
    return '-';
  }

  static String _wageText(Map<String, dynamic> data) {
    String currencyValue(num amount) {
      final formatted = amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
      return '\$$formatted';
    }

    final salaryType = _stringFrom(data['salaryType'], fallback: '');

    final salary = data['salary'];
    if (salary is num) {
      final base = currencyValue(salary);
      return salaryType.isEmpty ? base : '$base $salaryType';
    }

    final hourlyRate = data['hourlyRate'];
    if (hourlyRate is num) {
      final base = '${currencyValue(hourlyRate)}/hr';
      return salaryType.isEmpty ? base : '$base $salaryType';
    }

    final wage = data['wage'];
    if (wage is String || wage is num) {
      return _stringFrom(wage);
    }
    if (wage is Map) {
      final map = wage.cast<dynamic, dynamic>();
      final amount = map['amount'];
      if (amount is num) {
        final base = currencyValue(amount);
        final period = _stringFrom(
          map['period'],
          fallback: _stringFrom(map['type'], fallback: ''),
        );
        return period.isEmpty ? base : '$base $period';
      }
      final text = _stringFrom(
        map['text'],
        fallback: _stringFrom(map['value'], fallback: ''),
      );
      if (text.isNotEmpty) return text;
    }

    final payment = data['payment'];
    if (payment is String || payment is num) {
      return _stringFrom(payment);
    }
    if (payment is Map) {
      final map = payment.cast<dynamic, dynamic>();
      final amount = map['amount'];
      if (amount is num) {
        final base = currencyValue(amount);
        final period = _stringFrom(
          map['type'],
          fallback: _stringFrom(map['period'], fallback: ''),
        );
        return period.isEmpty ? base : '$base $period';
      }
      final text = _stringFrom(
        map['label'],
        fallback: _stringFrom(map['name'], fallback: ''),
      );
      if (text.isNotEmpty) return text;
    }

    return '-';
  }
}
