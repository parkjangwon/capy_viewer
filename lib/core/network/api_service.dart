import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';
import '../errors/failures.dart';

class ApiService {
  final http.Client client;

  ApiService({required this.client});

  Future<dynamic> get(String url) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': ApiConstants.userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ServerException();
      }
    } catch (e) {
      throw ServerFailure();
    }
  }
} 