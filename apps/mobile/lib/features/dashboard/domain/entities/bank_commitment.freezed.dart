// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bank_commitment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BankCommitment {

 int get id; String get bankName; int get totalAmount; int get chequeCount; List<CompanyCommitment> get companies;
/// Create a copy of BankCommitment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankCommitmentCopyWith<BankCommitment> get copyWith => _$BankCommitmentCopyWithImpl<BankCommitment>(this as BankCommitment, _$identity);

  /// Serializes this BankCommitment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankCommitment&&(identical(other.id, id) || other.id == id)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other.companies, companies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bankName,totalAmount,chequeCount,const DeepCollectionEquality().hash(companies));

@override
String toString() {
  return 'BankCommitment(id: $id, bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount, companies: $companies)';
}


}

/// @nodoc
abstract mixin class $BankCommitmentCopyWith<$Res>  {
  factory $BankCommitmentCopyWith(BankCommitment value, $Res Function(BankCommitment) _then) = _$BankCommitmentCopyWithImpl;
@useResult
$Res call({
 int id, String bankName, int totalAmount, int chequeCount, List<CompanyCommitment> companies
});




}
/// @nodoc
class _$BankCommitmentCopyWithImpl<$Res>
    implements $BankCommitmentCopyWith<$Res> {
  _$BankCommitmentCopyWithImpl(this._self, this._then);

  final BankCommitment _self;
  final $Res Function(BankCommitment) _then;

/// Create a copy of BankCommitment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,Object? companies = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,companies: null == companies ? _self.companies : companies // ignore: cast_nullable_to_non_nullable
as List<CompanyCommitment>,
  ));
}

}


/// Adds pattern-matching-related methods to [BankCommitment].
extension BankCommitmentPatterns on BankCommitment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankCommitment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankCommitment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankCommitment value)  $default,){
final _that = this;
switch (_that) {
case _BankCommitment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankCommitment value)?  $default,){
final _that = this;
switch (_that) {
case _BankCommitment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitment> companies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankCommitment() when $default != null:
return $default(_that.id,_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitment> companies)  $default,) {final _that = this;
switch (_that) {
case _BankCommitment():
return $default(_that.id,_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String bankName,  int totalAmount,  int chequeCount,  List<CompanyCommitment> companies)?  $default,) {final _that = this;
switch (_that) {
case _BankCommitment() when $default != null:
return $default(_that.id,_that.bankName,_that.totalAmount,_that.chequeCount,_that.companies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankCommitment implements BankCommitment {
  const _BankCommitment({required this.id, required this.bankName, required this.totalAmount, required this.chequeCount, final  List<CompanyCommitment> companies = const <CompanyCommitment>[]}): _companies = companies;
  factory _BankCommitment.fromJson(Map<String, dynamic> json) => _$BankCommitmentFromJson(json);

@override final  int id;
@override final  String bankName;
@override final  int totalAmount;
@override final  int chequeCount;
 final  List<CompanyCommitment> _companies;
@override@JsonKey() List<CompanyCommitment> get companies {
  if (_companies is EqualUnmodifiableListView) return _companies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_companies);
}


/// Create a copy of BankCommitment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankCommitmentCopyWith<_BankCommitment> get copyWith => __$BankCommitmentCopyWithImpl<_BankCommitment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankCommitmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankCommitment&&(identical(other.id, id) || other.id == id)&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount)&&const DeepCollectionEquality().equals(other._companies, _companies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,bankName,totalAmount,chequeCount,const DeepCollectionEquality().hash(_companies));

@override
String toString() {
  return 'BankCommitment(id: $id, bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount, companies: $companies)';
}


}

/// @nodoc
abstract mixin class _$BankCommitmentCopyWith<$Res> implements $BankCommitmentCopyWith<$Res> {
  factory _$BankCommitmentCopyWith(_BankCommitment value, $Res Function(_BankCommitment) _then) = __$BankCommitmentCopyWithImpl;
@override @useResult
$Res call({
 int id, String bankName, int totalAmount, int chequeCount, List<CompanyCommitment> companies
});




}
/// @nodoc
class __$BankCommitmentCopyWithImpl<$Res>
    implements _$BankCommitmentCopyWith<$Res> {
  __$BankCommitmentCopyWithImpl(this._self, this._then);

  final _BankCommitment _self;
  final $Res Function(_BankCommitment) _then;

/// Create a copy of BankCommitment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,Object? companies = null,}) {
  return _then(_BankCommitment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,companies: null == companies ? _self._companies : companies // ignore: cast_nullable_to_non_nullable
as List<CompanyCommitment>,
  ));
}


}

// dart format on
