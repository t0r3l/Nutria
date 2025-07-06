import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';

class GoogleFitService {
  static const String _fitScope = 'https://www.googleapis.com/auth/fitness.activity.read';
  static const String _fitWriteScope = 'https://www.googleapis.com/auth/fitness.activity.write';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      _fitScope,
      _fitWriteScope,
      'https://www.googleapis.com/auth/fitness.body.read',
      'https://www.googleapis.com/auth/fitness.location.read',
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication auth = await account.authentication;
        safePrint('Google Sign-In successful for: ${account.email}');
        safePrint('Access token length: ${auth.accessToken?.length}');
        return true;
      }
      return false;
    } catch (error) {
      safePrint('Google sign-in error: $error');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      safePrint('Google Sign-Out successful');
    } catch (error) {
      safePrint('Google sign-out error: $error');
    }
  }

  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  Future<Map<String, dynamic>?> getFitnessData() async {
    if (!await _googleSignIn.isSignedIn()) {
      safePrint('Not signed in to Google, attempting sign in...');
      if (!await signInWithGoogle()) {
        safePrint('Failed to sign in to Google');
        return null;
      }
    }

    final account = _googleSignIn.currentUser;
    if (account == null) {
      safePrint('No Google account found');
      return null;
    }

    try {
      final auth = await account.authentication;
      final token = auth.accessToken;

      if (token == null) {
        safePrint('No access token available');
        return null;
      }

      // Get step count data for the last 7 days
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final startTime = endTime - (7 * 24 * 60 * 60 * 1000); // 7 days ago

      final aggregateRequest = {
        "aggregateBy": [
          {
            "dataTypeName": "com.google.step_count.delta",
            "dataSourceId": "derived:com.google.step_count.delta:com.google.android.gms:estimated_steps"
          }
        ],
        "bucketByTime": {"durationMillis": 86400000}, // 1 day buckets
        "startTimeMillis": startTime,
        "endTimeMillis": endTime
      };

      final response = await http.post(
        Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(aggregateRequest),
      );

      safePrint('Fitness API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        safePrint('Successfully retrieved fitness data');
        return _processStepData(data);
      } else {
        safePrint('Fitness API error: ${response.statusCode} - ${response.body}');
        return {
          'error': 'API Error ${response.statusCode}',
          'message': response.body
        };
      }
    } catch (e) {
      safePrint('Error getting fitness data: $e');
      return {
        'error': 'Exception',
        'message': e.toString()
      };
    }
  }

  Map<String, dynamic> _processStepData(Map<String, dynamic> rawData) {
    try {
      final buckets = rawData['bucket'] as List<dynamic>? ?? [];
      final processedData = <String, dynamic>{
        'totalSteps': 0,
        'dailySteps': <Map<String, dynamic>>[],
        'period': '7 days',
        'dataPoints': buckets.length,
      };

      int totalSteps = 0;

      for (final bucket in buckets) {
        final datasets = bucket['dataset'] as List<dynamic>? ?? [];
        int dailySteps = 0;
        String date = '';

        // Extract date from bucket
        final startTime = bucket['startTimeMillis'];
        if (startTime != null) {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(
              int.parse(startTime.toString())
          );
          date = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
        }

        // Extract step count from datasets
        for (final dataset in datasets) {
          final points = dataset['point'] as List<dynamic>? ?? [];
          for (final point in points) {
            final values = point['value'] as List<dynamic>? ?? [];
            for (final value in values) {
              final stepCount = value['intVal'];
              if (stepCount != null) {
                dailySteps += int.parse(stepCount.toString());
              }
            }
          }
        }

        totalSteps += dailySteps;

        if (date.isNotEmpty) {
          (processedData['dailySteps'] as List).add({
            'date': date,
            'steps': dailySteps,
          });
        }
      }

      processedData['totalSteps'] = totalSteps;
      processedData['averageSteps'] = buckets.isNotEmpty ? (totalSteps / buckets.length).round() : 0;

      return processedData;
    } catch (e) {
      safePrint('Error processing step data: $e');
      return {
        'error': 'Processing Error',
        'message': e.toString(),
        'rawData': rawData,
      };
    }
  }

  // Get current user info
  Future<Map<String, dynamic>?> getUserInfo() async {
    final account = _googleSignIn.currentUser;
    if (account == null) return null;

    return {
      'email': account.email,
      'displayName': account.displayName,
      'photoUrl': account.photoUrl,
      'id': account.id,
    };
  }
}