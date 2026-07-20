// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company_commitment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CompanyCommitment {

 int get id; String get companyName; int get totalAmount; int get chequeCount;
/// Create a copy of CompanyCommitment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyCommitmentCopyWith<CompanyCommitment> get copyWith => _$CompanyCommitmentCopyWithImpl<CompanyCommitment>(this as CompanyCommitment, _$identity);

  /// Serializes this CompanyCommitment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyCommitment&&(identical(other.id, id) || other.id == id)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyName,totalAmount,chequeCount);

@override
String toString() {
  return 'CompanyCommitment(id: $id, companyName: $companyName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class $CompanyCommitmentCopyWith<$Res>  {
  factory $CompanyCommitmentCopyWith(CompanyCommitment value, $Res Function(CompanyCommitment) _then) = _$CompanyCommitmentCopyWithImpl;
@useResult
$Res call({
 int id, String companyName, int totalAmount, int chequeCount
});




}
/// @nodoc
class _$CompanyCommitmentCopyWithImpl<$Res>
    implements $CompanyCommitmentCopyWith<$Res> {
  _$CompanyCommitmentCopyWithImpl(this._self, this._then);

  final CompanyCommitment _self;
  final $Res Function(CompanyCommitment) _then;

/// Create a copy of CompanyCommitment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyCommitment].
extension CompanyCommitmentPatterns on CompanyCommitment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyCommitment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyCommitment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyCommitment value)  $default,){
final _that = this;
switch (_that) {
case _CompanyCommitment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyCommitment value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyCommitment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String companyName,  int totalAmount,  int chequeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyCommitment() when $default != null:
return $default(_that.id,_that.companyName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String companyName,  int totalAmount,  int chequeCount)  $default,) {final _that = this;
switch (_that) {
case _CompanyCommitment():
return $default(_that.id,_that.companyName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String companyName,  int totalAmount,  int chequeCount)?  $default,) {final _that = this;
switch (_that) {
case _CompanyCommitment() when $default != null:
return $default(_that.id,_that.companyName,_that.totalAmount,_that.chequeCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyCommitment implements CompanyCommitment {
  const _CompanyCommitment({required this.id, required this.companyName, required this.totalAmount, required this.chequeCount});
  factory _CompanyCommitment.fromJson(Map<String, dynamic> json) => _$CompanyCommitmentFromJson(json);

@override final  int id;
@override final  String companyName;
@override final  int totalAmount;
@override final  int chequeCount;

/// Create a copy of CompanyCommitment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyCommitmentCopyWith<_CompanyCommitment> get copyWith => __$CompanyCommitmentCopyWithImpl<_CompanyCommitment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyCommitmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyCommitment&&(identical(other.id, id) || other.id == id)&&(identical(other.companyName, companyName) || other.companyName == companyName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyName,totalAmount,chequeCount);

@override
String toString() {
  return 'CompanyCommitment(id: $id, companyName: $companyName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class _$CompanyCommitmentCopyWith<$Res> implements $CompanyCommitmentCopyWith<$Res> {
  factory _$CompanyCommitmentCopyWith(_CompanyCommitment value, $Res Function(_CompanyCommitment) _then) = __$CompanyCommitmentCopyWithImpl;
@override @useResult
$Res call({
 int id, String companyName, int totalAmount, int chequeCount
});




}
/// @nodoc
class __$CompanyCommitmentCopyWithImpl<$Res>
    implements _$CompanyCommitmentCopyWith<$Res> {
  __$CompanyCommitmentCopyWithImpl(this._self, this._then);

  final _CompanyCommitment _self;
  final $Res Function(_CompanyCommitment) _then;

/// Create a copy of CompanyCommitment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_CompanyCommitment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,companyName: null == companyName ? _self.companyName : companyName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
