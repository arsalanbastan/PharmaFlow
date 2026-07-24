// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cheque.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Cheque {

 int get id; int get companyId; int get bankAccountId; String get chequeNumber; int get amountRial; DateTime get issueDate; DateTime get dueDate; ChequeStatus get status; bool get isRegisteredInSayad; String? get receiverName; String? get description; DateTime? get archivedAt;@JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson) Uint8List? get imageData; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Cheque
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChequeCopyWith<Cheque> get copyWith => _$ChequeCopyWithImpl<Cheque>(this as Cheque, _$identity);

  /// Serializes this Cheque to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Cheque&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.chequeNumber, chequeNumber) || other.chequeNumber == chequeNumber)&&(identical(other.amountRial, amountRial) || other.amountRial == amountRial)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.isRegisteredInSayad, isRegisteredInSayad) || other.isRegisteredInSayad == isRegisteredInSayad)&&(identical(other.receiverName, receiverName) || other.receiverName == receiverName)&&(identical(other.description, description) || other.description == description)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.imageData, imageData)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,bankAccountId,chequeNumber,amountRial,issueDate,dueDate,status,isRegisteredInSayad,receiverName,description,archivedAt,const DeepCollectionEquality().hash(imageData),createdAt,updatedAt);

@override
String toString() {
  return 'Cheque(id: $id, companyId: $companyId, bankAccountId: $bankAccountId, chequeNumber: $chequeNumber, amountRial: $amountRial, issueDate: $issueDate, dueDate: $dueDate, status: $status, isRegisteredInSayad: $isRegisteredInSayad, receiverName: $receiverName, description: $description, archivedAt: $archivedAt, imageData: $imageData, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ChequeCopyWith<$Res>  {
  factory $ChequeCopyWith(Cheque value, $Res Function(Cheque) _then) = _$ChequeCopyWithImpl;
@useResult
$Res call({
 int id, int companyId, int bankAccountId, String chequeNumber, int amountRial, DateTime issueDate, DateTime dueDate, ChequeStatus status, bool isRegisteredInSayad, String? receiverName, String? description, DateTime? archivedAt,@JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson) Uint8List? imageData, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$ChequeCopyWithImpl<$Res>
    implements $ChequeCopyWith<$Res> {
  _$ChequeCopyWithImpl(this._self, this._then);

  final Cheque _self;
  final $Res Function(Cheque) _then;

/// Create a copy of Cheque
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyId = null,Object? bankAccountId = null,Object? chequeNumber = null,Object? amountRial = null,Object? issueDate = null,Object? dueDate = null,Object? status = null,Object? isRegisteredInSayad = null,Object? receiverName = freezed,Object? description = freezed,Object? archivedAt = freezed,Object? imageData = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as int,chequeNumber: null == chequeNumber ? _self.chequeNumber : chequeNumber // ignore: cast_nullable_to_non_nullable
as String,amountRial: null == amountRial ? _self.amountRial : amountRial // ignore: cast_nullable_to_non_nullable
as int,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChequeStatus,isRegisteredInSayad: null == isRegisteredInSayad ? _self.isRegisteredInSayad : isRegisteredInSayad // ignore: cast_nullable_to_non_nullable
as bool,receiverName: freezed == receiverName ? _self.receiverName : receiverName // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,imageData: freezed == imageData ? _self.imageData : imageData // ignore: cast_nullable_to_non_nullable
as Uint8List?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Cheque].
extension ChequePatterns on Cheque {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Cheque value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Cheque() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Cheque value)  $default,){
final _that = this;
switch (_that) {
case _Cheque():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Cheque value)?  $default,){
final _that = this;
switch (_that) {
case _Cheque() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int companyId,  int bankAccountId,  String chequeNumber,  int amountRial,  DateTime issueDate,  DateTime dueDate,  ChequeStatus status,  bool isRegisteredInSayad,  String? receiverName,  String? description,  DateTime? archivedAt, @JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson)  Uint8List? imageData,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Cheque() when $default != null:
return $default(_that.id,_that.companyId,_that.bankAccountId,_that.chequeNumber,_that.amountRial,_that.issueDate,_that.dueDate,_that.status,_that.isRegisteredInSayad,_that.receiverName,_that.description,_that.archivedAt,_that.imageData,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int companyId,  int bankAccountId,  String chequeNumber,  int amountRial,  DateTime issueDate,  DateTime dueDate,  ChequeStatus status,  bool isRegisteredInSayad,  String? receiverName,  String? description,  DateTime? archivedAt, @JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson)  Uint8List? imageData,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Cheque():
return $default(_that.id,_that.companyId,_that.bankAccountId,_that.chequeNumber,_that.amountRial,_that.issueDate,_that.dueDate,_that.status,_that.isRegisteredInSayad,_that.receiverName,_that.description,_that.archivedAt,_that.imageData,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int companyId,  int bankAccountId,  String chequeNumber,  int amountRial,  DateTime issueDate,  DateTime dueDate,  ChequeStatus status,  bool isRegisteredInSayad,  String? receiverName,  String? description,  DateTime? archivedAt, @JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson)  Uint8List? imageData,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Cheque() when $default != null:
return $default(_that.id,_that.companyId,_that.bankAccountId,_that.chequeNumber,_that.amountRial,_that.issueDate,_that.dueDate,_that.status,_that.isRegisteredInSayad,_that.receiverName,_that.description,_that.archivedAt,_that.imageData,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Cheque implements Cheque {
  const _Cheque({required this.id, required this.companyId, required this.bankAccountId, required this.chequeNumber, required this.amountRial, required this.issueDate, required this.dueDate, required this.status, required this.isRegisteredInSayad, this.receiverName, this.description, this.archivedAt, @JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson) this.imageData, required this.createdAt, required this.updatedAt});
  factory _Cheque.fromJson(Map<String, dynamic> json) => _$ChequeFromJson(json);

@override final  int id;
@override final  int companyId;
@override final  int bankAccountId;
@override final  String chequeNumber;
@override final  int amountRial;
@override final  DateTime issueDate;
@override final  DateTime dueDate;
@override final  ChequeStatus status;
@override final  bool isRegisteredInSayad;
@override final  String? receiverName;
@override final  String? description;
@override final  DateTime? archivedAt;
@override@JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson) final  Uint8List? imageData;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Cheque
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChequeCopyWith<_Cheque> get copyWith => __$ChequeCopyWithImpl<_Cheque>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChequeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Cheque&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.bankAccountId, bankAccountId) || other.bankAccountId == bankAccountId)&&(identical(other.chequeNumber, chequeNumber) || other.chequeNumber == chequeNumber)&&(identical(other.amountRial, amountRial) || other.amountRial == amountRial)&&(identical(other.issueDate, issueDate) || other.issueDate == issueDate)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.status, status) || other.status == status)&&(identical(other.isRegisteredInSayad, isRegisteredInSayad) || other.isRegisteredInSayad == isRegisteredInSayad)&&(identical(other.receiverName, receiverName) || other.receiverName == receiverName)&&(identical(other.description, description) || other.description == description)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&const DeepCollectionEquality().equals(other.imageData, imageData)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,bankAccountId,chequeNumber,amountRial,issueDate,dueDate,status,isRegisteredInSayad,receiverName,description,archivedAt,const DeepCollectionEquality().hash(imageData),createdAt,updatedAt);

@override
String toString() {
  return 'Cheque(id: $id, companyId: $companyId, bankAccountId: $bankAccountId, chequeNumber: $chequeNumber, amountRial: $amountRial, issueDate: $issueDate, dueDate: $dueDate, status: $status, isRegisteredInSayad: $isRegisteredInSayad, receiverName: $receiverName, description: $description, archivedAt: $archivedAt, imageData: $imageData, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ChequeCopyWith<$Res> implements $ChequeCopyWith<$Res> {
  factory _$ChequeCopyWith(_Cheque value, $Res Function(_Cheque) _then) = __$ChequeCopyWithImpl;
@override @useResult
$Res call({
 int id, int companyId, int bankAccountId, String chequeNumber, int amountRial, DateTime issueDate, DateTime dueDate, ChequeStatus status, bool isRegisteredInSayad, String? receiverName, String? description, DateTime? archivedAt,@JsonKey(fromJson: _imageDataFromJson, toJson: _imageDataToJson) Uint8List? imageData, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$ChequeCopyWithImpl<$Res>
    implements _$ChequeCopyWith<$Res> {
  __$ChequeCopyWithImpl(this._self, this._then);

  final _Cheque _self;
  final $Res Function(_Cheque) _then;

/// Create a copy of Cheque
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyId = null,Object? bankAccountId = null,Object? chequeNumber = null,Object? amountRial = null,Object? issueDate = null,Object? dueDate = null,Object? status = null,Object? isRegisteredInSayad = null,Object? receiverName = freezed,Object? description = freezed,Object? archivedAt = freezed,Object? imageData = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Cheque(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as int,bankAccountId: null == bankAccountId ? _self.bankAccountId : bankAccountId // ignore: cast_nullable_to_non_nullable
as int,chequeNumber: null == chequeNumber ? _self.chequeNumber : chequeNumber // ignore: cast_nullable_to_non_nullable
as String,amountRial: null == amountRial ? _self.amountRial : amountRial // ignore: cast_nullable_to_non_nullable
as int,issueDate: null == issueDate ? _self.issueDate : issueDate // ignore: cast_nullable_to_non_nullable
as DateTime,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ChequeStatus,isRegisteredInSayad: null == isRegisteredInSayad ? _self.isRegisteredInSayad : isRegisteredInSayad // ignore: cast_nullable_to_non_nullable
as bool,receiverName: freezed == receiverName ? _self.receiverName : receiverName // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,imageData: freezed == imageData ? _self.imageData : imageData // ignore: cast_nullable_to_non_nullable
as Uint8List?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
