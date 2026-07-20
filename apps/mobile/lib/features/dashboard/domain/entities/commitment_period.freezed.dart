// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'commitment_period.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CommitmentPeriod {

 int get id;/// مثال:
/// ۵ مرداد ۱۴۰۵
 String get title; String get fromDate; String get toDate; int get totalAmount; int get chequeCount; List<BankCommitment> get banks;
/// Create a copy of CommitmentPeriod
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommitmentPeriodCopyWith<CommitmentPeriod> get copyWith => _$CommitmentPeriodCopyWithImpl<CommitmentPeriod>(this as CommitmentPeriod, _$identity);

  /// Serializes this CommitmentPeriod to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommitmentPeriod&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.toDate, toDate) || other.toDate == toDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other.banks, banks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,fromDate,toDate,totalAmount,chequeCount,const DeepCollectionEquality().hash(banks));

@override
String toString() {
  return 'CommitmentPeriod(id: $id, title: $title, fromDate: $fromDate, toDate: $toDate, totalAmount: $totalAmount, chequeCount: $chequeCount, banks: $banks)';
}


}

/// @nodoc
abstract mixin class $CommitmentPeriodCopyWith<$Res>  {
  factory $CommitmentPeriodCopyWith(CommitmentPeriod value, $Res Function(CommitmentPeriod) _then) = _$CommitmentPeriodCopyWithImpl;
@useResult
$Res call({
 int id, String title, String fromDate, String toDate, int totalAmount, int chequeCount, List<BankCommitment> banks
});




}
/// @nodoc
class _$CommitmentPeriodCopyWithImpl<$Res>
    implements $CommitmentPeriodCopyWith<$Res> {
  _$CommitmentPeriodCopyWithImpl(this._self, this._then);

  final CommitmentPeriod _self;
  final $Res Function(CommitmentPeriod) _then;

/// Create a copy of CommitmentPeriod
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? fromDate = null,Object? toDate = null,Object? totalAmount = null,Object? chequeCount = null,Object? banks = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,toDate: null == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,banks: null == banks ? _self.banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankCommitment>,
  ));
}

}


/// Adds pattern-matching-related methods to [CommitmentPeriod].
extension CommitmentPeriodPatterns on CommitmentPeriod {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommitmentPeriod value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommitmentPeriod() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommitmentPeriod value)  $default,){
final _that = this;
switch (_that) {
case _CommitmentPeriod():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommitmentPeriod value)?  $default,){
final _that = this;
switch (_that) {
case _CommitmentPeriod() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitment> banks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommitmentPeriod() when $default != null:
return $default(_that.id,_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitment> banks)  $default,) {final _that = this;
switch (_that) {
case _CommitmentPeriod():
return $default(_that.id,_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String fromDate,  String toDate,  int totalAmount,  int chequeCount,  List<BankCommitment> banks)?  $default,) {final _that = this;
switch (_that) {
case _CommitmentPeriod() when $default != null:
return $default(_that.id,_that.title,_that.fromDate,_that.toDate,_that.totalAmount,_that.chequeCount,_that.banks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CommitmentPeriod implements CommitmentPeriod {
  const _CommitmentPeriod({required this.id, required this.title, required this.fromDate, required this.toDate, required this.totalAmount, required this.chequeCount, final  List<BankCommitment> banks = const <BankCommitment>[]}): _banks = banks;
  factory _CommitmentPeriod.fromJson(Map<String, dynamic> json) => _$CommitmentPeriodFromJson(json);

@override final  int id;
/// مثال:
/// ۵ مرداد ۱۴۰۵
@override final  String title;
@override final  String fromDate;
@override final  String toDate;
@override final  int totalAmount;
@override final  int chequeCount;
 final  List<BankCommitment> _banks;
@override@JsonKey() List<BankCommitment> get banks {
  if (_banks is EqualUnmodifiableListView) return _banks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_banks);
}


/// Create a copy of CommitmentPeriod
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommitmentPeriodCopyWith<_CommitmentPeriod> get copyWith => __$CommitmentPeriodCopyWithImpl<_CommitmentPeriod>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CommitmentPeriodToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommitmentPeriod&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.fromDate, fromDate) || other.fromDate == fromDate)&&(identical(other.toDate, toDate) || other.toDate == toDate)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other._banks, _banks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,fromDate,toDate,totalAmount,chequeCount,const DeepCollectionEquality().hash(_banks));

@override
String toString() {
  return 'CommitmentPeriod(id: $id, title: $title, fromDate: $fromDate, toDate: $toDate, totalAmount: $totalAmount, chequeCount: $chequeCount, banks: $banks)';
}


}

/// @nodoc
abstract mixin class _$CommitmentPeriodCopyWith<$Res> implements $CommitmentPeriodCopyWith<$Res> {
  factory _$CommitmentPeriodCopyWith(_CommitmentPeriod value, $Res Function(_CommitmentPeriod) _then) = __$CommitmentPeriodCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String fromDate, String toDate, int totalAmount, int chequeCount, List<BankCommitment> banks
});




}
/// @nodoc
class __$CommitmentPeriodCopyWithImpl<$Res>
    implements _$CommitmentPeriodCopyWith<$Res> {
  __$CommitmentPeriodCopyWithImpl(this._self, this._then);

  final _CommitmentPeriod _self;
  final $Res Function(_CommitmentPeriod) _then;

/// Create a copy of CommitmentPeriod
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? fromDate = null,Object? toDate = null,Object? totalAmount = null,Object? chequeCount = null,Object? banks = null,}) {
  return _then(_CommitmentPeriod(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,fromDate: null == fromDate ? _self.fromDate : fromDate // ignore: cast_nullable_to_non_nullable
as String,toDate: null == toDate ? _self.toDate : toDate // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,banks: null == banks ? _self._banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankCommitment>,
  ));
}


}

// dart format on
