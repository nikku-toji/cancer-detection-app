// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: flutter pub run build_runner build

part of 'scan_record.dart';

class ScanRecordAdapter extends TypeAdapter<ScanRecord> {
  @override
  final int typeId = 0;

  @override
  ScanRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanRecord(
      id: fields[0] as String,
      cancerType: fields[1] as String,
      imagePath: fields[2] as String,
      topLabel: fields[3] as String,
      topConfidence: fields[4] as double,
      allConfidences: (fields[5] as Map).cast<String, double>(),
      createdAt: fields[6] as DateTime,
      isHighRisk: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ScanRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cancerType)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.topLabel)
      ..writeByte(4)
      ..write(obj.topConfidence)
      ..writeByte(5)
      ..write(obj.allConfidences)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.isHighRisk);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}
