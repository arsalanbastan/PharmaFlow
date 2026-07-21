// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Company {

 int? get id; String get name; String? get nationalId; String? get economicCode; String? get notes; String? get visitorName; String? get visitorPhone; String? get accountantName; String? get accountantPhone; DateTime? get archivedAt; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCopyWith<Company> get copyWith => _$CompanyCopyWithImpl<Company>(this as Company, _$identity);

  /// Serializes this Company to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nationalId, nationalId) || other.nationalId == nationalId)&&(identical(other.economicCode, economicCode) || other.economicCode == economicCode)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.visitorName, visitorName) || other.visitorName == visitorName)&&(identical(other.visitorPhone, visitorPhone) || other.visitorPhone == visitorPhone)&&(identical(other.accountantName, accountantName) || other.accountantName == accountantName)&&(identical(other.accountantPhone, accountantPhone) || other.accountantPhone == accountantPhone)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nationalId,economicCode,notes,visitorName,visitorPhone,accountantName,accountantPhone,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Company(id: $id, name: $name, nationalId: $nationalId, economicCode: $economicCode, notes: $notes, visitorName: $visitorName, visitorPhone: $visitorPhone, accountantName: $accountantName, accountantPhone: $accountantPhone, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $CompanyCopyWith<$Res>  {
  factory $CompanyCopyWith(Company value, $Res Function(Company) _then) = _$CompanyCopyWithImpl;
@useResult
$Res call({
 int? id, String name, String? nationalId, String? economicCode, String? notes, String? visitorName, String? visitorPhone, String? accountantName, String? accountantPhone, DateTime? archivedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$CompanyCopyWithImpl<$Res>
    implements $CompanyCopyWith<$Res> {
  _$CompanyCopyWithImpl(this._self, this._then);

  final Company _self;
  final $Res Function(Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? name = null,Object? nationalId = freezed,Object? economicCode = freezed,Object? notes = freezed,Object? visitorName = freezed,Object? visitorPhone = freezed,Object? accountantName = freezed,Object? accountantPhone = freezed,Object? archivedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nationalId: freezed == nationalId ? _self.nationalId : nationalId // ignore: cast_nullable_to_non_nullable
as String?,economicCode: freezed == economicCode ? _self.economicCode : economicCode // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,visitorName: freezed == visitorName ? _self.visitorName : visitorName // ignore: cast_nullable_to_non_nullable
as String?,visitorPhone: freezed == visitorPhone ? _self.visitorPhone : visitorPhone // ignore: cast_nullable_to_non_nullable
as String?,accountantName: freezed == accountantName ? _self.accountantName : accountantName // ignore: cast_nullable_to_non_nullable
as String?,accountantPhone: freezed == accountantPhone ? _self.accountantPhone : accountantPhone // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Company].
extension CompanyPatterns on Company {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Company value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Company value)  $default,){
final _that = this;
switch (_that) {
case _Company():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Company value)?  $default,){
final _that = this;
switch (_that) {
case _Company() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id,  String name,  String? nationalId,  String? economicCode,  String? notes,  String? visitorName,  String? visitorPhone,  String? accountantName,  String? accountantPhone,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.nationalId,_that.economicCode,_that.notes,_that.visitorName,_that.visitorPhone,_that.accountantName,_that.accountantPhone,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id,  String name,  String? nationalId,  String? economicCode,  String? notes,  String? visitorName,  String? visitorPhone,  String? accountantName,  String? accountantPhone,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Company():
return $default(_that.id,_that.name,_that.nationalId,_that.economicCode,_that.notes,_that.visitorName,_that.visitorPhone,_that.accountantName,_that.accountantPhone,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id,  String name,  String? nationalId,  String? economicCode,  String? notes,  String? visitorName,  String? visitorPhone,  String? accountantName,  String? accountantPhone,  DateTime? archivedAt,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Company() when $default != null:
return $default(_that.id,_that.name,_that.nationalId,_that.economicCode,_that.notes,_that.visitorName,_that.visitorPhone,_that.accountantName,_that.accountantPhone,_that.archivedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Company implements Company {
  const _Company({this.id, required this.name, this.nationalId, this.economicCode, this.notes, this.visitorName, this.visitorPhone, this.accountantName, this.accountantPhone, this.archivedAt, required this.createdAt, required this.updatedAt});
  factory _Company.fromJson(Map<String, dynamic> json) => _$CompanyFromJson(json);

@override final  int? id;
@override final  String name;
@override final  String? nationalId;
@override final  String? economicCode;
@override final  String? notes;
@override final  String? visitorName;
@override final  String? visitorPhone;
@override final  String? accountantName;
@override final  String? accountantPhone;
@override final  DateTime? archivedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCopyWith<_Company> get copyWith => __$CompanyCopyWithImpl<_Company>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Company&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.nationalId, nationalId) || other.nationalId == nationalId)&&(identical(other.economicCode, economicCode) || other.economicCode == economicCode)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.visitorName, visitorName) || other.visitorName == visitorName)&&(identical(other.visitorPhone, visitorPhone) || other.visitorPhone == visitorPhone)&&(identical(other.accountantName, accountantName) || other.accountantName == accountantName)&&(identical(other.accountantPhone, accountantPhone) || other.accountantPhone == accountantPhone)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,nationalId,economicCode,notes,visitorName,visitorPhone,accountantName,accountantPhone,archivedAt,createdAt,updatedAt);

@override
String toString() {
  return 'Company(id: $id, name: $name, nationalId: $nationalId, economicCode: $economicCode, notes: $notes, visitorName: $visitorName, visitorPhone: $visitorPhone, accountantName: $accountantName, accountantPhone: $accountantPhone, archivedAt: $archivedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$CompanyCopyWith<$Res> implements $CompanyCopyWith<$Res> {
  factory _$CompanyCopyWith(_Company value, $Res Function(_Company) _then) = __$CompanyCopyWithImpl;
@override @useResult
$Res call({
 int? id, String name, String? nationalId, String? economicCode, String? notes, String? visitorName, String? visitorPhone, String? accountantName, String? accountantPhone, DateTime? archivedAt, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$CompanyCopyWithImpl<$Res>
    implements _$CompanyCopyWith<$Res> {
  __$CompanyCopyWithImpl(this._self, this._then);

  final _Company _self;
  final $Res Function(_Company) _then;

/// Create a copy of Company
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? name = null,Object? nationalId = freezed,Object? economicCode = freezed,Object? notes = freezed,Object? visitorName = freezed,Object? visitorPhone = freezed,Object? accountantName = freezed,Object? accountantPhone = freezed,Object? archivedAt = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Company(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,nationalId: freezed == nationalId ? _self.nationalId : nationalId // ignore: cast_nullable_to_non_nullable
as String?,economicCode: freezed == economicCode ? _self.economicCode : economicCode // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,visitorName: freezed == visitorName ? _self.visitorName : visitorName // ignore: cast_nullable_to_non_nullable
as String?,visitorPhone: freezed == visitorPhone ? _self.visitorPhone : visitorPhone // ignore: cast_nullable_to_non_nullable
as String?,accountantName: freezed == accountantName ? _self.accountantName : accountantName // ignore: cast_nullable_to_non_nullable
as String?,accountantPhone: freezed == accountantPhone ? _self.accountantPhone : accountantPhone // ignore: cast_nullable_to_non_nullable
as String?,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
