// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'today_check.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TodayCheck {

 int get bankId; String get bankName; int get totalAmount; int get chequeCount;
/// Create a copy of TodayCheck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TodayCheckCopyWith<TodayCheck> get copyWith => _$TodayCheckCopyWithImpl<TodayCheck>(this as TodayCheck, _$identity);

  /// Serializes this TodayCheck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TodayCheck&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankId,bankName,totalAmount,chequeCount);

@override
String toString() {
  return 'TodayCheck(bankId: $bankId, bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class $TodayCheckCopyWith<$Res>  {
  factory $TodayCheckCopyWith(TodayCheck value, $Res Function(TodayCheck) _then) = _$TodayCheckCopyWithImpl;
@useResult
$Res call({
 int bankId, String bankName, int totalAmount, int chequeCount
});




}
/// @nodoc
class _$TodayCheckCopyWithImpl<$Res>
    implements $TodayCheckCopyWith<$Res> {
  _$TodayCheckCopyWithImpl(this._self, this._then);

  final TodayCheck _self;
  final $Res Function(TodayCheck) _then;

/// Create a copy of TodayCheck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bankId = null,Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_self.copyWith(
bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int,bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TodayCheck].
extension TodayCheckPatterns on TodayCheck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TodayCheck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TodayCheck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TodayCheck value)  $default,){
final _that = this;
switch (_that) {
case _TodayCheck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TodayCheck value)?  $default,){
final _that = this;
switch (_that) {
case _TodayCheck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int bankId,  String bankName,  int totalAmount,  int chequeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TodayCheck() when $default != null:
return $default(_that.bankId,_that.bankName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int bankId,  String bankName,  int totalAmount,  int chequeCount)  $default,) {final _that = this;
switch (_that) {
case _TodayCheck():
return $default(_that.bankId,_that.bankName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int bankId,  String bankName,  int totalAmount,  int chequeCount)?  $default,) {final _that = this;
switch (_that) {
case _TodayCheck() when $default != null:
return $default(_that.bankId,_that.bankName,_that.totalAmount,_that.chequeCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TodayCheck implements TodayCheck {
  const _TodayCheck({required this.bankId, required this.bankName, required this.totalAmount, required this.chequeCount});
  factory _TodayCheck.fromJson(Map<String, dynamic> json) => _$TodayCheckFromJson(json);

@override final  int bankId;
@override final  String bankName;
@override final  int totalAmount;
@override final  int chequeCount;

/// Create a copy of TodayCheck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TodayCheckCopyWith<_TodayCheck> get copyWith => __$TodayCheckCopyWithImpl<_TodayCheck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TodayCheckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TodayCheck&&(identical(other.bankId, bankId) || other.bankId == bankId)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankId,bankName,totalAmount,chequeCount);

@override
String toString() {
  return 'TodayCheck(bankId: $bankId, bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class _$TodayCheckCopyWith<$Res> implements $TodayCheckCopyWith<$Res> {
  factory _$TodayCheckCopyWith(_TodayCheck value, $Res Function(_TodayCheck) _then) = __$TodayCheckCopyWithImpl;
@override @useResult
$Res call({
 int bankId, String bankName, int totalAmount, int chequeCount
});




}
/// @nodoc
class __$TodayCheckCopyWithImpl<$Res>
    implements _$TodayCheckCopyWith<$Res> {
  __$TodayCheckCopyWithImpl(this._self, this._then);

  final _TodayCheck _self;
  final $Res Function(_TodayCheck) _then;

/// Create a copy of TodayCheck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bankId = null,Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_TodayCheck(
bankId: null == bankId ? _self.bankId : bankId // ignore: cast_nullable_to_non_nullable
as int,bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
