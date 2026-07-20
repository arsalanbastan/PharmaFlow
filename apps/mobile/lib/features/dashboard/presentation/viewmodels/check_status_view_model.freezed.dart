// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'check_status_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CheckStatusViewModel {

 List<BankTodayCheckViewModel> get banks; int get totalTodayCommitments;
/// Create a copy of CheckStatusViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CheckStatusViewModelCopyWith<CheckStatusViewModel> get copyWith => _$CheckStatusViewModelCopyWithImpl<CheckStatusViewModel>(this as CheckStatusViewModel, _$identity);

  /// Serializes this CheckStatusViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CheckStatusViewModel&&const DeepCollectionEquality().equals(other.banks, banks)&&(identical(other.totalTodayCommitments, totalTodayCommitments) || other.totalTodayCommitments == totalTodayCommitments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(banks),totalTodayCommitments);

@override
String toString() {
  return 'CheckStatusViewModel(banks: $banks, totalTodayCommitments: $totalTodayCommitments)';
}


}

/// @nodoc
abstract mixin class $CheckStatusViewModelCopyWith<$Res>  {
  factory $CheckStatusViewModelCopyWith(CheckStatusViewModel value, $Res Function(CheckStatusViewModel) _then) = _$CheckStatusViewModelCopyWithImpl;
@useResult
$Res call({
 List<BankTodayCheckViewModel> banks, int totalTodayCommitments
});




}
/// @nodoc
class _$CheckStatusViewModelCopyWithImpl<$Res>
    implements $CheckStatusViewModelCopyWith<$Res> {
  _$CheckStatusViewModelCopyWithImpl(this._self, this._then);

  final CheckStatusViewModel _self;
  final $Res Function(CheckStatusViewModel) _then;

/// Create a copy of CheckStatusViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? banks = null,Object? totalTodayCommitments = null,}) {
  return _then(_self.copyWith(
banks: null == banks ? _self.banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankTodayCheckViewModel>,totalTodayCommitments: null == totalTodayCommitments ? _self.totalTodayCommitments : totalTodayCommitments // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CheckStatusViewModel].
extension CheckStatusViewModelPatterns on CheckStatusViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CheckStatusViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CheckStatusViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CheckStatusViewModel value)  $default,){
final _that = this;
switch (_that) {
case _CheckStatusViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CheckStatusViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _CheckStatusViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BankTodayCheckViewModel> banks,  int totalTodayCommitments)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CheckStatusViewModel() when $default != null:
return $default(_that.banks,_that.totalTodayCommitments);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BankTodayCheckViewModel> banks,  int totalTodayCommitments)  $default,) {final _that = this;
switch (_that) {
case _CheckStatusViewModel():
return $default(_that.banks,_that.totalTodayCommitments);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BankTodayCheckViewModel> banks,  int totalTodayCommitments)?  $default,) {final _that = this;
switch (_that) {
case _CheckStatusViewModel() when $default != null:
return $default(_that.banks,_that.totalTodayCommitments);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CheckStatusViewModel implements CheckStatusViewModel {
  const _CheckStatusViewModel({required final  List<BankTodayCheckViewModel> banks, required this.totalTodayCommitments}): _banks = banks;
  factory _CheckStatusViewModel.fromJson(Map<String, dynamic> json) => _$CheckStatusViewModelFromJson(json);

 final  List<BankTodayCheckViewModel> _banks;
@override List<BankTodayCheckViewModel> get banks {
  if (_banks is EqualUnmodifiableListView) return _banks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_banks);
}

@override final  int totalTodayCommitments;

/// Create a copy of CheckStatusViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CheckStatusViewModelCopyWith<_CheckStatusViewModel> get copyWith => __$CheckStatusViewModelCopyWithImpl<_CheckStatusViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CheckStatusViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CheckStatusViewModel&&const DeepCollectionEquality().equals(other._banks, _banks)&&(identical(other.totalTodayCommitments, totalTodayCommitments) || other.totalTodayCommitments == totalTodayCommitments));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_banks),totalTodayCommitments);

@override
String toString() {
  return 'CheckStatusViewModel(banks: $banks, totalTodayCommitments: $totalTodayCommitments)';
}


}

/// @nodoc
abstract mixin class _$CheckStatusViewModelCopyWith<$Res> implements $CheckStatusViewModelCopyWith<$Res> {
  factory _$CheckStatusViewModelCopyWith(_CheckStatusViewModel value, $Res Function(_CheckStatusViewModel) _then) = __$CheckStatusViewModelCopyWithImpl;
@override @useResult
$Res call({
 List<BankTodayCheckViewModel> banks, int totalTodayCommitments
});




}
/// @nodoc
class __$CheckStatusViewModelCopyWithImpl<$Res>
    implements _$CheckStatusViewModelCopyWith<$Res> {
  __$CheckStatusViewModelCopyWithImpl(this._self, this._then);

  final _CheckStatusViewModel _self;
  final $Res Function(_CheckStatusViewModel) _then;

/// Create a copy of CheckStatusViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? banks = null,Object? totalTodayCommitments = null,}) {
  return _then(_CheckStatusViewModel(
banks: null == banks ? _self._banks : banks // ignore: cast_nullable_to_non_nullable
as List<BankTodayCheckViewModel>,totalTodayCommitments: null == totalTodayCommitments ? _self.totalTodayCommitments : totalTodayCommitments // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$BankTodayCheckViewModel {

 String get bankName; int get totalAmount; int get chequeCount;
/// Create a copy of BankTodayCheckViewModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BankTodayCheckViewModelCopyWith<BankTodayCheckViewModel> get copyWith => _$BankTodayCheckViewModelCopyWithImpl<BankTodayCheckViewModel>(this as BankTodayCheckViewModel, _$identity);

  /// Serializes this BankTodayCheckViewModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BankTodayCheckViewModel&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankName,totalAmount,chequeCount);

@override
String toString() {
  return 'BankTodayCheckViewModel(bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class $BankTodayCheckViewModelCopyWith<$Res>  {
  factory $BankTodayCheckViewModelCopyWith(BankTodayCheckViewModel value, $Res Function(BankTodayCheckViewModel) _then) = _$BankTodayCheckViewModelCopyWithImpl;
@useResult
$Res call({
 String bankName, int totalAmount, int chequeCount
});




}
/// @nodoc
class _$BankTodayCheckViewModelCopyWithImpl<$Res>
    implements $BankTodayCheckViewModelCopyWith<$Res> {
  _$BankTodayCheckViewModelCopyWithImpl(this._self, this._then);

  final BankTodayCheckViewModel _self;
  final $Res Function(BankTodayCheckViewModel) _then;

/// Create a copy of BankTodayCheckViewModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_self.copyWith(
bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BankTodayCheckViewModel].
extension BankTodayCheckViewModelPatterns on BankTodayCheckViewModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BankTodayCheckViewModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BankTodayCheckViewModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BankTodayCheckViewModel value)  $default,){
final _that = this;
switch (_that) {
case _BankTodayCheckViewModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BankTodayCheckViewModel value)?  $default,){
final _that = this;
switch (_that) {
case _BankTodayCheckViewModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String bankName,  int totalAmount,  int chequeCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BankTodayCheckViewModel() when $default != null:
return $default(_that.bankName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String bankName,  int totalAmount,  int chequeCount)  $default,) {final _that = this;
switch (_that) {
case _BankTodayCheckViewModel():
return $default(_that.bankName,_that.totalAmount,_that.chequeCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String bankName,  int totalAmount,  int chequeCount)?  $default,) {final _that = this;
switch (_that) {
case _BankTodayCheckViewModel() when $default != null:
return $default(_that.bankName,_that.totalAmount,_that.chequeCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BankTodayCheckViewModel implements BankTodayCheckViewModel {
  const _BankTodayCheckViewModel({required this.bankName, required this.totalAmount, required this.chequeCount});
  factory _BankTodayCheckViewModel.fromJson(Map<String, dynamic> json) => _$BankTodayCheckViewModelFromJson(json);

@override final  String bankName;
@override final  int totalAmount;
@override final  int chequeCount;

/// Create a copy of BankTodayCheckViewModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BankTodayCheckViewModelCopyWith<_BankTodayCheckViewModel> get copyWith => __$BankTodayCheckViewModelCopyWithImpl<_BankTodayCheckViewModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BankTodayCheckViewModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BankTodayCheckViewModel&&(identical(other.bankName, bankName) || other.bankName == bankName)&&(identical(other.totalAmount, totalAmount) || other.totalAmount == totalAmount)&&(identical(other.chequeCount, chequeCount) || other.chequeCount == chequeCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,bankName,totalAmount,chequeCount);

@override
String toString() {
  return 'BankTodayCheckViewModel(bankName: $bankName, totalAmount: $totalAmount, chequeCount: $chequeCount)';
}


}

/// @nodoc
abstract mixin class _$BankTodayCheckViewModelCopyWith<$Res> implements $BankTodayCheckViewModelCopyWith<$Res> {
  factory _$BankTodayCheckViewModelCopyWith(_BankTodayCheckViewModel value, $Res Function(_BankTodayCheckViewModel) _then) = __$BankTodayCheckViewModelCopyWithImpl;
@override @useResult
$Res call({
 String bankName, int totalAmount, int chequeCount
});




}
/// @nodoc
class __$BankTodayCheckViewModelCopyWithImpl<$Res>
    implements _$BankTodayCheckViewModelCopyWith<$Res> {
  __$BankTodayCheckViewModelCopyWithImpl(this._self, this._then);

  final _BankTodayCheckViewModel _self;
  final $Res Function(_BankTodayCheckViewModel) _then;

/// Create a copy of BankTodayCheckViewModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bankName = null,Object? totalAmount = null,Object? chequeCount = null,}) {
  return _then(_BankTodayCheckViewModel(
bankName: null == bankName ? _self.bankName : bankName // ignore: cast_nullable_to_non_nullable
as String,totalAmount: null == totalAmount ? _self.totalAmount : totalAmount // ignore: cast_nullable_to_non_nullable
as int,chequeCount: null == chequeCount ? _self.chequeCount : chequeCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
