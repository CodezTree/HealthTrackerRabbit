// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetHealthEntryCollection on Isar {
  IsarCollection<HealthEntry> get healthEntrys => this.collection();
}

const HealthEntrySchema = CollectionSchema(
  name: r'HealthEntry',
  id: -643552396761949885,
  properties: {
    r'battery': PropertySchema(
      id: 0,
      name: r'battery',
      type: IsarType.long,
    ),
    r'chargingState': PropertySchema(
      id: 1,
      name: r'chargingState',
      type: IsarType.long,
    ),
    r'heartRate': PropertySchema(
      id: 2,
      name: r'heartRate',
      type: IsarType.long,
    ),
    r'maxHeartRate': PropertySchema(
      id: 3,
      name: r'maxHeartRate',
      type: IsarType.long,
    ),
    r'minHeartRate': PropertySchema(
      id: 4,
      name: r'minHeartRate',
      type: IsarType.long,
    ),
    r'screenStatus': PropertySchema(
      id: 5,
      name: r'screenStatus',
      type: IsarType.long,
    ),
    r'sleepHours': PropertySchema(
      id: 6,
      name: r'sleepHours',
      type: IsarType.double,
    ),
    r'spo2': PropertySchema(
      id: 7,
      name: r'spo2',
      type: IsarType.long,
    ),
    r'sportsTime': PropertySchema(
      id: 8,
      name: r'sportsTime',
      type: IsarType.long,
    ),
    r'stepCount': PropertySchema(
      id: 9,
      name: r'stepCount',
      type: IsarType.long,
    ),
    r'timestamp': PropertySchema(
      id: 10,
      name: r'timestamp',
      type: IsarType.dateTime,
    ),
    r'userId': PropertySchema(
      id: 11,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _healthEntryEstimateSize,
  serialize: _healthEntrySerialize,
  deserialize: _healthEntryDeserialize,
  deserializeProp: _healthEntryDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _healthEntryGetId,
  getLinks: _healthEntryGetLinks,
  attach: _healthEntryAttach,
  version: '3.1.0+1',
);

int _healthEntryEstimateSize(
  HealthEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _healthEntrySerialize(
  HealthEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.battery);
  writer.writeLong(offsets[1], object.chargingState);
  writer.writeLong(offsets[2], object.heartRate);
  writer.writeLong(offsets[3], object.maxHeartRate);
  writer.writeLong(offsets[4], object.minHeartRate);
  writer.writeLong(offsets[5], object.screenStatus);
  writer.writeDouble(offsets[6], object.sleepHours);
  writer.writeLong(offsets[7], object.spo2);
  writer.writeLong(offsets[8], object.sportsTime);
  writer.writeLong(offsets[9], object.stepCount);
  writer.writeDateTime(offsets[10], object.timestamp);
  writer.writeString(offsets[11], object.userId);
}

HealthEntry _healthEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = HealthEntry();
  object.battery = reader.readLong(offsets[0]);
  object.chargingState = reader.readLong(offsets[1]);
  object.heartRate = reader.readLong(offsets[2]);
  object.id = id;
  object.maxHeartRate = reader.readLong(offsets[3]);
  object.minHeartRate = reader.readLong(offsets[4]);
  object.screenStatus = reader.readLong(offsets[5]);
  object.sleepHours = reader.readDouble(offsets[6]);
  object.spo2 = reader.readLong(offsets[7]);
  object.sportsTime = reader.readLong(offsets[8]);
  object.stepCount = reader.readLong(offsets[9]);
  object.timestamp = reader.readDateTime(offsets[10]);
  object.userId = reader.readString(offsets[11]);
  return object;
}

P _healthEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _healthEntryGetId(HealthEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _healthEntryGetLinks(HealthEntry object) {
  return [];
}

void _healthEntryAttach(
    IsarCollection<dynamic> col, Id id, HealthEntry object) {
  object.id = id;
}

extension HealthEntryQueryWhereSort
    on QueryBuilder<HealthEntry, HealthEntry, QWhere> {
  QueryBuilder<HealthEntry, HealthEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension HealthEntryQueryWhere
    on QueryBuilder<HealthEntry, HealthEntry, QWhereClause> {
  QueryBuilder<HealthEntry, HealthEntry, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension HealthEntryQueryFilter
    on QueryBuilder<HealthEntry, HealthEntry, QFilterCondition> {
  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> batteryEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'battery',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      batteryGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'battery',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> batteryLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'battery',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> batteryBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'battery',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      chargingStateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chargingState',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      chargingStateGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chargingState',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      chargingStateLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chargingState',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      chargingStateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chargingState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      heartRateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'heartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      heartRateGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'heartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      heartRateLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'heartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      heartRateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'heartRate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      maxHeartRateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      maxHeartRateGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      maxHeartRateLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      maxHeartRateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxHeartRate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      minHeartRateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'minHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      minHeartRateGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'minHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      minHeartRateLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'minHeartRate',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      minHeartRateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'minHeartRate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      screenStatusEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'screenStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      screenStatusGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'screenStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      screenStatusLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'screenStatus',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      screenStatusBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'screenStatus',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sleepHoursEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sleepHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sleepHoursGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sleepHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sleepHoursLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sleepHours',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sleepHoursBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sleepHours',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> spo2EqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'spo2',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> spo2GreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'spo2',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> spo2LessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'spo2',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> spo2Between(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'spo2',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sportsTimeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sportsTime',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sportsTimeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sportsTime',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sportsTimeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sportsTime',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      sportsTimeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sportsTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      stepCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stepCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      stepCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stepCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      stepCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stepCount',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      stepCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stepCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition> userIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension HealthEntryQueryObject
    on QueryBuilder<HealthEntry, HealthEntry, QFilterCondition> {}

extension HealthEntryQueryLinks
    on QueryBuilder<HealthEntry, HealthEntry, QFilterCondition> {}

extension HealthEntryQuerySortBy
    on QueryBuilder<HealthEntry, HealthEntry, QSortBy> {
  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByBattery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'battery', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByBatteryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'battery', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByChargingState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargingState', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      sortByChargingStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargingState', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByMaxHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxHeartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      sortByMaxHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxHeartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByMinHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minHeartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      sortByMinHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minHeartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByScreenStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'screenStatus', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      sortByScreenStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'screenStatus', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySleepHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySpo2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spo2', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySpo2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spo2', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySportsTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sportsTime', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortBySportsTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sportsTime', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByStepCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepCount', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByStepCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepCount', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension HealthEntryQuerySortThenBy
    on QueryBuilder<HealthEntry, HealthEntry, QSortThenBy> {
  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByBattery() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'battery', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByBatteryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'battery', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByChargingState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargingState', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      thenByChargingStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chargingState', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'heartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByMaxHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxHeartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      thenByMaxHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxHeartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByMinHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minHeartRate', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      thenByMinHeartRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'minHeartRate', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByScreenStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'screenStatus', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy>
      thenByScreenStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'screenStatus', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySleepHoursDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sleepHours', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySpo2() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spo2', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySpo2Desc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spo2', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySportsTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sportsTime', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenBySportsTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sportsTime', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByStepCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepCount', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByStepCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stepCount', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QAfterSortBy> thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension HealthEntryQueryWhereDistinct
    on QueryBuilder<HealthEntry, HealthEntry, QDistinct> {
  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByBattery() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'battery');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByChargingState() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chargingState');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'heartRate');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByMaxHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxHeartRate');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByMinHeartRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'minHeartRate');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByScreenStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'screenStatus');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctBySleepHours() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sleepHours');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctBySpo2() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'spo2');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctBySportsTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sportsTime');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByStepCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stepCount');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }

  QueryBuilder<HealthEntry, HealthEntry, QDistinct> distinctByUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension HealthEntryQueryProperty
    on QueryBuilder<HealthEntry, HealthEntry, QQueryProperty> {
  QueryBuilder<HealthEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> batteryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'battery');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> chargingStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chargingState');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> heartRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'heartRate');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> maxHeartRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxHeartRate');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> minHeartRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'minHeartRate');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> screenStatusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'screenStatus');
    });
  }

  QueryBuilder<HealthEntry, double, QQueryOperations> sleepHoursProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sleepHours');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> spo2Property() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'spo2');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> sportsTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sportsTime');
    });
  }

  QueryBuilder<HealthEntry, int, QQueryOperations> stepCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stepCount');
    });
  }

  QueryBuilder<HealthEntry, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }

  QueryBuilder<HealthEntry, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
