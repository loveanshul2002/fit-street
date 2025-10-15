// lib/utils/kyc_utils.dart
class KycUtils {
  /// Checks if KYC is completed based on various possible field names from the API response
  static bool isKycCompleted(Map<String, dynamic> data) {
    // Check all possible KYC status indicators
    final kycCompleted = data['kycStatus'] == 'completed' || 
                        data['kycCompleted'] == true || 
                        data['isKycCompleted'] == true ||
                        data['isKyc'] == true ||
                        data['kyc'] == true ||
                        (data['kycStatus']?.toString().toLowerCase() == 'approved');
    
    return kycCompleted;
  }

  /// Debug function to print all KYC-related fields (only use for debugging)
  static void debugKycStatus(Map<String, dynamic> data) {
    print('=== KYC Debug Information ===');
    print('kycStatus: ${data['kycStatus']} (type: ${data['kycStatus']?.runtimeType})');
    print('kycCompleted: ${data['kycCompleted']} (type: ${data['kycCompleted']?.runtimeType})');
    print('isKycCompleted: ${data['isKycCompleted']} (type: ${data['isKycCompleted']?.runtimeType})');
    print('isKyc: ${data['isKyc']} (type: ${data['isKyc']?.runtimeType})');
    print('kyc: ${data['kyc']} (type: ${data['kyc']?.runtimeType})');
    print('Final result: ${isKycCompleted(data)}');
    print('All keys containing "kyc": ${data.keys.where((k) => k.toString().toLowerCase().contains('kyc')).toList()}');
    print('===========================');
  }
}
