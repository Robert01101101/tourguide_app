// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tour.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TourAdapter extends TypeAdapter<Tour> {
  @override
  final int typeId = 0;

  @override
  Tour read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Tour(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      city: fields[3] as String,
      visibility: fields[4] as String,
      imageUrl: fields[5] as String,
      createdDateTime: fields[6] as DateTime?,
      lastChangedDateTime: fields[7] as DateTime?,
      latitude: fields[8] as double,
      longitude: fields[9] as double,
      placeId: fields[10] as String,
      authorName: fields[11] as String,
      authorId: fields[12] as String,
      requestReviewStatus: fields[13] as String,
      tourguidePlaces: (fields[14] as List).cast<TourguidePlace>(),
      reports: (fields[15] as List).cast<TourguideReport>(),
      upvotes: fields[16] as int,
      downvotes: fields[17] as int,
      tags: (fields[18] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, Tour obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.visibility)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.createdDateTime)
      ..writeByte(7)
      ..write(obj.lastChangedDateTime)
      ..writeByte(8)
      ..write(obj.latitude)
      ..writeByte(9)
      ..write(obj.longitude)
      ..writeByte(10)
      ..write(obj.placeId)
      ..writeByte(11)
      ..write(obj.authorName)
      ..writeByte(12)
      ..write(obj.authorId)
      ..writeByte(13)
      ..write(obj.requestReviewStatus)
      ..writeByte(14)
      ..write(obj.tourguidePlaces)
      ..writeByte(15)
      ..write(obj.reports)
      ..writeByte(18)
      ..write(obj.tags)
      ..writeByte(16)
      ..write(obj.upvotes)
      ..writeByte(17)
      ..write(obj.downvotes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
