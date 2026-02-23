import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const String clientId = '1000.2LT7BBRRUJLNOMHMQ3HZD1JZM757VL';
  const String clientSecret = '8484f7736bb49ff0e7c80fa719baf300ff0cd0e283';
  const String refreshToken = '1000.0c1da5acbbef2a1171fb36b5364b6cbc.8b2f9fed3eac0d03652e1006d72e0cdf';
  const String reportName = 'State_District_Mandal_Village_Report';

  final authResponse = await http.post(Uri.parse('https://accounts.zoho.in/oauth/v2/token'), body: {
    'client_id': clientId, 'client_secret': clientSecret, 'refresh_token': refreshToken, 'grant_type': 'refresh_token',
  });
  final accessToken = jsonDecode(authResponse.body)['access_token'];

  print('Fetching data...');
  
  final response = await http.get(
    Uri.parse('https://www.zohoapis.in/creator/v2.1/data/shareindia/share-india/report/$reportName?limit=10'),
    headers: {'Authorization': 'Zoho-oauthtoken $accessToken'},
  );

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'] ?? [];
    for (var i = 0; i < data.length; i++) {
       print('\n--- RECORD ${i+1} ---');
       print(JsonEncoder.withIndent('  ').convert(data[i]));
    }
  } else {
    print('Error: ${response.body}');
  }
}
