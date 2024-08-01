// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tourguide_place.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TourguidePlaceAdapter extends TypeAdapter<TourguidePlace> {
  @override
  final int typeId = 1;

  @override
  TourguidePlace read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TourguidePlace(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      googleMapPlaceId: fields[2] as String,
      title: fields[3] as String,
      description: fields[4] as String,
      photoUrl: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TourguidePlace obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.googleMapPlaceId)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.photoUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourguidePlaceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
