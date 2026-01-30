import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ZohoCreatorService {
  static final ZohoCreatorService _instance = ZohoCreatorService._internal();
  factory ZohoCreatorService() => _instance;
  ZohoCreatorService._internal();

  static const String clientId = '1000.2LT7BBRRUJLNOMHMQ3HZD1JZM757VL';
  static const String clientSecret =
      '8484f7736bb49ff0e7c80fa719baf300ff0cd0e283';
  static const String refreshToken =
      '1000.0c1da5acbbef2a1171fb36b5364b6cbc.8b2f9fed3eac0d03652e1006d72e0cdf';

  static const String accountOwner = 'shareindia';
  static const String appLinkName = 'share-india';
  static const String formLinkName = 'Family_Code_Creation';
  static const String reportLinkName = 'All_Family_Code_Creation';
  static const String submitUrl =
      'https://www.zohoapis.in/creator/v2.1/data/$accountOwner/$appLinkName/form/$formLinkName';
  static const String fetchUrl =
      'https://www.zohoapis.in/creator/v2.1/data/$accountOwner/$appLinkName/report/$reportLinkName';
  static const String authUrl = 'https://accounts.zoho.in/oauth/v2/token';
  
  // Location ID Mapping
  static const Map<String, String> _locationMap = {
    "Telangana": "326338000000022013",
    "Medchal-Malkajgiri": "326338000000050005",
    "Medchal": "326338000000050009",
    "Yellampet": "326338000000052163",
    "Yadaram": "326338000000052159",
    "Shazadiguda": "326338000000052155",
    "Srirangavaram": "326338000000052151",
    "Somaram": "326338000000052147",
    "Suthariguda": "326338000000052143",
    "Ravalkole": "326338000000052139",
    "Ravalkole Thanda": "326338000000052135",
    "Railapur": "326338000000052131",
    "Rajbollaram": "326338000000052127",
    "Rajbollaram Thanda": "326338000000052123",
    "Pudur": "326338000000052119",
    "Nuthankol": "326338000000052115",
    "Muneerabad": "326338000000052111",
    "Maisereddypally": "326338000000052107",
    "Muraharipally": "326338000000052103",
    "Maisamma Gudam": "326338000000052099",
    "MediCiti": "326338000000052095",
    "Lethamamidi Thanda": "326338000000052091",
    "Lingapur": "326338000000052087",
    "Kasimbai Thanda": "326338000000052083",
    "Konahipally": "326338000000052079",
    "Kandla Koyya": "326338000000052075",
    "Kistapur": "326338000000052071",
    "Gyanapur": "326338000000052067",
    "Gubbari Thanda": "326338000000052063",
    "Gosaiguda": "326338000000052059",
    "Girmapur": "326338000000052055",
    "Gundla Pochampally": "326338000000052051",
    "Ghanpur": "326338000000052047",
    "Ghanpur Thanda": "326338000000052043",
    "Gowdavelly": "326338000000052039",
    "Guddamgadda Thanda": "326338000000052035",
    "Dabilpur": "326338000000052031",
    "Dongalgutta Thanda": "326338000000052027",
    "Basaragadi": "326338000000052023",
    "Bandamadaram": "326338000000052019",
    "Barmajigudam": "326338000000052015",
    "Akberjapet": "326338000000052007",
    "Arkalaguda": "326338000000052003",
    "Athvelly": "326338000000051011"
  };

  String? _accessToken;
  DateTime? _tokenExpiry;
  Future<String?>? _pendingRefresh;

  Future<String?> _getAccessToken() async {
    // Check if current token is still valid
    if (_accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      debugPrint('ZOHO: Refreshing access token...');
      
      final response = await http.post(
        Uri.parse(authUrl),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['access_token'] != null) {
        _accessToken = data['access_token'];
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        debugPrint('ZOHO: Access token refreshed successfully');
        return _accessToken;
      } else {
        debugPrint('ZOHO: Token refresh failed. Status: ${response.statusCode}');
        debugPrint('ZOHO: Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ZOHO: Error refreshing token: $e');
      return null;
    }
  }

  Future<bool> syncRecord(Map<String, dynamic> firestoreData) async {
    final familyId = firestoreData['family_id'];
    debugPrint('ZOHO: syncRecord started for $familyId');
    
    final accessToken = await _getAccessToken();
    debugPrint('ZOHO: Token check for $familyId: accessToken is ${accessToken == null ? 'NULL' : 'OK'}');
    
    if (accessToken == null) {
      debugPrint('ZOHO: Sync aborted for $familyId - no access token');
      return false;
    }

    try {
      debugPrint('ZOHO: Mapping data for $familyId...');
      // Map Firestore data to Zoho Creator fields
      final zohoData = {
        'data': {
          'Family_ID': firestoreData['family_id']?.toString() ?? '',
          'State': _locationMap[firestoreData['state']] ?? firestoreData['state']?.toString() ?? '',
          'District1': _locationMap[firestoreData['district']] ?? firestoreData['district']?.toString() ?? '',
          'Mandal1': _locationMap[firestoreData['mandal']] ?? firestoreData['mandal']?.toString() ?? '',
          'Village1': _locationMap[firestoreData['village']] ?? firestoreData['village']?.toString() ?? '',
          'House_No': firestoreData['house_no']?.toString() ?? '',
          'Head_of_the_family': firestoreData['head_of_family']?.toString() ?? '',
          'Family_Type': firestoreData['family_type']?.toString() ?? '',
          'Family_Status': firestoreData['family_status']?.toString() ?? '',
          'Do_you_Own_this_house_house': firestoreData['own_house']?.toString() ?? '',
          'No_of_rooms': int.tryParse(firestoreData['no_of_rooms']?.toString() ?? '0') ?? 0,
          'Type_of_House': firestoreData['type_of_house']?.toString() ?? '',
          'Wall': firestoreData['wall_type']?.toString() ?? '',
          'Roof': firestoreData['roof_type']?.toString() ?? '',
          'Floor': firestoreData['floor_type']?.toString() ?? '',
          'Where_do_we_cook': _toList(firestoreData['cooking_location']),
          'If_Others_Please_Mention9': firestoreData['cooking_location_other']?.toString() ?? '',
          'Separate_Room_for_kitchen1': firestoreData['separate_kitchen']?.toString() ?? '',
          'Type_of_fuel_used_for_cooking': _toList(firestoreData['cooking_fuel_types']),
          'If_Others_Please_Mention2': firestoreData['cooking_fuel_other']?.toString() ?? '',
          'Mainly_Used': firestoreData['cooking_fuel_main']?.toString() ?? '',
          'Main_source_of_lighting_in_household': firestoreData['lighting_source']?.toString() ?? '',
          'source_of_water': _toList(firestoreData['water_sources']),
          'If_Others_Please_Mention3': firestoreData['water_source_other']?.toString() ?? '',
          'Mainly_Used1': firestoreData['water_main_source']?.toString() ?? '',
          'Do_to_the_water_to_make_it_safer_to_drink': _toList(firestoreData['water_treatment']),
          'If_Others_Please_Mention5': firestoreData['water_treatment_other']?.toString() ?? '',
          'Source_water_used_for_all_purposes': _toList(firestoreData['water_all_sources']),
          'If_Others_Please_Mention': firestoreData['water_all_other']?.toString() ?? '',
          'What_kind_of_toilet_facility_HH1': firestoreData['toilet_facility']?.toString() ?? '',
          'What_kind_of_toilet_facility_HH1': firestoreData['toilet_facility_other']?.toString() ?? '',
          'Have_ration_card': firestoreData['ration_card']?.toString() ?? '',
          'Religion': firestoreData['religion']?.toString() ?? '',
          'Cast_of_the_head': firestoreData['caste']?.toString() ?? '',
          'Any_agriculture_land': firestoreData['agriculture_land']?.toString() ?? '',
          'Number': firestoreData['agriculture_land_area']?.toString() ?? '',
          'Land_Unit': firestoreData['agriculture_land_unit']?.toString() ?? '',
          'Land_is_irrigated': firestoreData['irrigated_land_area']?.toString() ?? '',
          'Land_Unit1': firestoreData['irrigated_land_unit']?.toString() ?? '',
          'None': firestoreData['irrigated_none'] == true,
          'Own_any_cattle1': _toList(firestoreData['cattle_owned']),
          'If_Others_Please_Mention4': firestoreData['cattle_other']?.toString() ?? '',
          'get_sick_where_do_they_go': firestoreData['health_care_place']?.toString() ?? '',
          'Why_they_dont_go_to_Govt_Hospital': _toList(firestoreData['govt_hospital_reasons']),
          'If_Others_Please_Mention6': firestoreData['govt_hospital_other']?.toString() ?? '',
          ..._mapAssetsToZoho(firestoreData['household_assets'] ?? []),
        }
      };

      debugPrint('ZOHO: Syncing to URL: $submitUrl');
      final bodyString = jsonEncode(zohoData);
      debugPrint('ZOHO: Request Body: $bodyString');

      final response = await http.post(
        Uri.parse(submitUrl),
        headers: {
          'Authorization': 'Zoho-oauthtoken $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(zohoData),
      );

      debugPrint('ZOHO: Response Status: ${response.statusCode}');
      debugPrint('ZOHO: Response Body: ${response.body}');

      final responseBody = jsonDecode(response.body);
      
      if ((response.statusCode == 201 || response.statusCode == 200) && 
          responseBody['code'] == 3000) {
        debugPrint(
            'ZOHO: Record synced successfully: ${firestoreData['family_id']}');
        return true;
      } else {
        final errorMsg = responseBody['message'] ?? 'Unknown error';
        final errorDetails = responseBody['error'] ?? '';
        debugPrint(
            'ZOHO: Failed to sync record $familyId: $errorMsg ($errorDetails)');
        return false;
      }
    } catch (e) {
      debugPrint('ZOHO: Error syncing record $familyId: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecords() async {
    debugPrint('ZOHO: fetchRecords started');
    final accessToken = await _getAccessToken();
    if (accessToken == null) return [];

    try {
      final response = await http.get(
        Uri.parse(fetchUrl),
        headers: {
          'Authorization': 'Zoho-oauthtoken $accessToken',
        },
      ).timeout(const Duration(seconds: 20));

      debugPrint('ZOHO: Fetch Response Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['code'] == 3000 && body['data'] != null) {
          final List<dynamic> zohoList = body['data'];
          return zohoList.map((record) => _mapFromZoho(record)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('ZOHO: Error fetching records: $e');
      return [];
    }
  }

  Map<String, dynamic> _mapFromZoho(Map<String, dynamic> z) {
    return {
      'family_id': _getValue(z['Family_ID']),
      'state': _getNonEmptyValue([z['State_constant'], z['State']]),
      'district': _getNonEmptyValue([z['District_Constant'], z['District1']]),
      'mandal': _getNonEmptyValue([z['Mandal_Constant'], z['Mandal1']]),
      'village': _getNonEmptyValue([z['Village_Constant'], z['Village1']]),
      'house_no': _getValue(z['House_No']),
      'head_of_family': _getValue(z['Head_of_the_family']),
      'family_type': _matchOption(_getValue(z['Family_Type']), ['(1) Nuclear Family', '(0) Joint Family']),
      'family_status': _matchOption(_getNonEmptyValue([z['Family_Status'], z['ACTIVE_ST']]), ['(1) Active', '(0) Vacant']),
      'own_house': _matchOption(_getValue(z['Do_you_Own_this_house_house']), ['(1) Yes', '(2) No']),
      'no_of_rooms': int.tryParse(_getValue(z['No_of_rooms'])) ?? 0,
      'type_of_house': _matchOption(_getValue(z['Type_of_House']), ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']),
      'wall_type': _matchOption(_getNonEmptyValue([z['WALL2'], z['Wall']]), ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']),
      'roof_type': _matchOption(_getNonEmptyValue([z['ROOF1'], z['Roof']]), ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']),
      'floor_type': _matchOption(_getNonEmptyValue([z['FLOOR1'], z['Floor']]), ['(1) PUCCA', '(2) SEMI PUCCA', '(3) KACHHA']),
      'cooking_location': _matchOption(_getValue(z['Where_do_we_cook']), ['(1) In the House', '(2) In a seperate Building', '(3) Outdoors', '(4) Other']),
      'cooking_location_other': _getValue(z['If_Others_Please_Mention9']),
      'separate_kitchen': _matchOption(_getValue(z['Separate_Room_for_kitchen1']), ['(1) Yes', '(2) No']),
      'cooking_fuel_types': _toList(z['Type_of_fuel_used_for_cooking']),
      'cooking_fuel_other': _getValue(z['If_Others_Please_Mention2']),
      'cooking_fuel_main': _getValue(z['Mainly_Used']),
      'lighting_source': _matchOption(_getNonEmptyValue([z['Main_source_of_lighting_in_household'], z['SOURCE_LIG']]), ['(1) Electricity', '(2) Kerosene', '(3) Oil', '(4) Gas']),
      'water_sources': _toList(z['source_of_water']),
      'water_source_other': _getValue(z['If_Others_Please_Mention3']),
      'water_main_source': _getValue(z['Mainly_Used1']),
      'water_treatment': _toList(z['Do_to_the_water_to_make_it_safer_to_drink']),
      'water_treatment_other': _getValue(z['If_Others_Please_Mention5']),
      'water_all_sources': _toList(z['Source_water_used_for_all_purposes']),
      'water_all_other': _getValue(z['If_Others_Please_Mention']),
      'toilet_facility': _matchOption(_getNonEmptyValue([z['What_kind_of_toilet_facility_HH1'], z['TOILET']]), ['(1) Flush Toilet', '(2) Toilet ST', '(3) Pit toilet', '(4) Open Field']),
      'toilet_facility_other': _getValue(z['If_Others_Please_Mention7']),
      'ration_card': _matchOption(_getNonEmptyValue([z['Have_ration_card'], z['RCARD']]), ['(1) White card', '(2) Pink Card', '(3) No card']),
      'religion': _matchOption(_getNonEmptyValue([z['RELIGION1'], z['Religion']]), ['(1) Hindu', '(2) Muslim', '(3) Christian']),
      'caste': _matchOption(_getNonEmptyValue([z['Cast_of_the_head'], z['CASTE']]), ['(1) SC', '(2) ST', '(3) BC', '(4) FC']),
      'agriculture_land': _matchOption(_getValue(z['Any_agriculture_land']), ['(1) Yes', '(2) No']),
      'agriculture_land_area': _getValue(z['Number']),
      'agriculture_land_unit': _getValue(z['Land_Unit']),
      'irrigated_land_area': _getValue(z['Land_is_irrigated']),
      'irrigated_land_unit': _getValue(z['Land_Unit1']),
      'irrigated_none': z['None'] == true || z['None'] == "true" || _getValue(z['None']).toLowerCase() == 'true',
      'cattle_owned': _toList(z['Own_any_cattle1']),
      'cattle_other': _getValue(z['If_Others_Please_Mention4']),
      'health_care_place': _matchOption(_getNonEmptyValue([z['get_sick_where_do_they_go'], z['GET_SICK_OTH']]), [
        '(1) Govt.hospital',
        '(2) MediCiti hospital',
        '(3) private hospital',
        '(4) Private MBBS doctor',
        '(5) RMP',
        '(6) Medical shop',
        '(7) Home treatment'
      ]),
      'govt_hospital_reasons': _toList(z['Why_they_dont_go_to_Govt_Hospital']),
      'govt_hospital_other': _getValue(z['If_Others_Please_Mention6']),
      'household_assets': _mapAssetsFromZoho(z),
      'is_temporary': false,
      'clientUpdatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  String _getValue(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      if (value.isEmpty) return '';
      return _getValue(value.first);
    }
    if (value is Map) {
      if (value.containsKey('display_value')) return value['display_value']?.toString() ?? '';
      if (value.containsKey('zc_display_value')) return value['zc_display_value']?.toString() ?? '';
      
      // Check for specific field names that often hold the label
      const labelKeys = ['District', 'State', 'Mandal', 'Village', 'value'];
      for (final key in labelKeys) {
        if (value.containsKey(key)) return value[key]?.toString() ?? '';
      }
    }
    return value.toString();
  }

  String _matchOption(dynamic value, List<String> options) {
    if (value == null) return '';
    String valStr = _getValue(value).trim();
    if (valStr.isEmpty) return '';

    // If Zoho sends exactly one of our options, return it
    for (var opt in options) {
      if (opt == valStr) return opt;
    }

    // Handle prefixed options like "(1) Yes"
    String prefix = '';
    if (RegExp(r'^\d+$').hasMatch(valStr)) {
      prefix = '($valStr)';
    } else if (valStr.startsWith('(') && valStr.contains(')')) {
      prefix = valStr.substring(0, valStr.indexOf(')') + 1);
    }

    if (prefix.isNotEmpty) {
      for (var opt in options) {
        if (opt.startsWith(prefix)) return opt;
      }
    }

    // Fallback: check if the value is contained in any option (case insensitive)
    for (var opt in options) {
      if (opt.toLowerCase().contains(valStr.toLowerCase())) return opt;
    }

    return valStr;
  }

  String _getNonEmptyValue(List<dynamic> values) {
    for (var val in values) {
      final s = _getValue(val);
      if (s.isNotEmpty) return s;
    }
    return '';
  }


  List<String> _toList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => _getValue(e)).toList();
    }
    if (value is String) {
      if (value.startsWith('[') && value.endsWith(']')) {
        try {
          final List<dynamic> parsed = jsonDecode(value);
          return parsed.map((e) => _getValue(e)).toList();
        } catch (_) {}
      }
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [_getValue(value)];
  }

  Map<String, dynamic> _mapAssetsToZoho(dynamic assets) {
    final List<String> list = assets is List ? assets.cast<String>() : [];
    final Map<String, String> apiNames = {
      'Mattress': 'Mattress', 'Cot/bed': 'Cot_bed', 'Electric Fan': 'Electric_Fan',
      'Pressure cooker': 'Pressure_cooker', 'sewing Machine': 'sewing_Machine',
      'Refrigerator': 'Refrigerator', 'Mobile phone': 'Mobile_phone', 'Any phone': 'Any_phone',
      'Bicycle': 'Bicycle', 'Scooter': 'Scooter', 'Animal cart': 'Animal_cart',
      'Chair': 'Chair', 'Table': 'Table', 'Radio': 'Radio', 'Mixer': 'Mixer',
      'Colour TV': 'Colour_TV', 'A/C': 'A_C', 'Water pump': 'Water_pump',
      'Computer': 'Computer', 'Tractor': 'Tractor', 'Car': 'Car', 'Thresher': 'Thresher'
    };
    final Map<String, dynamic> result = {};
    apiNames.forEach((ui, api) => result[api] = list.contains(ui) ? '(1) Yes' : '(2) No');
    return result;
  }

  List<String> _mapAssetsFromZoho(Map<String, dynamic> z) {
    final Map<String, String> apiNames = {
      'Mattress': 'Mattress', 'Cot/bed': 'Cot_bed', 'Electric Fan': 'Electric_Fan',
      'Pressure cooker': 'Pressure_cooker', 'sewing Machine': 'sewing_Machine',
      'Refrigerator': 'Refrigerator', 'Mobile phone': 'Mobile_phone', 'Any phone': 'Any_phone',
      'Bicycle': 'Bicycle', 'Scooter': 'Scooter', 'Animal cart': 'Animal_cart',
      'Chair': 'Chair', 'Table': 'Table', 'Radio': 'Radio', 'Mixer': 'Mixer',
      'Colour TV': 'Colour_TV', 'A/C': 'A_C', 'Water pump': 'Water_pump',
      'Computer': 'Computer', 'Tractor': 'Tractor', 'Car': 'Car', 'Thresher': 'Thresher'
    };
    final List<String> result = [];
    apiNames.forEach((ui, api) {
      final val = _getValue(z[api]);
      if (val == '1' || val.toLowerCase().contains('yes')) result.add(ui);
    });
    return result;
  }

  String _mapHouseType(String? type) {
    switch (type) {
      case 'kutcha':
        return 'Kutcha';
      case 'semi_pucca':
        return 'Semi Pucca';
      case 'pucca':
        return 'Pucca';
      default:
        return '';
    }
  }
}
