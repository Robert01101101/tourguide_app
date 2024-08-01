// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tourguide_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TourguideReportAdapter extends TypeAdapter<TourguideReport> {
  @override
  final int typeId = 2;

  @override
  TourguideReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TourguideReport(
      title: fields[0] as String,
      additionalDetails: fields[1] as String,
      reportAuthorId: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TourguideReport obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.additionalDetails)
      ..writeByte(2)
      ..write(obj.reportAuthorId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourguideReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
