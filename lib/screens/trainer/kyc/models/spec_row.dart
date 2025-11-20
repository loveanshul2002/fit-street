import 'package:flutter/material.dart';

class SpecRow {
  String? specialization;
  final TextEditingController certificateName = TextEditingController();
  String? certificatePhotoPath;
  // Backend specialization proof id, if this row comes from server
  String? proofId;
}
